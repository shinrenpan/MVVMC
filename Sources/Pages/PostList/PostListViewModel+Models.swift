import Foundation

// MARK: - State

extension PostListViewModel {
  struct State: Sendable {
    var api: API = .init()
    var posts: [Post] = []
  }

  struct API: Sendable {
    var fetchPosts: APIStatus = .prepare
  }
}

// MARK: - Domain Models

extension PostListViewModel {
  struct Post: Identifiable, Sendable {
    let id: Int
    var title: String
    var body: String
  }
}

// MARK: - DTOs

extension PostListViewModel {
  struct PostDTO: Codable, Sendable {
    var id: Int
    var title: String
    var body: String

    func toDomain() -> Post {
      .init(id: id, title: title, body: body)
    }
  }
}
