import Foundation

// MARK: - State

extension PostDetailViewModel {
  struct State: Equatable, Sendable {
    let post: Post
  }
}

// MARK: - Domain Models

extension PostDetailViewModel {
  struct Post: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var body: String
  }
}
