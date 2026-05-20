#if DEBUG
extension PostListViewModel.Post {
  static let mock: Self = .init(id: 1, userId: 1, title: "Understanding MVVMC", body: "MVVMC separates concerns across four strictly defined layers.")
  static let mocks: [Self] = [
    .init(id: 1, userId: 1, title: "Understanding MVVMC", body: "MVVMC separates concerns across four strictly defined layers: Model, ViewModel, View, and Controller."),
    .init(id: 2, userId: 1, title: "SwiftUI + UIKit Bridge", body: "UIHostingController embeds SwiftUI views into UIKit navigation, giving the best of both worlds."),
    .init(id: 3, userId: 2, title: "@Observable ViewModel", body: "Swift's Observation framework provides automatic fine-grained tracking — no @Published needed."),
    .init(id: 4, userId: 2, title: "doAction Single Entry Point", body: "All state changes flow through one async function. Predictable, traceable, and easy to test."),
    .init(id: 5, userId: 3, title: "onRoute for Navigation", body: "The ViewModel signals intent via onRoute. The HostController decides how to navigate."),
  ]
}
#endif
