import Foundation

// MARK: - State

extension UserDetailViewModel {
  struct State: Equatable, Sendable {
    var isFirstAppear: Bool = true
    var api: API = .init()
    var user: User? = nil
  }

  struct API: Equatable, Sendable {
    var fetchUser: APIStatus = .prepare
  }
}

// MARK: - Domain Models

extension UserDetailViewModel {
  struct User: Equatable, Sendable {
    let id: Int
    var name: String
    var email: String
    var company: String
  }
}

// MARK: - DTOs

extension UserDetailViewModel {
  struct UserDTO: Codable, Sendable {
    var id: Int
    var name: String
    var email: String
    var company: String

    func toDomain() -> User? {
      guard !name.isEmpty else { return nil }
      return .init(id: id, name: name, email: email, company: company)
    }
  }
}
