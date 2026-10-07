import SwiftUI
import UIKit

// 問題：在 MVVMC 裡並排兩個 feature，能不能讓每個 pane 都是完整的 HostController（feature 邊界不變）？
//   -mode b   UIKit：UINavigationController(root: UIArrangementViewController)，兩個 pane 各是一個 HostController
//   -mode b2  同 b，但設定在 primary、首頁在 secondary 且 layoutPriority = 1（FoodEntropy 想要的版面）
//   -mode b3  同 b2，再給兩欄各 400pt 最小寬度（讓窄螢幕物理上分不了）
//   -mode c   SwiftUI：UINavigationController(root: 容器 HostController)，裡面 ArrangementView 的兩個 pane
//             各用 UIViewControllerRepresentable 包一個 HostController
// primary = Home（窄時預設保留），secondary = Settings（窄時被藏起來）。
// 每秒印一行 STATE，讓開合時的狀態可以從 log 直接讀。見 ../README.md。

let mode = UserDefaults.standard.string(forKey: "mode") ?? "b"

@MainActor enum Registry {
  static var panes: [String: PaneHostController] = [:]
}

// MARK: - Pane（代表一個完整 feature 的 HostController）

struct PaneView: View {
  let name: String
  let color: Color
  let presentSheet: () -> Void
  let push: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Text(name).font(.largeTitle.bold())
      Button("從這一欄開 sheet", action: presentSheet).buttonStyle(.borderedProminent)
      Button("從這一欄 push", action: push).buttonStyle(.bordered)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(color.opacity(0.15))
  }
}

final class PaneHostController: UIHostingController<PaneView> {
  let name: String

  init(name: String, color: Color) {
    self.name = name
    var presentSheet: () -> Void = {}
    var push: () -> Void = {}
    super.init(rootView: PaneView(name: name, color: color, presentSheet: { presentSheet() }, push: { push() }))
    // 與 MVVMC 的 HostController 同一條路徑：present / push 都從 self 出發
    presentSheet = { [weak self] in
      let sheet = UIHostingController(rootView: Text("\(name) 開的 sheet").font(.title))
      sheet.modalPresentationStyle = .pageSheet
      self?.present(sheet, animated: true)
    }
    push = { [weak self] in
      let page = UIHostingController(rootView: Text("\(name) push 的頁面").font(.title))
      page.title = "Pushed from \(name)"
      self?.navigationController?.pushViewController(page, animated: true)
    }
    title = name
    Registry.panes[name] = self
  }

  @MainActor required dynamic init?(coder: NSCoder) { fatalError() }
}

// MARK: - C：SwiftUI ArrangementView 包 HostController

struct PaneRepresentable: UIViewControllerRepresentable {
  let controller: PaneHostController
  func makeUIViewController(context: Context) -> PaneHostController { controller }
  func updateUIViewController(_ uiViewController: PaneHostController, context: Context) {}
}

struct SwiftUIContainer: View {
  let home: PaneHostController
  let settings: PaneHostController
  var body: some View {
    if #available(iOS 27.1, *) {
      ArrangementView {
        PaneRepresentable(controller: home)
      } secondary: {
        PaneRepresentable(controller: settings)
      }
      .arrangementViewStyle(.split.axes(.horizontal))
    } else {
      Text("requires iOS 27.1")
    }
  }
}

// MARK: - App

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  weak var nav: UINavigationController?
  weak var arrangement: UIViewController?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let home = PaneHostController(name: "Home", color: .blue)
    let settings = PaneHostController(name: "Settings", color: .orange)

    let root: UIViewController
    if mode == "c" {
      root = UIHostingController(rootView: SwiftUIContainer(home: home, settings: settings))
    } else if #available(iOS 27.1, *) {
      let avc = UIArrangementViewController()
      if mode == "b2" || mode == "b3" {
        // FoodEntropy 想要的版面：設定在左（primary）、首頁在右（secondary），窄時只留首頁
        avc.setViewController(settings, for: .primary)
        avc.setViewController(home, for: .secondary)
        var arrangement = UISplitArrangement.split.axes(.horizontal)
        var props = arrangement.defaultViewProperties
        props.layoutPriority = 1
        if mode == "b3" {
          // 兩欄各要求至少 400pt：直向 669pt 塞不下兩欄 → 收合、保留 priority 較高的首頁
          props.width.minimum = .absolute(400)
        }
        arrangement.setViewProperties(props, for: .secondary)
        if mode == "b3" {
          var primaryProps = arrangement.defaultViewProperties
          primaryProps.width.minimum = .absolute(400)
          arrangement.setViewProperties(primaryProps, for: .primary)
        }
        avc.updateArrangement(arrangement)
      } else {
        avc.setViewController(home, for: .primary)
        avc.setViewController(settings, for: .secondary)
        avc.updateArrangement(UISplitArrangement.split.axes(.horizontal))
      }
      root = avc
    } else {
      root = UIViewController()
    }
    root.title = "Container (\(mode))"
    arrangement = root

    let nav = UINavigationController(rootViewController: root)
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = nav
    window.makeKeyAndVisible()
    self.window = window
    self.nav = nav

    Task { @MainActor [weak self] in
      while true {
        self?.log()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  private func log() {
    guard let window else { return }
    func r(_ x: CGFloat) -> String { String(format: "%.0f", x) }
    var parts = ["STATE mode=\(mode) window=\(r(window.bounds.width))x\(r(window.bounds.height))",
                 "navTop=\(nav?.topViewController?.title ?? "-")"]
    for name in ["Home", "Settings"] {
      guard let p = Registry.panes[name] else { continue }
      let f = p.viewIfLoaded.map { $0.convert($0.bounds, to: nil) } ?? .zero
      var hidden = "?"
      if mode.hasPrefix("b"), #available(iOS 27.1, *), let avc = arrangement as? UIArrangementViewController {
        let homeIsPrimary = mode == "b"
        let placement: UIArrangementViewController.ViewPlacement = (name == "Home") == homeIsPrimary ? .primary : .secondary
        hidden = avc.state(for: placement).map { "\($0.isHidden)" } ?? "nil"
      }
      let presented = p.presentedViewController.map { _ in "yes" } ?? "no"
      parts.append("\(name)=[inWindow=\(p.viewIfLoaded?.window != nil) parent=\(p.parent.map { String(describing: type(of: $0)) } ?? "nil")"
        + " nav=\(p.navigationController != nil) frame=x\(r(f.minX)) w\(r(f.width)) hidden=\(hidden) sheet=\(presented)]")
    }
    print(parts.joined(separator: " "))
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
