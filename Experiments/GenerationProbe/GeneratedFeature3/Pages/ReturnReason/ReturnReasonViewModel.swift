//
//  ReturnReasonViewModel.swift
//  MVVMC
//

import Foundation

@Observable
@MainActor
final class ReturnReasonViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State = .init()

  @ObservationIgnored
  var onRoute: (@MainActor (Router) -> Void)?

  @ObservationIgnored
  var onCallback: (@MainActor (Callback) async -> Void)?

  /// 跨 feature 只收 primitive；reasonCode / note 是上一步保管的草稿，用來還原輸入
  init(orderID: String, itemIDs: [String], reasonCode: String, note: String) {
    state.orderID = orderID
    state.itemIDs = itemIDs
    state.reasonCategory = ReasonCategory(rawValue: reasonCode)
    state.note = note
  }

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    }
  }
}

// MARK: - ViewAction

extension ReturnReasonViewModel {
  enum ViewAction: Sendable {
    case categoryDidTap(ReasonCategory)
    case nextButtonDidTap
    case backButtonDidTap
    case cancelButtonDidTap
    case cancelAlertDidConfirm
    // 下游步驟經由 C 層中繼上來的結果
    case childDidCancel
    case childDidSubmit(returnID: String)
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case let .categoryDidTap(category):
      state.reasonCategory = (state.reasonCategory == category) ? nil : category

    case .nextButtonDidTap:
      guard state.isValid else { return }
      onRoute?(.toConfirm(
        orderID: state.orderID,
        itemIDs: state.itemIDs,
        reasonCode: state.reasonCode,
        note: state.note
      ))

    case .backButtonDidTap:
      // 回上一步：把目前輸入交還給上一頁保管，否則本頁 VC 被 pop 掉後草稿就消失了
      await onCallback?(.didGoBack(reasonCode: state.reasonCode, note: state.note))

    case .cancelButtonDidTap:
      guard state.isDirty else {
        await onCallback?(.didCancel)
        return
      }
      state.isShowingCancelAlert = true

    case .cancelAlertDidConfirm:
      state.isShowingCancelAlert = false
      await onCallback?(.didCancel)

    case .childDidCancel:
      await onCallback?(.didCancel)

    case let .childDidSubmit(returnID):
      await onCallback?(.didSubmit(returnID: returnID))
    }
  }
}

// MARK: - Router

extension ReturnReasonViewModel {
  enum Router: Equatable, Sendable {
    case toConfirm(orderID: String, itemIDs: [String], reasonCode: String, note: String)
  }
}

// MARK: - Callback

extension ReturnReasonViewModel {
  enum Callback: Equatable, Sendable {
    case didGoBack(reasonCode: String, note: String)
    case didCancel
    case didSubmit(returnID: String)
  }
}
