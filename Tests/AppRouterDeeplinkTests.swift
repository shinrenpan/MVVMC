import Testing
import UIKit
@testable import MVVMCDemo

/// deeplink 進來時，畫面上已經有 modal 開著——AppRouter 要先收掉它，目的地才看得到。
///
/// 這類問題只有掛在真的 window 上、真的 present 才測得出來：沒有 window 時 UIKit 根本不會
/// present，斷言會在錯的狀態上通過。寫法來自 FoodEntropy 的 `AppRouterTests`（2026-10-07 回報）。
/// `.serialized`：每個測試都把自己的 window 設成 scene 的 key window，平行跑會互相覆蓋。
@MainActor
@Suite(.serialized)
struct AppRouterDeeplinkTests {

  private struct Harness {
    let window: UIWindow
    let tabBar: UITabBarController
    let scene: UIWindowScene
  }

  private func makeHarness() throws -> Harness {
    // 測試程式碼可以走全域找 scene——要被測的是 AppRouter，不是這裡
    let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let tabBar = UITabBarController()
    tabBar.viewControllers = [
      UINavigationController(rootViewController: UIViewController()),
      UINavigationController(rootViewController: UIViewController()),
    ]
    let window = UIWindow(windowScene: scene)
    window.rootViewController = tabBar
    window.makeKeyAndVisible()
    return Harness(window: window, tabBar: tabBar, scene: scene)
  }

  private func tearDown(_ harness: Harness) {
    harness.tabBar.presentedViewController?.dismiss(animated: false)
    harness.window.isHidden = true
  }

  /// 等 UIKit 的 present／dismiss 收尾（即使 animated: false 也不是同步完成）
  private func settle() async {
    try? await Task.sleep(for: .milliseconds(600))
  }

  private func presentSheet(on harness: Harness) async throws {
    let sheet = UIViewController()
    sheet.modalPresentationStyle = .pageSheet
    harness.tabBar.present(sheet, animated: false)
    await settle()
    try #require(harness.tabBar.presentedViewController === sheet)
  }

  @Test
  func `present deeplink replaces an already-presented sheet`() async throws {
    let harness = try makeHarness()
    defer { tearDown(harness) }
    try await presentSheet(on: harness)

    let target = UIViewController()
    AppRouter.shared.deeplink(.present(target), in: harness.scene, animated: false)
    await settle()

    let presentedNav = harness.tabBar.presentedViewController as? UINavigationController
    #expect(presentedNav?.viewControllers.first === target)
  }

  @Test
  func `navigate deeplink dismisses the sheet and pushes onto the tab`() async throws {
    let harness = try makeHarness()
    defer { tearDown(harness) }
    try await presentSheet(on: harness)

    let target = UIViewController()
    AppRouter.shared.deeplink(.navigate(tab: 1, stack: [target]), in: harness.scene, animated: false)
    await settle()

    #expect(harness.tabBar.presentedViewController == nil)
    #expect(harness.tabBar.selectedIndex == 1)
    let nav = harness.tabBar.selectedViewController as? UINavigationController
    #expect(nav?.viewControllers.last === target)
    #expect(nav?.viewControllers.count == 2)   // 保留分頁既有的根，只推上目的地
  }
}
