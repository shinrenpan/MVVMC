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

  /// deeplink 的唯一入口。呼叫端是 SceneDelegate（三個進入點都走這裡），由它傳入事件所屬的 scene。
  ///
  /// ❌ **不從全域找 window。** `UIApplication.shared.connectedScenes.first` 在單一 scene 時
  /// 碰巧對，多 scene（iPhone Duo 內螢幕、iPad）時會把 deeplink 送到錯的視窗。三個進入點
  /// 手上本來就有 scene（`openURLContexts` 的 `scene`、`willConnectTo` 的 `scene`、
  /// 通知回應的 `targetScene`），所以改成收參數——Apple `app-resizability` skill 原則 11：
  /// 「沒有區域物件可用時，替方法加一個參數，並更新呼叫端」。
  ///
  /// ❌ **不注入 Close 鈕。** Router 往別人的 `navigationItem` 塞按鈕，那顆按鈕在 C 層與
  /// V 層之外被建立、沒有 `viewModel` 可以呼叫，結構上不可能遵守「導覽列按鈕的點擊要走
  /// `doAction`」；而且它不知道那一頁關閉時該做什麼（送出中的表單、要發 onCallback 的頁）。
  /// 關閉入口由目的地自己在 V 層提供（見 `SettingsView` 的 `.toolbar`）。
  func deeplink(_ destination: Deeplink.Destination, in scene: UIWindowScene, animated: Bool = true) {
    guard let rootVC = scene.keyWindow?.rootViewController else {
      assertionFailure("AppRouter.deeplink(): 找不到 rootViewController")
      return
    }

    // 已經有 modal 蓋在上面時先收掉，**在 completion 裡**才做後續：
    // - `.present`：有 modal 時 UIKit 拒絕再 present，deeplink 被吃掉（AppRouterDeeplinkTests 重現）
    // - `.navigate`：切了分頁、推了頁面，使用者卻被 modal 擋著看不到；dismiss 與設堆疊放在
    //   同一個 runloop 會漏 push（FoodEntropy fix-deeplink-dropped-push 回報）
    dismissPresented(on: rootVC) {
      switch destination {
      case let .navigate(tab, stack):
        guard let tabBar = rootVC as? UITabBarController else {
          assertionFailure("AppRouter.deeplink(.navigate): rootViewController 不是 UITabBarController")
          return
        }
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
  }

  /// 沒有 modal 時直接執行；有的話收掉後在 completion 執行。
  /// 不能無條件呼叫 `dismiss(animated:completion:)`：沒有東西可收時，UIKit 不保證會呼叫 completion。
  private func dismissPresented(on root: UIViewController, then work: @escaping @MainActor () -> Void) {
    guard let presented = root.presentedViewController else {
      work()
      return
    }
    presented.dismiss(animated: false) { work() }
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
