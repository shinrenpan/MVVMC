//
//  OrderDetailViewModel.swift
//  MVVMC
//

import Foundation

@Observable
@MainActor
final class OrderDetailViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  @ObservationIgnored
  var onRoute: (@MainActor (Router) -> Void)?

  init(orderID: String) {
    state.orderID = orderID
  }

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    case let .apiRequest(request): await handleAPIRequest(request)
    case let .apiResponse(response): await handleAPIResponse(response)
    }
  }
}

// MARK: - ViewAction

extension OrderDetailViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case pullToRefresh
    /// 狀態列出現 → 開始輪詢；由 View 的 `.task` 驅動，離開畫面時該 Task 被取消，迴圈隨之結束
    case statusBarDidAppear
    case retryButtonDidTap
    case returnRequestButtonDidTap
    /// 退貨流程（跨三頁）最終送出成功，由子 HostController 的 onCallback 中繼上來
    case returnFlowDidSubmit(returnID: String)
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchOrder))

    case .pullToRefresh:
      await doAction(.apiRequest(.fetchOrder))

    case .statusBarDidAppear:
      await doAction(.apiRequest(.pollStatus))

    case .retryButtonDidTap:
      await doAction(.apiRequest(.fetchOrder))

    case .returnRequestButtonDidTap:
      guard state.canRequestReturn else { return }
      onRoute?(.toReturnItemSelect(orderID: state.orderID))

    case let .returnFlowDidSubmit(returnID):
      // 樂觀更新：先把狀態列切成「退貨處理中」，下一次輪詢會拿到伺服器的權威值覆蓋
      state.submittedReturnID = returnID
      state.liveStatus = .init(code: .returnProcessing, updatedAt: .now, note: nil)
    }
  }
}

// MARK: - Router

extension OrderDetailViewModel {
  enum Router: Equatable, Sendable {
    case toReturnItemSelect(orderID: String)
  }
}

// MARK: - APIRequest

extension OrderDetailViewModel {
  enum APIRequest: Sendable {
    case fetchOrder
    /// 內含 5 秒輪詢迴圈；靠呼叫端（View `.task`）的 Task 取消結束
    case pollStatus
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case .fetchOrder:
      state.api.fetchOrder = .loading
      do {
        let dto = try await OrderDetailAPI.fetchOrder(id: state.orderID)
        await doAction(.apiResponse(.fetchOrderDidFinish(.success(dto))))
      } catch {
        await doAction(.apiResponse(.fetchOrderDidFinish(.failure(.message(error.localizedDescription)))))
      }

    case .pollStatus:
      await pollStatusLoop()
    }
  }

  /// 每 5 秒打一次狀態 API。取消由呼叫端的 Task 負責（`.task` 隨畫面消失自動取消）。
  private func pollStatusLoop() async {
    while !Task.isCancelled {
      // 只有「還沒有任何狀態可顯示」時才表達 loading，
      // 否則每 5 秒閃一次轉圈是體驗倒退（已有內容時不覆蓋既有內容）
      if state.liveStatus == nil {
        state.api.pollStatus = .loading
      }

      do {
        let dto = try await OrderDetailAPI.fetchStatus(orderID: state.orderID)
        await doAction(.apiResponse(.pollStatusDidFinish(.success(dto))))
      } catch is CancellationError {
        return
      } catch {
        await doAction(.apiResponse(.pollStatusDidFinish(.failure(.message(error.localizedDescription)))))
      }

      do {
        try await Task.sleep(for: .seconds(5))
      } catch {
        return  // 被取消
      }
    }
  }
}

// MARK: - APIResponse

extension OrderDetailViewModel {
  enum APIResponse: Sendable {
    case fetchOrderDidFinish(Result<OrderDTO, APIError>)
    case pollStatusDidFinish(Result<OrderStatusDTO, APIError>)
  }

  private func handleAPIResponse(_ response: APIResponse) async {
    switch response {
    case let .fetchOrderDidFinish(.success(dto)):
      guard let order = dto.toDomain() else {
        state.api.fetchOrder = .error("訂單資料格式不正確")
        return
      }
      state.order = order
      state.api.fetchOrder = .success

    case let .fetchOrderDidFinish(.failure(.message(message))):
      state.api.fetchOrder = .error(message)

    case let .pollStatusDidFinish(.success(dto)):
      state.api.pollStatus = .success
      guard let status = dto.toDomain() else { return }
      // 內容沒變就不寫回，避免無謂的 state 變動觸發重繪
      guard status != state.liveStatus else { return }
      state.liveStatus = status

    case let .pollStatusDidFinish(.failure(.message(message))):
      state.api.pollStatus = .error(message)
    }
  }
}
