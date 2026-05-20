import Observation

@MainActor
@Observable
final class PostDetailViewModel {
  var state: State

  init(post: Post) {
    state = .init(post: post)
  }
}
