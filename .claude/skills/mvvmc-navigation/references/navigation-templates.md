# Navigation Templates

MVVMC 導航地基的完整可貼實作。三個檔案住在 `Sources/App/`。

> ⚠️ **下列程式碼逐字取自 demo 的 `Sources/App/`，不是另一份手抄本。** 唯一的來源是那三個檔；本檔只是把它們攤開來方便貼進新專案。
>
> 舊版這裡寫的是「改動任一邊都要同步另一邊」——**那條自律失敗過**：v3.2.0 把 `deeplink()` 從「present 一個 VC」改成 `Deeplink.Destination`（切分頁＋推上脈絡）之後，demo、`README.md` 都更新了，這份範本沒有，落後了整整一代，而且還在示範規範已明文禁止的「Router 注入 Close 鈕」。**範本是唯一會被整段貼進新專案的檔案**，所以它是所有消費端裡最不該落後的一個。
>
> 改 `Sources/App/` 之後，用這行確認範本沒落後（無輸出即一致）：
>
> ```bash
> python3 - <<'EOF'
> import re
> t=open('.claude/skills/mvvmc-navigation/references/navigation-templates.md').read()
> for name, code in re.findall(r'## (\S+\.swift)\n.*?```swift\n(.*?)\n```', t, re.S):
>     if code != open(f'Sources/App/{name}').read().rstrip('\n'):
>         print('STALE:', name)
> EOF
> ```

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
      nav.interactivePopGestureRecognizer?.isEnabled = true
      nav.interactivePopGestureRecognizer?.delegate = self
      if #available(iOS 26, *) {
        nav.interactiveContentPopGestureRecognizer?.isEnabled = true
        nav.interactiveContentPopGestureRecognizer?.delegate = self
      }
    }
    destination.appTransitionStyle = style
    nav.pushViewController(destination, animated: animated)
  }

  func back(from source: UIViewController, animated: Bool = true) {
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

  // 不收 from:——那是死參數。destination 本來就必須在目標 stack 裡，從它身上取 nav
  // 還能讓「destination 不在任何 stack」這個裝配錯誤落進 assertionFailure，
  // 而不是讓 UIKit 靜默什麼都不做。
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

  /// deeplink 的唯一入口。呼叫端是 SceneDelegate（三個進入點都走這裡），手上只有 window。
  ///
  /// ❌ **不注入 Close 鈕。** Router 往別人的 `navigationItem` 塞按鈕，那顆按鈕在 C 層與
  /// V 層之外被建立、沒有 `viewModel` 可以呼叫，結構上不可能遵守「導覽列按鈕的點擊要走
  /// `doAction`」；而且它不知道那一頁關閉時該做什麼（送出中的表單、要發 onCallback 的頁）。
  /// 關閉入口由目的地自己在 V 層提供（見 `SettingsView` 的 `.toolbar`）。
  func deeplink(_ destination: Deeplink.Destination, animated: Bool = true) {
    let rootVC = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.keyWindow?.rootViewController
    guard let rootVC else {
      assertionFailure("AppRouter.deeplink(): 找不到 rootViewController")
      return
    }

    switch destination {
    case let .navigate(tab, stack):
      guard let tabBar = rootVC as? UITabBarController else {
        assertionFailure("AppRouter.deeplink(.navigate): rootViewController 不是 UITabBarController")
        return
      }
      // 已經有 modal 蓋在上面時先收掉，否則切了分頁使用者也看不到
      tabBar.presentedViewController?.dismiss(animated: false)
      tabBar.selectedIndex = tab
      guard let nav = (tabBar.selectedViewController as? UINavigationController) else {
        assertionFailure("AppRouter.deeplink(.navigate): 該分頁的根不是 UINavigationController")
        return
      }
      // 保留該分頁既有的根（那就是「往回按看得到的列表」），只推上目的地
      let root = nav.viewControllers.prefix(1)
      stack.forEach { $0.appTransitionStyle = .push }
      nav.setViewControllers(Array(root) + stack, animated: animated)

    case let .present(vc):
      vc.appTransitionStyle = .sheet
      let nav = UINavigationController(rootViewController: vc)
      nav.modalPresentationStyle = .fullScreen
      nav.appTransitionStyle = .sheet
      rootVC.present(nav, animated: animated)
    }
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

集中式路由。新增一個 deeplink 目標只需改這一檔：加一個 `case` + `init?(url:)` 一個分支 + `makeDestination()` 一個分支。回傳 `Destination` 而非單一 `UIViewController`，是因為冷啟動的 deeplink 多半要建**一組** VC（切到分頁 + 把目的地推上該 stack），不是 present 一個孤兒頁。

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

// MARK: - Destination

extension Deeplink {
  /// deeplink 的目的地是「一組 VC ＋ 一個呈現意圖」，不是單一 VC。
  ///
  /// why：只 present 一個詳情頁，冷啟動時會得到一個**孤兒頁面**——使用者的心智模型是
  /// 「往回按可以看到列表」，而那個 stack 是空的。真正該是 modal 的（獨立 onboarding、
  /// 強制更新）才用 `.present`。
  enum Destination {
    /// 切到某個分頁，並把這一組 VC 推上該分頁的 stack（第一個是脈絡，最後一個是目的地）
    case navigate(tab: Int, stack: [UIViewController])
    /// 真正該是 modal 的：獨立於導航脈絡、看完就關
    case present(UIViewController)
  }

  @MainActor func makeDestination() -> Destination {
    switch self {
    case .settings:
      // 設定與任何分頁的脈絡無關，關掉就回到原本在看的東西 → modal
      // 它的關閉入口由 SettingsView 的 .toolbar 自己提供（見 mvvmc-navigation）
      return .present(SettingsHostController(viewModel: .init()))

    case let .postDetail(id):
      // 詳情頁屬於 Posts 分頁的脈絡 → 切分頁 + 推上去，系統返回鈕自然存在
      return .navigate(tab: 0, stack: [
        PostDetailHostController(id: id, title: "Post #\(id)", body: "")
      ])
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
    AppRouter.shared.deeplink(deeplink.makeDestination())
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
      AppRouter.shared.deeplink(deeplink.makeDestination())
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
    Task { @MainActor in AppRouter.shared.deeplink(deeplink.makeDestination()) }
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
