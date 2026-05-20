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

    let postsNav = UINavigationController(rootViewController: PostListHostController(viewModel: .init()))
    postsNav.tabBarItem = UITabBarItem(title: "Posts", image: UIImage(systemName: "list.bullet"), tag: 0)

    let profileNav = UINavigationController(rootViewController: ProfileHostController())
    profileNav.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 1)

    let tabBar = UITabBarController()
    tabBar.viewControllers = [postsNav, profileNav]

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = tabBar
    window.backgroundColor = .systemBackground
    window.makeKeyAndVisible()
    self.window = window
  }
}
