import Foundation

// 模擬 API — 實際專案中這裡會是 EndPoint struct，由 APIManager 消費
enum UserDetailAPI {
  static func fetch(userId: Int) async throws -> UserDetailViewModel.UserDTO {
    try await Task.sleep(for: .seconds(1))
    let all: [UserDetailViewModel.UserDTO] = [
      .init(id: 1, name: "Alice Chen", email: "alice@example.com", company: "MVVMC Corp"),
      .init(id: 2, name: "Bob Wu", email: "bob@example.com", company: "Swift Labs"),
      .init(id: 3, name: "Carol Lin", email: "carol@example.com", company: "iOS Studio"),
      .init(id: 4, name: "David Lee", email: "david@example.com", company: "Tech Hub"),
      .init(id: 5, name: "Eva Wang", email: "eva@example.com", company: "Mobile Dev"),
    ]
    guard let dto = all.first(where: { $0.id == userId }) else {
      throw APIError.message("User \(userId) not found")
    }
    return dto
  }
}
