# Navigation Templates

MVVMC 導航地基的完整可貼實作。三個檔案住在 `Sources/App/`。

> ⚠️ **本檔與 demo 的 `Sources/App/` 是同一份程式碼的兩個副本**（差異僅在此處註解較密）。改動任一邊都要同步另一邊，否則「可貼的模板」會與「跑得起來的實作」漸行漸遠。

---

## AppRouter.swift

Stateless 導航中樞。`TransitionStyle` 透過 associated object 掛在 VC 上，供 `UINavigationControllerDelegate` 讀取決定轉場；`AppTransitionAnimator` 負責 `.modal` / `.fade` 的實際動畫。

```swift
import UIKit

// MARK: - TransitionStyle

extension AppRouter {
  enum TransitionStyle: Equatable {
    case push
    case modal
    case fade
    case sheet
  }
}

// MARK: - UIViewController + appTransitionStyle

private final class TransitionStyleBox {
  let style: AppRouter.TransitionStyle
  init(_ style: AppRouter.TransitionStyle) { self.style = style }
}

// 僅作為 associated object 的位址使用、從不真正被改寫，故 nonisolated(unsafe) 安全（Swift 6 strict concurrency）
private nonisolated(unsafe) var appTransitionStyleKey: UInt8 = 0

extension UIViewController {
  fileprivate var appTransitionStyle: AppRouter.TransitionStyle {
    get { (objc_getAssociatedObject(self, &appTransitionStyleKey) as? TransitionStyleBox)?.style ?? .push }
    set { objc_setAssociatedObject(self, &appTransitionStyleKey, TransitionStyleBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }
}

// MARK: - AppRouter

@MainActor
final class AppRouter: NSObject {
  static let shared = AppRouter()
  private override init() {}

  func to(_ destination: UIViewController, from source: UIViewController, style: TransitionStyle = .push, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.to(): source VC 沒有 navigationController，請確認 rootViewController 設定為 UINavigationController")
      return
    }
    if nav.delegate !== self {
      nav.delegate = self
      // 自訂 nav.delegate 會壓掉系統的互動式側滑返回，故需手動重新啟用 + 設 delegate 去 gate
      // （只在 .push 頁面放行，見 gestureRecognizerShouldBegin）。
      // 邊緣側滑（iOS 26 以前唯一的返回手勢）
      nav.interactivePopGestureRecognizer?.isEnabled = true
      nav.interactivePopGestureRecognizer?.delegate = self
      if #available(iOS 26, *) {
        // iOS 26 起改成「整頁」都能側滑返回，這是另一個獨立 recognizer——不是上面那個的重複，
        // 兩個都得啟用，否則 iOS 26 上整頁側滑會失效。刪任一個都會弄壞返回手勢。
        nav.interactiveContentPopGestureRecognizer?.isEnabled = true
        nav.interactiveContentPopGestureRecognizer?.delegate = self
      }
    }
    destination.appTransitionStyle = style
    nav.pushViewController(destination, animated: animated)
  }

  func back(from source: UIViewController, animated: Bool = true) {
    // fallback 到 navigationController 的原因：sheet 若包一層 UINavigationController 呈現，
    // `.sheet` 樣式是蓋在 wrapper nav 上、不在葉子 VC 上。葉子 VC 呼叫 back 時自身讀到預設 `.push`，
    // 只看葉子會誤走 pop（但它是 root、pop 不掉）。往上抓 wrapper nav 的樣式才能正確走 dismiss。
    // （此複雜度屬 push-based 版：back 以 appTransitionStyle 驅動 pop/dismiss 與 .modal/.fade 自訂轉場，故需之。）
    let style = source.appTransitionStyle != .push
      ? source.appTransitionStyle
      : source.navigationController?.appTransitionStyle ?? .push
    switch style {
    case .sheet:
      (source.navigationController ?? source).dismiss(animated: animated)
    default:
      guard let nav = source.navigationController else {
        assertionFailure("AppRouter.back(): source VC 沒有 navigationController")
        return
      }
      nav.popViewController(animated: animated)
    }
  }

  // `from:` 曾經存在但是死參數——它只被用來取 nav，而 destination 本來就必須在同一個
  // stack 裡（否則 popToViewController 無效）。從 destination 取 nav 還順帶修好一個
  // 失敗模式：destination 不在 stack 時，舊寫法會通過 guard 然後讓 UIKit 靜默什麼都不做。
  func backTo(_ destination: UIViewController, animated: Bool = true) {
    guard let nav = destination.navigationController else {
      assertionFailure("AppRouter.backTo(): destination 不在任何 navigation stack 裡")
      return
    }
    nav.popToViewController(destination, animated: animated)
  }

  func backToRoot(from source: UIViewController, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.backToRoot(): source VC 沒有 navigationController")
      return
    }
    nav.popToRootViewController(animated: animated)
  }

  func sheet(
    _ destination: UIViewController,
    from source: UIViewController,
    detents: [UISheetPresentationController.Detent]? = nil,
    animated: Bool = true
  ) {
    destination.appTransitionStyle = .sheet
    destination.modalPresentationStyle = .pageSheet
    if let detents {
      destination.sheetPresentationController?.detents = detents
    }
    source.present(destination, animated: animated)
  }

  func deeplink(_ destination: UIViewController, animated: Bool = true) {
    let rootVC = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.keyWindow?.rootViewController
    guard let rootVC else {
      assertionFailure("AppRouter.deeplink(): 找不到 rootViewController")
      return
    }
    // 標 .sheet 不是因為它長得像 sheet（這裡是 fullScreen），而是因為 .sheet 的語意是
    // 「以 present 呈現 → back() 要走 dismiss」。改成別的樣式會讓 back() 誤走 pop。
    destination.appTransitionStyle = .sheet
    destination.navigationItem.leftBarButtonItem = UIBarButtonItem(
      systemItem: .close,
      primaryAction: UIAction { [weak destination] _ in
        destination?.dismiss(animated: true)
      }
    )
    let nav = UINavigationController(rootViewController: destination)
    nav.modalPresentationStyle = .fullScreen
    rootVC.present(nav, animated: animated)
  }

  func tab(_ index: Int, from source: UIViewController) {
    guard let tabBar = source.tabBarController else {
      assertionFailure("AppRouter.tab(): source VC 沒有 tabBarController，請確認 rootViewController 設定為 UITabBarController")
      return
    }
    tabBar.selectedIndex = index
  }
}

// MARK: - UINavigationControllerDelegate

extension AppRouter: UINavigationControllerDelegate {
  func navigationController(
    _ navigationController: UINavigationController,
    animationControllerFor operation: UINavigationController.Operation,
    from fromVC: UIViewController,
    to toVC: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    let style = operation == .push ? toVC.appTransitionStyle : fromVC.appTransitionStyle
    guard style != .push, style != .sheet else { return nil }
    return AppTransitionAnimator(style: style, isPush: operation == .push)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension AppRouter: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let nav = gestureRecognizer.view?.next as? UINavigationController else { return true }
    guard nav.viewControllers.count > 1 else { return false }
    return (nav.topViewController?.appTransitionStyle ?? .push) == .push
  }
}

// MARK: - AppTransitionAnimator

private final class AppTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  let style: AppRouter.TransitionStyle
  let isPush: Bool

  init(style: AppRouter.TransitionStyle, isPush: Bool) {
    self.style = style
    self.isPush = isPush
  }

  func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval { 0.35 }

  func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
    switch style {
    case .modal: animateModal(transitionContext)
    case .fade:  animateFade(transitionContext)
    case .push, .sheet: transitionContext.completeTransition(true)
    }
  }
}

private extension AppTransitionAnimator {
  func animateModal(_ ctx: any UIViewControllerContextTransitioning) {
    let duration = transitionDuration(using: ctx)
    if isPush {
      guard let toVC = ctx.viewController(forKey: .to), let toView = ctx.view(forKey: .to) else {
        ctx.completeTransition(false); return
      }
      let finalFrame = ctx.finalFrame(for: toVC)
      toView.frame = finalFrame.offsetBy(dx: 0, dy: finalFrame.height)
      ctx.containerView.addSubview(toView)
      UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
        toView.frame = finalFrame
      } completion: { _ in
        ctx.completeTransition(!ctx.transitionWasCancelled)
      }
    } else {
      guard let fromVC = ctx.viewController(forKey: .from),
            let fromView = ctx.view(forKey: .from),
            let toView = ctx.view(forKey: .to) else {
        ctx.completeTransition(false); return
      }
      ctx.containerView.insertSubview(toView, belowSubview: fromView)
      let initialFrame = ctx.initialFrame(for: fromVC)
      UIView.animate(withDuration: duration, delay: 0, options: .curveEaseIn) {
        fromView.frame = initialFrame.offsetBy(dx: 0, dy: initialFrame.height)
      } completion: { _ in
        ctx.completeTransition(!ctx.transitionWasCancelled)
      }
    }
  }

  func animateFade(_ ctx: any UIViewControllerContextTransitioning) {
    let duration = transitionDuration(using: ctx)
    if isPush {
      guard let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
      toView.alpha = 0
      ctx.containerView.addSubview(toView)
      UIView.animate(withDuration: duration) {
        toView.alpha = 1
      } completion: { _ in
        ctx.completeTransition(!ctx.transitionWasCancelled)
      }
    } else {
      guard let fromView = ctx.view(forKey: .from),
            let toView = ctx.view(forKey: .to) else {
        ctx.completeTransition(false); return
      }
      ctx.containerView.insertSubview(toView, belowSubview: fromView)
      UIView.animate(withDuration: duration) {
        fromView.alpha = 0
      } completion: { _ in
        ctx.completeTransition(!ctx.transitionWasCancelled)
      }
    }
  }
}
```

---

## Deeplink.swift

集中式路由。新增一個 deeplink 目標只需改這一檔：加一個 `case` + `init?(url:)` 一個分支 + `makeHostController()` 一個分支。

```swift
import UIKit

// MARK: - Deeplink

enum Deeplink {
  case settings
  case postDetail(id: Int)
}

// MARK: - URL Parsing

extension Deeplink {
  init?(url: URL) {
    guard url.scheme == "mvvmc" else { return nil }
    switch url.host {
    case "settings":
      self = .settings
    case "posts":
      guard let idString = url.pathComponents.dropFirst().first,
            let id = Int(idString) else { return nil }
      self = .postDetail(id: id)
    default:
      return nil
    }
  }
}

// MARK: - HostController Factory

extension Deeplink {
  @MainActor func makeHostController() -> UIViewController {
    switch self {
    case .settings:
      return SettingsHostController(viewModel: .init())
    case let .postDetail(id):
      return PostDetailHostController(id: id, title: "Post #\(id)", body: "")
    }
  }
}
```

---

## SceneDelegate.swift

導航裝配 + 三個 Deeplink 進入點。注意 `window.backgroundColor` 與冷啟動 deeplink 的時機。

```swift
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
    window.backgroundColor = .systemBackground   // 防止轉場期間露出黑底
    window.makeKeyAndVisible()
    self.window = window

    UNUserNotificationCenter.current().delegate = self

    // 進入點 2：冷啟動 URL Scheme（必須在 makeKeyAndVisible() 之後）
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
```

---

## 反模式對照表

| ❌ 反模式 | ✅ 正確做法 | 理由 |
|---------|-----------|------|
| AppRouter 持有 `nav` / `window` stored property | 從 `source.navigationController` 動態取 | 保持 stateless，避免生命週期錯亂 |
| HostController 用 `dismiss` 關 sheet | `AppRouter.shared.back(from: self)` | back() 自動判斷 sheet→dismiss |
| 自訂轉場 VC 開放側滑 | gesture 限定 `.push` 樣式 | 避免側滑回自訂轉場頁造成黑畫面 |
| SceneDelegate 自己 parse URL | 一律 `Deeplink(url:)` | 解析邏輯單一來源 |
| Push 另寫一套 URL 解析 | 重用 `Deeplink(url:)` | payload 就是 `mvvmc://` URL |
| 冷啟動 deeplink 在 `makeKeyAndVisible()` 之前 | 之後才處理 | 確保 rootVC 已存在 |
| 忘記 `window.backgroundColor` | 設 `.systemBackground` | 防止轉場黑底 |
