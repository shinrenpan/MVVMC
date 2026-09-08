import Testing
import SwiftUI
import UIKit
@testable import ViewSplitProbe

@MainActor
struct BodyCountTests {

  private func host<V: View>(_ view: V) -> UIWindow {
    let vc = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = vc
    window.isHidden = false
    window.layoutIfNeeded()
    return window
  }

  private func settle(_ window: UIWindow) async {
    for _ in 0..<5 {
      await Task.yield()
      RunLoop.current.run(until: Date().addingTimeInterval(0.02))
      window.setNeedsLayout()
      window.layoutIfNeeded()
    }
  }

  @Test
  func `measure body executions when only a changes`() async {
    // 版本 1：@ViewBuilder func 拆分
    let m1 = ProbeModel()
    let w1 = host(FuncSplitView(model: m1))
    await settle(w1)
    BodyCounter.shared.reset()
    m1.a += 1
    await settle(w1)
    let funcParent = BodyCounter.shared.count("func.parent")
    let funcA = BodyCounter.shared.count("func.A")
    let funcB = BodyCounter.shared.count("func.B")

    // 版本 2：獨立 struct View + 精準注入（只傳需要的值）
    let m2 = ProbeModel()
    let w2 = host(StructSplitView(model: m2))
    await settle(w2)
    BodyCounter.shared.reset()
    m2.a += 1
    await settle(w2)
    let structParent = BodyCounter.shared.count("struct.parent")
    let structA = BodyCounter.shared.count("struct.A")
    let structB = BodyCounter.shared.count("struct.B")

    // 版本 3：獨立 struct View，但整包傳 @Observable model
    let m3 = ProbeModel()
    let w3 = host(StructWholeModelView(model: m3))
    await settle(w3)
    BodyCounter.shared.reset()
    m3.a += 1
    await settle(w3)
    let wholeParent = BodyCounter.shared.count("whole.parent")
    let wholeA = BodyCounter.shared.count("whole.A")
    let wholeB = BodyCounter.shared.count("whole.B")

    // 版本 4：AnyView 包裹
    let m4 = ProbeModel()
    let w4 = host(AnyViewSplitView(model: m4))
    await settle(w4)
    BodyCounter.shared.reset()
    m4.a += 1
    await settle(w4)
    let anyParent = BodyCounter.shared.count("anyview.parent")
    let anyA = BodyCounter.shared.count("anyview.A")
    let anyB = BodyCounter.shared.count("anyview.B")

    // 版本 5：MVVMC 形狀（單一 state struct）
    let m5 = MVVMCModel()
    let w5 = host(MVVMCSplitView(viewModel: m5))
    await settle(w5)
    BodyCounter.shared.reset()
    m5.state.a += 1
    await settle(w5)
    let mvvmcParent = BodyCounter.shared.count("mvvmc.parent")
    let mvvmcA = BodyCounter.shared.count("mvvmc.A")
    let mvvmcB = BodyCounter.shared.count("mvvmc.B")

    print("PROBE_RESULT func   parent=\(funcParent) A=\(funcA) B=\(funcB)")
    print("PROBE_RESULT struct parent=\(structParent) A=\(structA) B=\(structB)")
    print("PROBE_RESULT whole  parent=\(wholeParent) A=\(wholeA) B=\(wholeB)")

    print("PROBE_RESULT anyview parent=\(anyParent) A=\(anyA) B=\(anyB)")

    print("PROBE_RESULT mvvmc  parent=\(mvvmcParent) A=\(mvvmcA) B=\(mvvmcB)")

    // 只驗證實驗本身有效（A 確實重繪了），B 的數字是觀測目標
    #expect(funcA >= 1)
    #expect(structA >= 1)
    #expect(wholeA >= 1)
  }
}

@MainActor
struct ReorderTests {

  private func host<V: View>(_ view: V) -> UIWindow {
    let vc = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = vc
    window.isHidden = false
    window.layoutIfNeeded()
    return window
  }

  private func settle(_ window: UIWindow) async {
    for _ in 0..<5 {
      await Task.yield()
      RunLoop.current.run(until: Date().addingTimeInterval(0.02))
      window.setNeedsLayout()
      window.layoutIfNeeded()
    }
  }

  /// mvvmc-view §8 的斷言：「列表重排時 view 會重建，@State 會重置」
  /// 這裡量的是：同一個 item.id 的子組件，在陣列順序改變後，@State 身分還在不在。
  @Test
  func `reordering a ForEach resets child @State or not`() async {
    let original = [ReorderItem(id: 1, label: "A"),
                    ReorderItem(id: 2, label: "B"),
                    ReorderItem(id: 3, label: "C")]
    let reordered = [original[2], original[0], original[1]]

    // ── 版本 A：加了 .id(item.id)
    StateIdentityLog.shared.reset()
    let vcA = UIHostingController(rootView: ReorderWithExplicitIDView(items: original))
    let wA = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    wA.rootViewController = vcA
    wA.isHidden = false
    await settle(wA)
    let beforeA = StateIdentityLog.shared.identities
    BodyCounter.shared.reset()
    vcA.rootView = ReorderWithExplicitIDView(items: reordered)
    await settle(wA)
    let afterA = StateIdentityLog.shared.identities
    let survivedA = [1, 2, 3].allSatisfy { beforeA[$0] != nil && beforeA[$0] == afterA[$0] }
    let childBodiesA = BodyCounter.shared.count("withID.child")

    // ── 版本 B：沒有額外 .id()
    StateIdentityLog.shared.reset()
    let vcB = UIHostingController(rootView: ReorderNoExplicitIDView(items: original))
    let wB = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    wB.rootViewController = vcB
    wB.isHidden = false
    await settle(wB)
    let beforeB = StateIdentityLog.shared.identities
    BodyCounter.shared.reset()
    vcB.rootView = ReorderNoExplicitIDView(items: reordered)
    await settle(wB)
    let afterB = StateIdentityLog.shared.identities
    let survivedB = [1, 2, 3].allSatisfy { beforeB[$0] != nil && beforeB[$0] == afterB[$0] }
    let childBodiesB = BodyCounter.shared.count("noID.child")

    print("PROBE_RESULT reorder withID  @State survived=\(survivedA)  child bodies=\(childBodiesA)")
    print("PROBE_RESULT reorder noID    @State survived=\(survivedB)  child bodies=\(childBodiesB)")

    // 只驗證實驗有效：重排後子組件確實重新求值過
    #expect(childBodiesA >= 1)
    #expect(childBodiesB >= 1)
  }
}
