import Observation

@MainActor
@Observable
final class PostFilterViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State = .init()

  @ObservationIgnored
  var onCallback: (@MainActor (Callback) async -> Void)?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    }
  }
}

// MARK: - View Action

extension PostFilterViewModel {
  enum ViewAction: Sendable {
    case didSelectUser(User)
    case showAll
    case cancel
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case let .didSelectUser(user):
      await onCallback?(.didSelectUser(user))
    case .showAll:
      await onCallback?(.showAll)
    case .cancel:
      await onCallback?(.didCancel)
    }
  }
}
