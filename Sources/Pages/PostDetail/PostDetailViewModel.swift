import Observation

@MainActor
@Observable
final class PostDetailViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State

  init(post: PostListViewModel.Post) {
    state = .init(post: post)
  }

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action):
      handleViewAction(action)
    }
  }
}

// MARK: - View Action

extension PostDetailViewModel {
  enum ViewAction: Sendable {
    case onAppear
  }

  private func handleViewAction(_ action: ViewAction) {
    switch action {
    case .onAppear:
      break
    }
  }
}
