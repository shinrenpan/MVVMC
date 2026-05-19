#if DEBUG
extension PostListViewModel.Post {
  static let mock: Self = .init(id: 1, title: "Understanding MVVMC", body: "MVVMC separates concerns across four strictly defined layers.")
  static let mocks: [Self] = [
    .init(id: 1, title: "Understanding MVVMC", body: "MVVMC separates concerns across four strictly defined layers: Model, ViewModel, View, and Controller."),
    .init(id: 2, title: "SwiftUI + UIKit Bridge", body: "UIHostingController embeds SwiftUI views into UIKit navigation, giving the best of both worlds."),
    .init(id: 3, title: "@Observable ViewModel", body: "Swift's Observation framework provides automatic fine-grained tracking — no @Published needed."),
    .init(id: 4, title: "doAction Single Entry Point", body: "All state changes flow through one async function. Predictable, traceable, and easy to test."),
    .init(id: 5, title: "onAction for Routing", body: "The ViewModel signals intent. The HostController decides how to navigate."),
  ]
}
#endif
