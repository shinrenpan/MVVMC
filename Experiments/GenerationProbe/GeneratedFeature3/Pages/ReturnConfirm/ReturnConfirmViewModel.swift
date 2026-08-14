//
//  ReturnConfirmViewModel.swift
//  MVVMC
//

import Foundation

@Observable
@MainActor
final class ReturnConfirmViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  @ObservationIgnored
  var onCallback: (@MainActor (Callback) async -> Void)?

  init(orderID: String, itemIDs: [String], reasonCode: String, note: String) {
    state.orderID = orderID
    state.itemIDs = itemIDs
    state.reasonCode = reasonCode
    state.note = note
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

extension ReturnConfirmViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case retryButtonDidTap
    case submitButtonDidTap
    case backButtonDidTap
    case cancelButtonDidTap
    case cancelAlertDidConfirm
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchSummary))

    case .retryButtonDidTap:
      await doAction(.apiRequest(.fetchSummary))

    case .submitButtonDidTap:
      // 防重複送出是 VM 的 guard，不靠 UI 禁用來保證
      guard state.canSubmit else { return }
      await doAction(.apiRequest(.submitReturn))

    case .backButtonDidTap:
      await onCallback?(.didGoBack)

    case .cancelButtonDidTap:
      guard state.isDirty else {
        await onCallback?(.didCancel)
        return
      }
      state.isShowingCancelAlert = true

    case .cancelAlertDidConfirm:
      state.isShowingCancelAlert = false
      await onCallback?(.didCancel)
    }
  }
}

// MARK: - Callback

extension ReturnConfirmViewModel {
  enum Callback: Equatable, Sendable {
    case didGoBack
    case didCancel
    case didSubmit(returnID: String)
  }
}

// MARK: - APIRequest

extension ReturnConfirmViewModel {
  enum APIRequest: Sendable {
    case fetchSummary
    case submitReturn
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case .fetchSummary:
      state.api.fetchSummary = .loading
      do {
        let dto = try await ReturnConfirmAPI.fetchSummary(
          orderID: state.orderID,
          itemIDs: state.itemIDs,
          reasonCode: state.reasonCode
        )
        await doAction(.apiResponse(.fetchSummaryDidFinish(.success(dto))))
      } catch {
        await doAction(.apiResponse(.fetchSummaryDidFinish(.failure(.message(error.localizedDescription)))))
      }

    case .submitReturn:
      state.api.submit = .loading
      let requestDTO = SubmitReturnRequestDTO(
        order_id: state.orderID,
        item_ids: state.itemIDs,
        reason_code: state.reasonCode,
        note: state.note
      )
      do {
        let dto = try await ReturnConfirmAPI.submitReturn(requestDTO)
        await doAction(.apiResponse(.submitReturnDidFinish(.success(dto))))
      } catch {
        await doAction(.apiResponse(.submitReturnDidFinish(.failure(.message(error.localizedDescription)))))
      }
    }
  }
}

// MARK: - APIResponse

extension ReturnConfirmViewModel {
  enum APIResponse: Sendable {
    case fetchSummaryDidFinish(Result<ReturnSummaryDTO, APIError>)
    case submitReturnDidFinish(Result<ReturnReceiptDTO, APIError>)
  }

  private func handleAPIResponse(_ response: APIResponse) async {
    switch response {
    case let .fetchSummaryDidFinish(.success(dto)):
      guard let summary = dto.toDomain() else {
        state.api.fetchSummary = .error("退貨摘要格式不正確")
        return
      }
      state.summary = summary
      state.api.fetchSummary = .success

    case let .fetchSummaryDidFinish(.failure(.message(message))):
      state.api.fetchSummary = .error(message)

    case let .submitReturnDidFinish(.success(dto)):
      state.api.submit = .success
      // 一路往上拋到訂單詳情頁；中間兩頁只負責中繼
      await onCallback?(.didSubmit(returnID: dto.return_id))

    case let .submitReturnDidFinish(.failure(.message(message))):
      // 失敗只寫狀態欄位，前兩步的輸入緩衝原封不動
      state.api.submit = .error(message)
    }
  }
}
