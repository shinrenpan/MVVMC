import Testing
import SwiftUI
import UIKit
@testable import ViewSplitProbe

/// ⚠️ **本 suite 必須序列化。** 所有測試共用 `BodyCounter.shared` /
/// `StateIdentityLog.shared`，而 Swift Testing 預設平行執行——一個測試的
/// `reset()` 會清掉另一個測試進行中的計數。
/// 實測（2026-09-08）：同一份程式碼兩次執行給出不同數字（withID bodies=3 vs 0），
/// 而那組被污染的數字一度被當成實測結果寫進規範。
/// 新增測試時請加進**這個** suite，不要另開 struct——另開的 suite 之間仍是平行的。
@Suite(.serialized)
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

  @Test
  func `reordering a ForEach resets child @State or not`() async {
    let original = [ReorderItem(id: 1, label: "A"),
                    ReorderItem(id: 2, label: "B"),
                    ReorderItem(id: 3, label: "C")]
    let reordered = [original[2], original[0], original[1]]

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
  }

  /// §7 的表格每一列都預設順序不變。這裡量三種變動下，props 沒變的子組件會不會被跳過。
  @Test
  func `does props-unchanged skipping survive a reorder`() async {
    let base = [ReorderItem(id: 1, label: "A"),
                ReorderItem(id: 2, label: "B"),
                ReorderItem(id: 3, label: "C")]
    let vc = UIHostingController(rootView: ValueListView(items: base))
    let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    w.rootViewController = vc
    w.isHidden = false
    await settle(w)

    BodyCounter.shared.reset()
    vc.rootView = ValueListView(items: base)
    await settle(w)
    let identical = ["A", "B", "C"].map { BodyCounter.shared.count("value.child.\($0)") }

    BodyCounter.shared.reset()
    var oneChanged = base
    oneChanged[1] = ReorderItem(id: 2, label: "B2")
    vc.rootView = ValueListView(items: oneChanged)
    await settle(w)
    let ch = ["A", "B2", "C"].map { BodyCounter.shared.count("value.child.\($0)") }

    BodyCounter.shared.reset()
    let permuted = [oneChanged[2], oneChanged[0], oneChanged[1]]
    vc.rootView = ValueListView(items: permuted)
    await settle(w)
    let re = ["A", "B2", "C"].map { BodyCounter.shared.count("value.child.\($0)") }

    print("PROBE_RESULT skip identical  A=\(identical[0]) B=\(identical[1]) C=\(identical[2])")
    print("PROBE_RESULT skip oneChanged A=\(ch[0]) B2=\(ch[1]) C=\(ch[2])")
    print("PROBE_RESULT skip reordered  A=\(re[0]) B2=\(re[1]) C=\(re[2])")
  }
}
