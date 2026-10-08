import SwiftUI
import UIKit

// 問題：MVVMC 的頁面是 UIHostingController 推在 UINavigationController 上。關掉垂直 bar 有兩個 API——
// V 層的 SwiftUI `.toolbarVerticalBehavior(.disabled)` 與 C 層的 `preferredVerticalBarBehavior`。
// 哪一個真的生效？這決定規則寫在 mvvmc-view 還是 mvvmc-hostcontroller。
//
//   -mode none | swiftui | uikit | axis | compress | watch
// 2 秒後印一行 RESULT 並結束。見 ../README.md。

let mode = UserDefaults.standard.string(forKey: "mode") ?? "none"

struct ProbeView: View {
  /// -mode axis：兩顆按鈕標 `.axisBehavior(.horizontalOnly)`——單一按鈕層級的 SwiftUI 設定
  /// 傳不傳得過 UIHostingController 到 UIKit 的 UIBarButtonItem？
  @ToolbarContentBuilder
  var items: some ToolbarContent {
    if mode == "axis", #available(iOS 27.1, *) {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Filter", systemImage: "line.3.horizontal.decrease") {}
      }
      .axisBehavior(.horizontalOnly)
      ToolbarItem(placement: .topBarLeading) {
        Button("Profile", systemImage: "person") {}
      }
      .axisBehavior(.horizontalOnly)
    } else {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Filter", systemImage: "line.3.horizontal.decrease") {}
      }
      ToolbarItem(placement: .topBarLeading) {
        Button("Profile", systemImage: "person") {}
      }
    }
  }

  var body: some View {
    let base = List(0..<20, id: \.self) { Text("Row \($0)") }
      .navigationTitle("Probe")
      .toolbar { items }
    if mode == "swiftui", #available(iOS 27.1, *) {
      base.toolbarVerticalBehavior(.disabled)
    } else if mode == "compress", #available(iOS 27.1, *) {
      // 頁面層級、但 UIKit 端掛在 navigationItem 上的設定——傳不傳得過去？
      base.toolbarVerticalCompressionBehavior(.prefersToolbarItems)
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

  /// -mode watch：不結束，每次 layout 有變化就印一行 WATCH。用來在旋轉、Split View 時看
  /// 垂直 bar 會不會出現在 leading，以及安全區／layout margins 是否左右不對稱。
  private var lastWatch = ""

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard mode == "watch", let window = view.window else { return }
    func r(_ x: CGFloat) -> String { String(format: "%.0f", x) }
    var edge = "n/a"
    if #available(iOS 27.1, *) {
      edge = switch traitCollection.verticalBarEdge {
      case .leading: "leading"
      case .trailing: "trailing"
      default: "unspecified"
      }
    }
    let orientation = switch window.windowScene?.effectiveGeometry.interfaceOrientation {
    case .portrait: "portrait"
    case .portraitUpsideDown: "upsideDown"
    case .landscapeLeft: "landscapeLeft"
    case .landscapeRight: "landscapeRight"
    default: "unknown"
    }
    let s = view.safeAreaInsets
    let m = view.directionalLayoutMargins
    let line = "WATCH window=\(r(window.bounds.width))x\(r(window.bounds.height))"
      + " screen=\(r(window.screen.bounds.width))x\(r(window.screen.bounds.height)) orientation=\(orientation)"
      + " verticalBarEdge=\(edge) safe=[t\(r(s.top)) l\(r(s.left)) b\(r(s.bottom)) r\(r(s.right))]"
      + " margins=[t\(r(m.top)) lead\(r(m.leading)) b\(r(m.bottom)) trail\(r(m.trailing))]"
    if line != lastWatch {
      lastWatch = line
      print(line)
    }
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

    guard mode != "watch" else { return }
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
      var itemsDesc = "n/a"
      if #available(iOS 27.1, *) {
        let ni = host.navigationItem
        let all = (ni.leftBarButtonItems ?? []) + (ni.rightBarButtonItems ?? [])
          + ni.leadingItemGroups.flatMap(\.barButtonItems) + ni.trailingItemGroups.flatMap(\.barButtonItems)
        itemsDesc = "compression=\(ni.verticalBarCompressionBehavior.rawValue) \(all.count):" + all.map { "\($0.title ?? "-")/axis=\($0.axisBehavior.rawValue)" }.joined(separator: ",")
      }
      let bar = nav.navigationBar.frame
      let tb = tab.tabBar.frame
      print("RESULT mode=\(mode) window=\(r(window.bounds.width))x\(r(window.bounds.height))"
        + " verticalBarEdge=\(edge) hostInsets=[t\(r(inset.top)) l\(r(inset.left)) b\(r(inset.bottom)) r\(r(inset.right))]"
        + " navBar=[x\(r(bar.minX)) y\(r(bar.minY)) w\(r(bar.width)) h\(r(bar.height)) hidden=\(nav.navigationBar.isHidden)]"
        + " items=\(itemsDesc) tabBar=[x\(r(tb.minX)) y\(r(tb.minY)) w\(r(tb.width)) h\(r(tb.height)) hidden=\(tab.tabBar.isHidden)]")
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
