import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let nav = UINavigationController(rootViewController: PostListHostController(viewModel: .init()))
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = nav
    window.makeKeyAndVisible()
    self.window = window
  }
}
