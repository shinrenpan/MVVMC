import SwiftUI
import UIKit

// 問題：在 MVVMC 裡並排兩個 feature，能不能讓每個 pane 都是完整的 HostController（feature 邊界不變）？
//   -mode b   UIKit：UINavigationController(root: UIArrangementViewController)，兩個 pane 各是一個 HostController
//   -mode b2  同 b，但設定在 primary、首頁在 secondary 且 layoutPriority = 1（FoodEntropy 想要的版面）
//   -mode b3  同 b2，再給兩欄各 400pt 最小寬度（讓窄螢幕物理上分不了）
//   -mode b4  容器在寬／窄切換時互換 primary 與 secondary（寬 = regular 且寬 > 高：設定左首頁右；其他：只剩首頁）
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
    // MVVMC 的按鈕寫在每個 HostController 的 SwiftUI .toolbar——pane 裡的這顆會不會出現在共用的導覽列？
    .navigationTitle("\(name) title")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("\(name) action", systemImage: name == "Home" ? "house" : "gearshape") { print("TAP \(name) action") }
      }
    }
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

  /// -paneOptOut 1：pane 自己（照 mvvmc-hostcontroller 的規則）在 C 層退出垂直 bar——
  /// 放在自訂容器裡時，這個覆寫還會生效嗎？
  @available(iOS 27.1, *)
  override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
    UserDefaults.standard.bool(forKey: "paneOptOut") ? .disabled : .automatic
  }
}

// MARK: - B4：尺寸改變時互換 primary／secondary

/// 寬（寬 > 高）：設定 = primary（左）、首頁 = secondary（右）
/// 窄：首頁 = primary → arrangement 收合時保留首頁
@available(iOS 27.1, *)
final class SwappingArrangementController: UIArrangementViewController {
  let home: PaneHostController
  let settings: PaneHostController
  private var isWide: Bool?

  init(home: PaneHostController, settings: PaneHostController) {
    self.home = home
    self.settings = settings
    super.init()
    updateArrangement(UISplitArrangement.split.axes(.horizontal))
  }

  @MainActor required dynamic init?(coder: NSCoder) { fatalError() }

  // 只在 layout 時判斷：那時 bounds 與 trait 都已是新的（viewWillTransition 拿到的 size 早於 trait 更新）
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    apply(size: view.bounds.size)
  }

  // 導覽列只顯示最上層 VC（這個容器）的 navigationItem。pane 的 SwiftUI .toolbar 有寫進 pane 自己的
  // navigationItem，只是不會被顯示——所以由容器把畫面上 pane 的按鈕轉接到自己身上。
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let visible = [viewController(for: .primary), viewController(for: .secondary)]
      .compactMap { $0 }
      .filter { $0.viewIfLoaded?.window != nil }
    let items = visible.flatMap { ($0.navigationItem.rightBarButtonItems ?? []) + $0.navigationItem.trailingItemGroups.flatMap(\.barButtonItems) }
    if navigationItem.rightBarButtonItems.map({ $0.map(ObjectIdentifier.init) }) != items.map(ObjectIdentifier.init) {
      navigationItem.rightBarButtonItems = items
    }
  }

  /// -forward 1：容器把垂直 bar 的決定權轉給 primary pane（UIKit 只替 nav／tab 容器自動轉發）
  /// -containerOptOut 1：對照組——容器自己回傳 .disabled
  override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
    UserDefaults.standard.bool(forKey: "containerOptOut") ? .disabled : .automatic
  }

  override var childForPreferredVerticalBarBehavior: UIViewController? {
    UserDefaults.standard.bool(forKey: "forward") ? viewController(for: .primary) : nil
  }

  private func apply(size: CGSize) {
    // 第一版只看「寬 > 高」：外螢幕橫放（678×466）也算寬，被換成設定當 primary 後又收合，只剩設定。
    // 內螢幕直橫都是 regular、外螢幕橫放是 compact，所以要兩個條件一起看。
    let wide = traitCollection.horizontalSizeClass == .regular && size.width > size.height
    guard wide != isWide else { return }
    isWide = wide
    let (primary, secondary) = wide ? (settings, home) : (home, settings)
    setViewController(nil, for: .primary)
    setViewController(nil, for: .secondary)
    setViewController(primary, for: .primary)
    setViewController(secondary, for: .secondary)
    swaps += 1
    // 換了 primary，childForPreferredVerticalBarBehavior 的答案也變了——要通知系統重新查詢
    setNeedsUpdateOfVerticalBarConfiguration()
  }
  var swaps = 0
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
      let avc = mode == "b4"
        ? SwappingArrangementController(home: home, settings: settings)
        : UIArrangementViewController()
      if mode == "b4" {
        // 由 SwappingArrangementController 自己依寬高決定
      } else if mode == "b2" || mode == "b3" {
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
    if #available(iOS 27.1, *), let avc = arrangement as? UIArrangementViewController {
      let primary = (avc.viewController(for: .primary) as? PaneHostController)?.name ?? "-"
      let swaps = (avc as? SwappingArrangementController)?.swaps ?? 0
      var edge = "?"
      switch avc.traitCollection.verticalBarEdge {
      case .leading: edge = "leading"
      case .trailing: edge = "trailing"
      default: edge = "unspecified"
      }
      parts.append("primary=\(primary) swaps=\(swaps) hsc=\(avc.traitCollection.horizontalSizeClass == .regular ? "R" : "C") verticalBarEdge=\(edge)")
    }
    if let top = nav?.topViewController {
      let ni = top.navigationItem
      let items = (ni.rightBarButtonItems ?? []) + (ni.leftBarButtonItems ?? [])
        + ni.trailingItemGroups.flatMap(\.barButtonItems) + ni.leadingItemGroups.flatMap(\.barButtonItems)
      parts.append("navItems=\(items.count)[\(items.map { $0.title ?? "-" }.joined(separator: ","))] navTitle=\(ni.title ?? top.title ?? "-")")
    }
    for name in ["Home", "Settings"] {
      guard let p = Registry.panes[name] else { continue }
      let f = p.viewIfLoaded.map { $0.convert($0.bounds, to: nil) } ?? .zero
      var hidden = "?"
      if mode.hasPrefix("b"), #available(iOS 27.1, *), let avc = arrangement as? UIArrangementViewController {
        let homeIsPrimary = avc.viewController(for: .primary) === Registry.panes["Home"]
        let placement: UIArrangementViewController.ViewPlacement = (name == "Home") == homeIsPrimary ? .primary : .secondary
        hidden = avc.state(for: placement).map { "\($0.isHidden)" } ?? "nil"
      }
      let presented = p.presentedViewController.map { _ in "yes" } ?? "no"
      let pni = p.navigationItem
      let pItems = (pni.rightBarButtonItems ?? []) + pni.trailingItemGroups.flatMap(\.barButtonItems)
      parts.append("\(name).ownNavItems=\(pItems.count) \(name).ownTitle=\(pni.title ?? "-")")
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
