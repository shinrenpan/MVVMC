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

  func to(_ destination: UIViewController, from source: UIViewController, style: TransitionStyle = .push, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.to(): source VC 沒有 navigationController，請確認 rootViewController 設定為 UINavigationController")
      return
    }
    destination.appTransitionStyle = style
    if style == .push {
      nav.pushViewController(destination, animated: animated)
    } else {
      destination.navigationItem.hidesBackButton = true
      applyTransition(style, isPush: true, on: nav)
      nav.pushViewController(destination, animated: false)
    }
  }

  func back(from source: UIViewController, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.back(): source VC 沒有 navigationController")
      return
    }
    let style = nav.topViewController?.appTransitionStyle ?? .push
    if style == .push {
      nav.popViewController(animated: animated)
    } else {
      applyTransition(style, isPush: false, on: nav)
      nav.popViewController(animated: false)
    }
  }

  func backTo(_ destination: UIViewController, from source: UIViewController, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.backTo(): source VC 沒有 navigationController")
      return
    }
    let style = nav.topViewController?.appTransitionStyle ?? .push
    if style == .push {
      nav.popToViewController(destination, animated: animated)
    } else {
      applyTransition(style, isPush: false, on: nav)
      nav.popToViewController(destination, animated: false)
    }
  }

  func backToRoot(from source: UIViewController, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.backToRoot(): source VC 沒有 navigationController")
      return
    }
    let style = nav.topViewController?.appTransitionStyle ?? .push
    if style == .push {
      nav.popToRootViewController(animated: animated)
    } else {
      applyTransition(style, isPush: false, on: nav)
      nav.popToRootViewController(animated: false)
    }
  }
}

// MARK: - CATransition

private extension AppRouter {
  func applyTransition(_ style: TransitionStyle, isPush: Bool, on nav: UINavigationController) {
    let transition = CATransition()
    transition.duration = 0.35
    switch style {
    case .modal:
      transition.type = isPush ? .moveIn : .reveal
      transition.subtype = isPush ? .fromBottom : .fromTop
      transition.timingFunction = CAMediaTimingFunction(name: isPush ? .easeOut : .easeIn)
    case .fade:
      transition.type = .fade
      transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    case .push:
      break
    }
    nav.view.layer.add(transition, forKey: kCATransition)
  }
}
