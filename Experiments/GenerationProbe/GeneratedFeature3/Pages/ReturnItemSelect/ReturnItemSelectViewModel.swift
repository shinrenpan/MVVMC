//
//  ReturnItemSelectViewModel.swift
//  MVVMC
//

import Foundation

@Observable
@MainActor
final class ReturnItemSelectViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  @ObservationIgnored
  var onRoute: (@MainActor (Router) -> Void)?

  @ObservationIgnored
  var onCallback: (@MainActor (Callback) async -> Void)?

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

extension ReturnItemSelectViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case retryButtonDidTap
    case itemDidTap(id: String)
    case nextButtonDidTap
    case cancelButtonDidTap
    case cancelAlertDidConfirm
    // 以下三個不是「使用者在本頁做了什麼」，而是下游步驟經由 C 層中繼上來的結果。
    // MVVMC 沒有第四種 Action 類別可放，依 demo 慣例併入 ViewAction。
    case childDidGoBack(reasonCode: String, note: String)
    case childDidCancel
    case childDidSubmit(returnID: String)
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchReturnableItems))

    case .retryButtonDidTap:
      await doAction(.apiRequest(.fetchReturnableItems))

    case let .itemDidTap(id):
      if state.selectedIDs.contains(id) {
        state.selectedIDs.remove(id)
      } else {
        state.selectedIDs.insert(id)
      }

    case .nextButtonDidTap:
      guard state.canGoNext else { return }
      onRoute?(.toReason(
        orderID: state.orderID,
        itemIDs: state.selectedItemIDs,
        reasonCode: state.draftReasonCode,
        note: state.draftNote
      ))

    case .cancelButtonDidTap:
      guard state.isDirty else {
        await onCallback?(.didCancel)
        return
      }
      state.isShowingCancelAlert = true

    case .cancelAlertDidConfirm:
      state.isShowingCancelAlert = false
      await onCallback?(.didCancel)

    case let .childDidGoBack(reasonCode, note):
      state.draftReasonCode = reasonCode
      state.draftNote = note

    case .childDidCancel:
      await onCallback?(.didCancel)

    case let .childDidSubmit(returnID):
      await onCallback?(.didSubmit(returnID: returnID))
    }
  }
}

// MARK: - Router

extension ReturnItemSelectViewModel {
  enum Router: Equatable, Sendable {
    case toReason(orderID: String, itemIDs: [String], reasonCode: String, note: String)
  }
}

// MARK: - Callback

extension ReturnItemSelectViewModel {
  enum Callback: Equatable, Sendable {
    case didCancel
    case didSubmit(returnID: String)
  }
}

// MARK: - APIRequest

extension ReturnItemSelectViewModel {
  enum APIRequest: Sendable {
    case fetchReturnableItems
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case .fetchReturnableItems:
      state.api.fetchItems = .loading
      do {
        let dtos = try await ReturnItemSelectAPI.fetchReturnableItems(orderID: state.orderID)
        await doAction(.apiResponse(.fetchReturnableItemsDidFinish(.success(dtos))))
      } catch {
        await doAction(.apiResponse(.fetchReturnableItemsDidFinish(.failure(.message(error.localizedDescription)))))
      }
    }
  }
}

// MARK: - APIResponse

extension ReturnItemSelectViewModel {
  enum APIResponse: Sendable {
    case fetchReturnableItemsDidFinish(Result<[ReturnableItemDTO], APIError>)
  }

  private func handleAPIResponse(_ response: APIResponse) async {
    switch response {
    case let .fetchReturnableItemsDidFinish(.success(dtos)):
      let items = toDomains(dtos)
      state.items = items
      // 伺服器可能把某些品項改成不可退，順手把已選但已消失的 id 清掉
      state.selectedIDs = state.selectedIDs.intersection(items.map(\.id))
      state.api.fetchItems = .success

    case let .fetchReturnableItemsDidFinish(.failure(.message(message))):
      state.api.fetchItems = .error(message)
    }
  }

  /// 純運算，不碰 actor state
  nonisolated func toDomains(_ dtos: [ReturnableItemDTO]) -> [ReturnableItem] {
    dtos.compactMap { $0.toDomain() }
  }
}
