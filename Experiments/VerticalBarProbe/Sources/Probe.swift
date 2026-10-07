import SwiftUI
import UIKit

// 問題：MVVMC 的頁面是 UIHostingController 推在 UINavigationController 上。關掉垂直 bar 有兩個 API——
// V 層的 SwiftUI `.toolbarVerticalBehavior(.disabled)` 與 C 層的 `preferredVerticalBarBehavior`。
// 哪一個真的生效？這決定規則寫在 mvvmc-view 還是 mvvmc-hostcontroller。
//
//   -mode none | swiftui | uikit
// 2 秒後印一行 RESULT 並結束。見 ../README.md。

let mode = UserDefaults.standard.string(forKey: "mode") ?? "none"

struct ProbeView: View {
  var body: some View {
    let base = List(0..<20, id: \.self) { Text("Row \($0)") }
      .navigationTitle("Probe")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Filter", systemImage: "line.3.horizontal.decrease") {}
        }
        ToolbarItem(placement: .topBarLeading) {
          Button("Profile", systemImage: "person") {}
        }
      }
    if mode == "swiftui", #available(iOS 27.1, *) {
      base.toolbarVerticalBehavior(.disabled)
    } else {
      base
    }
  }
}

final class ProbeHostController: UIHostingController<ProbeView> {
  init() { super.init(rootView: ProbeView()) }
  @MainActor required dynamic init?(coder: NSCoder) { fatalError() }

  @available(iOS 27.1, *)
  override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
    mode == "uikit" ? .disabled : .automatic
  }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let host = ProbeHostController()
    let nav = UINavigationController(rootViewController: host)
    nav.tabBarItem = UITabBarItem(title: "Probe", image: UIImage(systemName: "list.bullet"), tag: 0)
    let other = UINavigationController(rootViewController: UIViewController())
    other.tabBarItem = UITabBarItem(title: "Other", image: UIImage(systemName: "person"), tag: 1)
    let tab = UITabBarController()
    tab.viewControllers = [nav, other]
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = tab
    window.makeKeyAndVisible()
    self.window = window

    Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      func r(_ x: CGFloat) -> String { String(format: "%.0f", x) }
      let inset = host.view.safeAreaInsets
      var edge = "n/a"
      if #available(iOS 27.1, *) {
        edge = switch host.traitCollection.verticalBarEdge {
        case .leading: "leading"
        case .trailing: "trailing"
        default: "unspecified"
        }
      }
      let bar = nav.navigationBar.frame
      let tb = tab.tabBar.frame
      print("RESULT mode=\(mode) window=\(r(window.bounds.width))x\(r(window.bounds.height))"
        + " verticalBarEdge=\(edge) hostInsets=[t\(r(inset.top)) l\(r(inset.left)) b\(r(inset.bottom)) r\(r(inset.right))]"
        + " navBar=[x\(r(bar.minX)) y\(r(bar.minY)) w\(r(bar.width)) h\(r(bar.height)) hidden=\(nav.navigationBar.isHidden)]"
        + " tabBar=[x\(r(tb.minX)) y\(r(tb.minY)) w\(r(tb.width)) h\(r(tb.height)) hidden=\(tab.tabBar.isHidden)]")
      exit(0)
    }
  }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let config = UISceneConfiguration(name: nil, sessionRole: session.role)
    config.delegateClass = SceneDelegate.self
    return config
  }
}
