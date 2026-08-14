import Foundation

// MARK: - State

extension PostFilterViewModel {
  struct State: Equatable, Sendable {
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
    // payload 傳 primitive：父 feature 不需要認識 PostFilterViewModel.User（見 mvvmc-structure）
    case didSelectUser(id: Int)
    case showAll
    case didCancel
  }
}
