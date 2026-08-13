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

    print("PROBE_RESULT func   parent=\(funcParent) A=\(funcA) B=\(funcB)")
    print("PROBE_RESULT struct parent=\(structParent) A=\(structA) B=\(structB)")
    print("PROBE_RESULT whole  parent=\(wholeParent) A=\(wholeA) B=\(wholeB)")

    print("PROBE_RESULT anyview parent=\(anyParent) A=\(anyA) B=\(anyB)")

    // 只驗證實驗本身有效（A 確實重繪了），B 的數字是觀測目標
    #expect(funcA >= 1)
    #expect(structA >= 1)
    #expect(wholeA >= 1)
  }
}
