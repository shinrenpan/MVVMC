import UIKit
import UserNotifications

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  // 進入點 1：前景 / 背景 URL Scheme
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let windowScene = scene as? UIWindowScene,
          let url = URLContexts.first?.url,
          let deeplink = Deeplink(url: url) else { return }
    AppRouter.shared.deeplink(deeplink.makeDestination(), in: windowScene)
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
      AppRouter.shared.deeplink(deeplink.makeDestination(), in: windowScene)
    }
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension SceneDelegate: UNUserNotificationCenterDelegate {
  // 進入點 3：Push 點擊（全狀態通用）— nonisolated，用 Task 跳回主執行緒
  // 目的地 scene 取自 `response.targetScene`，不是 `self.window`：通知中心的 delegate 是
  // 全域單一個，多 scene 時它不一定是使用者點的那個 scene 的 SceneDelegate
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }
    guard let urlString = response.notification.request.content.userInfo["deeplink"] as? String,
          let url = URL(string: urlString),
          let deeplink = Deeplink(url: url) else { return }
    // 在這裡先取出 scene 再跳 Task：UNNotificationResponse 不是 Sendable，不能帶進 Task；
    // UIScene 是 @MainActor 類別，本身就是 Sendable
    let targetScene = response.targetScene
    Task { @MainActor in
      // targetScene 是 nullable 的 UIScene。nil 時退回這個 SceneDelegate 自己的 scene——
      // 不可退回 connectedScenes.first，那正是 deeplink(_:in:) 要消滅的全域查找
      guard let scene = (targetScene as? UIWindowScene) ?? self.window?.windowScene else { return }
      AppRouter.shared.deeplink(deeplink.makeDestination(), in: scene)
    }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
