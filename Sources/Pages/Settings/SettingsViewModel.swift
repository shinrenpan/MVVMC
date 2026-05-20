import Observation

@MainActor
@Observable
final class SettingsViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State = .init()

  @ObservationIgnored
  var onRoute: (@MainActor (Router) -> Void)?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    }
  }
}

// MARK: - View Action

extension SettingsViewModel {
  enum ViewAction: Sendable {
    case close
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .close:
      onRoute?(.close)
    }
  }
}

// MARK: - Router

extension SettingsViewModel {
  enum Router: Sendable {
    case close
  }
}
