import Observation

@MainActor
@Observable
final class ProfileViewModel {
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

extension ProfileViewModel {
  enum ViewAction: Sendable {
    case toPosts
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .toPosts:
      onRoute?(.toPosts)
    }
  }
}

// MARK: - Router

extension ProfileViewModel {
  enum Router: Sendable {
    case toPosts
  }
}
