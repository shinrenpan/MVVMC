import UIKit
import UserNotifications

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  // 進入點 1：前景 / 背景 URL Scheme
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url,
          let deeplink = Deeplink(url: url) else { return }
    AppRouter.shared.deeplink(deeplink.makeHostController())
  }

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
    window.backgroundColor = .systemBackground   // 防止自訂轉場期間露出黑底
    window.makeKeyAndVisible()
    self.window = window

    UNUserNotificationCenter.current().delegate = self

    // 進入點 2：冷啟動 URL Scheme（必須在 makeKeyAndVisible() 之後，確保 rootVC 已存在）
    if let url = connectionOptions.urlContexts.first?.url,
       let deeplink = Deeplink(url: url) {
      AppRouter.shared.deeplink(deeplink.makeHostController())
    }
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension SceneDelegate: UNUserNotificationCenterDelegate {
  // 進入點 3：Push 點擊（全狀態通用）— nonisolated，用 Task 跳回主執行緒
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }
    guard let urlString = response.notification.request.content.userInfo["deeplink"] as? String,
          let url = URL(string: urlString),
          let deeplink = Deeplink(url: url) else { return }
    Task { @MainActor in AppRouter.shared.deeplink(deeplink.makeHostController()) }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
