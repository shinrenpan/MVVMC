import Foundation

// MARK: - State

extension PostFilterViewModel {
  struct State: Sendable {
    let users: [User] = (1...5).map { .init(id: $0) }
  }
}

// MARK: - Domain Models

extension PostFilterViewModel {
  struct User: Identifiable, Equatable, Sendable {
    let id: Int
    var displayName: String { "User \(id)" }
  }
}

// MARK: - Callback

extension PostFilterViewModel {
  enum Callback: Equatable, Sendable {
    case didSelectUser(User)
    case showAll
    case didCancel
  }
}
