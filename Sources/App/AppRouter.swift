import UIKit

// MARK: - TransitionStyle

extension AppRouter {
  enum TransitionStyle: Equatable {
    case push   // 預設，右滑進入
    case modal  // 由下往上
    case fade   // 淡入淡出
  }
}

// MARK: - UIViewController + appTransitionStyle

private final class TransitionStyleBox {
  let style: AppRouter.TransitionStyle
  init(_ style: AppRouter.TransitionStyle) { self.style = style }
}

private var appTransitionStyleKey: UInt8 = 0

extension UIViewController {
  fileprivate var appTransitionStyle: AppRouter.TransitionStyle {
    get { (objc_getAssociatedObject(self, &appTransitionStyleKey) as? TransitionStyleBox)?.style ?? .push }
    set { objc_setAssociatedObject(self, &appTransitionStyleKey, TransitionStyleBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }
}

// MARK: - AppRouter

@MainActor
final class AppRouter {
  static let shared = AppRouter()
  private init() {}

  private let transitionDelegate = NavigationTransitionDelegate()

  func to(_ destination: UIViewController, from source: UIViewController, style: TransitionStyle = .push, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.to(): source VC 沒有 navigationController，請確認 rootViewController 設定為 UINavigationController")
      return
    }
    destination.appTransitionStyle = style
    nav.delegate = transitionDelegate
    nav.pushViewController(destination, animated: animated)
  }

  func back(from source: UIViewController, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.back(): source VC 沒有 navigationController")
      return
    }
    nav.popViewController(animated: animated)
  }

  func backTo(_ destination: UIViewController, from source: UIViewController, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.backTo(): source VC 沒有 navigationController")
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
}

// MARK: - NavigationTransitionDelegate

private final class NavigationTransitionDelegate: NSObject, UINavigationControllerDelegate {
  func navigationController(
    _ navigationController: UINavigationController,
    animationControllerFor operation: UINavigationController.Operation,
    from fromVC: UIViewController,
    to toVC: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    let style: AppRouter.TransitionStyle = switch operation {
    case .push: toVC.appTransitionStyle
    case .pop: fromVC.appTransitionStyle
    default: .push
    }
    guard style != .push else { return nil }
    return AppTransitionAnimator(style: style, operation: operation)
  }
}

// MARK: - AppTransitionAnimator

private final class AppTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  let style: AppRouter.TransitionStyle
  let operation: UINavigationController.Operation

  init(style: AppRouter.TransitionStyle, operation: UINavigationController.Operation) {
    self.style = style
    self.operation = operation
  }

  func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
    0.35
  }

  func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
    switch style {
    case .push:
      transitionContext.completeTransition(true)
    case .modal:
      animateModal(transitionContext)
    case .fade:
      animateFade(transitionContext)
    }
  }

  private func animateModal(_ context: any UIViewControllerContextTransitioning) {
    let container = context.containerView
    let duration = transitionDuration(using: context)

    switch operation {
    case .push:
      guard let toView = context.view(forKey: .to) else {
        context.completeTransition(false)
        return
      }
      container.addSubview(toView)
      toView.frame = container.bounds.offsetBy(dx: 0, dy: container.bounds.height)
      UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
        toView.frame = container.bounds
      } completion: {
        context.completeTransition($0)
      }

    case .pop:
      guard let fromView = context.view(forKey: .from),
            let toView = context.view(forKey: .to) else {
        context.completeTransition(false)
        return
      }
      container.insertSubview(toView, belowSubview: fromView)
      UIView.animate(withDuration: duration, delay: 0, options: .curveEaseIn) {
        fromView.frame = container.bounds.offsetBy(dx: 0, dy: container.bounds.height)
      } completion: {
        context.completeTransition($0)
      }

    default:
      context.completeTransition(true)
    }
  }

  private func animateFade(_ context: any UIViewControllerContextTransitioning) {
    guard let toView = context.view(forKey: .to) else {
      context.completeTransition(false)
      return
    }
    let container = context.containerView
    container.addSubview(toView)
    toView.alpha = 0
    UIView.animate(withDuration: transitionDuration(using: context)) {
      toView.alpha = 1
    } completion: {
      context.completeTransition($0)
    }
  }
}
