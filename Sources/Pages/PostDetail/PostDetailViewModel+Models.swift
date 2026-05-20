import Foundation

// MARK: - State

extension PostDetailViewModel {
  struct State: Sendable {
    let post: Post
  }
}

// MARK: - Domain Models

extension PostDetailViewModel {
  struct Post: Identifiable, Sendable {
    let id: Int
    var title: String
    var body: String
  }
}
