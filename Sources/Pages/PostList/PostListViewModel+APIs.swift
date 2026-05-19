import Foundation

// 模擬 API — 實際專案中這裡會是 EndPoint struct，由 APIManager 消費
enum PostListAPI {
  static func fetch(userId: Int? = nil) async throws -> [PostListViewModel.PostDTO] {
    try await Task.sleep(for: .seconds(1))
    let all: [PostListViewModel.PostDTO] = [
      .init(id: 1, user_id: 1, title: "Understanding MVVMC", body: "MVVMC separates concerns across four strictly defined layers: Model, ViewModel, View, and Controller."),
      .init(id: 2, user_id: 1, title: "SwiftUI + UIKit Bridge", body: "UIHostingController embeds SwiftUI views into UIKit navigation, giving the best of both worlds."),
      .init(id: 3, user_id: 2, title: "@Observable ViewModel", body: "Swift's Observation framework provides automatic fine-grained tracking — no @Published needed."),
      .init(id: 4, user_id: 2, title: "doAction Single Entry Point", body: "All state changes flow through one async function. Predictable, traceable, and easy to test."),
      .init(id: 5, user_id: 3, title: "onRoute for Navigation", body: "The ViewModel signals intent via onRoute. The HostController decides how to navigate."),
    ]
    guard let userId else { return all }
    return all.filter { $0.user_id == userId }
  }
}
