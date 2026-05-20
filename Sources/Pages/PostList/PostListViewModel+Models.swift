import Foundation

// MARK: - State

extension PostListViewModel {
  struct State: Sendable {
    var isFirstAppear: Bool = true
    var api: API = .init()
    var posts: [Post] = []
    var filterUserId: Int? = nil
  }

  struct API: Sendable {
    var fetchPosts: APIStatus = .prepare
  }
}

// MARK: - Domain Models

extension PostListViewModel {
  struct Post: Identifiable, Sendable {
    let id: Int
    let userId: Int
    var title: String
    var body: String
  }
}

// MARK: - DTOs

extension PostListViewModel {
  struct PostDTO: Codable, Sendable {
    var id: Int
    var user_id: Int
    var title: String
    var body: String

    func toDomain() -> Post {
      .init(id: id, userId: user_id, title: title, body: body)
    }
  }
}
