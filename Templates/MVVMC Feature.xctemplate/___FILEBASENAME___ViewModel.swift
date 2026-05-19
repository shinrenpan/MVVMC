//  ___FILENAME___
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

import Observation

@MainActor
@Observable
final class ___FILEBASENAME___ViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State = .init()

  @ObservationIgnored
  var onAction: (@MainActor (Action) -> Void)?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action):
      await handleViewAction(action)
    }
  }
}

// MARK: - View Action

extension ___FILEBASENAME___ViewModel {
  enum ViewAction: Sendable {
    case onAppear
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .onAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      // 第一次出現的邏輯
    }
  }
}
