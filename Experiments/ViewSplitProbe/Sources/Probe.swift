import SwiftUI

// body 執行次數計數器
@MainActor
final class BodyCounter {
  static let shared = BodyCounter()
  private(set) var counts: [String: Int] = [:]
  func bump(_ key: String) { counts[key, default: 0] += 1 }
  func reset() { counts = [:] }
  func count(_ key: String) -> Int { counts[key] ?? 0 }
}

@Observable
@MainActor
final class ProbeModel {
  var a: Int = 0   // 只有 A 區塊讀
  var b: Int = 0   // 只有 B 區塊讀
}

// MARK: - 版本 1：@ViewBuilder func 拆分

struct FuncSplitView: View {
  let model: ProbeModel

  var body: some View {
    let _ = BodyCounter.shared.bump("func.parent")
    VStack {
      sectionA()
      sectionB()
    }
  }

  @ViewBuilder private func sectionA() -> some View {
    let _ = BodyCounter.shared.bump("func.A")
    Text("A \(model.a)")
  }

  @ViewBuilder private func sectionB() -> some View {
    let _ = BodyCounter.shared.bump("func.B")
    Text("B \(model.b)")
  }
}

// MARK: - 版本 2：獨立 struct View 拆分（props 精準注入）

struct StructSplitView: View {
  let model: ProbeModel

  var body: some View {
    let _ = BodyCounter.shared.bump("struct.parent")
    VStack {
      SectionA(value: model.a)
      SectionB(value: model.b)
    }
  }
}

private extension StructSplitView {
  struct SectionA: View {
    let value: Int
    var body: some View {
      let _ = BodyCounter.shared.bump("struct.A")
      Text("A \(value)")
    }
  }

  struct SectionB: View {
    let value: Int
    var body: some View {
      let _ = BodyCounter.shared.bump("struct.B")
      Text("B \(value)")
    }
  }
}

// MARK: - 版本 3：獨立 struct View，但整包傳 model（違反「精準注入」）

struct StructWholeModelView: View {
  let model: ProbeModel

  var body: some View {
    let _ = BodyCounter.shared.bump("whole.parent")
    VStack {
      SectionA(model: model)
      SectionB(model: model)
    }
  }
}

private extension StructWholeModelView {
  struct SectionA: View {
    let model: ProbeModel
    var body: some View {
      let _ = BodyCounter.shared.bump("whole.A")
      Text("A \(model.a)")
    }
  }

  struct SectionB: View {
    let model: ProbeModel
    var body: some View {
      let _ = BodyCounter.shared.bump("whole.B")
      Text("B \(model.b)")
    }
  }
}

// MARK: - 版本 4：獨立 struct View，但用 AnyView 包裹（型別抹除）

struct AnyViewSplitView: View {
  let model: ProbeModel

  var body: some View {
    let _ = BodyCounter.shared.bump("anyview.parent")
    VStack {
      AnyView(SectionA(value: model.a))
      AnyView(SectionB(value: model.b))
    }
  }
}

private extension AnyViewSplitView {
  struct SectionA: View {
    let value: Int
    var body: some View {
      let _ = BodyCounter.shared.bump("anyview.A")
      Text("A \(value)")
    }
  }

  struct SectionB: View {
    let value: Int
    var body: some View {
      let _ = BodyCounter.shared.bump("anyview.B")
      Text("B \(value)")
    }
  }
}

// MARK: - 版本 5：MVVMC 形狀（單一 var state: State）

@Observable
@MainActor
final class MVVMCModel {
  struct State: Equatable, Sendable {
    var a: Int = 0
    var b: Int = 0
  }
  var state = State()
}

struct MVVMCSplitView: View {
  let viewModel: MVVMCModel

  var body: some View {
    let _ = BodyCounter.shared.bump("mvvmc.parent")
    VStack {
      SectionA(value: viewModel.state.a)
      SectionB(value: viewModel.state.b)
    }
  }
}

private extension MVVMCSplitView {
  struct SectionA: View {
    let value: Int
    var body: some View {
      let _ = BodyCounter.shared.bump("mvvmc.A")
      Text("A \(value)")
    }
  }

  struct SectionB: View {
    let value: Int
    var body: some View {
      let _ = BodyCounter.shared.bump("mvvmc.B")
      Text("B \(value)")
    }
  }
}

@main
struct ProbeApp: App {
  var body: some Scene {
    WindowGroup { Text("probe") }
  }
}

// MARK: - 重排探針：.id(item.id) 之下，@State 會不會被重置

/// 記錄每個 item.id 對應的子組件 @State 身分。
/// 若重排後同一個 item.id 的 instanceID 變了 → @State 被重置。
@MainActor
final class StateIdentityLog {
  static let shared = StateIdentityLog()
  private(set) var identities: [Int: UUID] = [:]
  func record(itemID: Int, instance: UUID) { identities[itemID] = instance }
  func reset() { identities = [:] }
  func identity(_ itemID: Int) -> UUID? { identities[itemID] }
}

struct ReorderItem: Identifiable, Equatable {
  let id: Int
  let label: String
}

/// 子組件持有自己的 @State。instanceID 在 @State 被重置時會換一個新的。
private struct ReorderChild: View {
  let item: ReorderItem
  let key: String
  @State private var instanceID = UUID()

  var body: some View {
    let _ = BodyCounter.shared.bump("\(key).child")
    let _ = StateIdentityLog.shared.record(itemID: item.id, instance: instanceID)
    return Text(item.label)
  }
}

/// 版本 A：ForEach + .id(item.id)——`mvvmc-view` §8 推薦的形狀
struct ReorderWithExplicitIDView: View {
  let items: [ReorderItem]

  var body: some View {
    let _ = BodyCounter.shared.bump("withID.parent")
    return VStack {
      ForEach(items) { item in
        ReorderChild(item: item, key: "withID")
          .id(item.id)
      }
    }
  }
}

/// 版本 B：ForEach 不額外加 .id()——對照組
struct ReorderNoExplicitIDView: View {
  let items: [ReorderItem]

  var body: some View {
    let _ = BodyCounter.shared.bump("noID.parent")
    return VStack {
      ForEach(items) { item in
        ReorderChild(item: item, key: "noID")
      }
    }
  }
}

// MARK: - §7 的表格在重排下還成不成立
// 子組件只收值（props 精準注入），沒有 @State——這是 §7 表格第二列的形狀。
// 問題：陣列被置換時，props 沒變的子組件會不會被跳過？

private struct ValueOnlyChild: View, Equatable {
  let label: String

  var body: some View {
    let _ = BodyCounter.shared.bump("value.child.\(label)")
    return Text(label)
  }
}

struct ValueListView: View {
  let items: [ReorderItem]

  var body: some View {
    let _ = BodyCounter.shared.bump("value.parent")
    return VStack {
      ForEach(items) { item in
        ValueOnlyChild(label: item.label)
      }
    }
  }
}

// MARK: - 版本 6／7：MVVMC 形狀 + send closure
//
// 版本 5 量的是「子組件只收值」。但 `mvvmc-view` 規定每個 L2/L3 都要帶
// `let send: @MainActor (Action) -> Void`——那個 closure 從未進過這支 probe。
// Apple 的 swiftui-specialist〈Not a fix: Hoisting the closure to a stored
// property on the View〉說 View struct 會被自由重建、`let` 的初始式因此重跑並
// 產生新 closure，比較在某些最佳化層級下一律視為不等。若屬實，版本 5 的
// `B body = 0` 在真實 MVVMC 形狀下就不成立。
//
// 6 = method reference（PostListView 的實際寫法：`send: handleListAction`）
// 7 = inline closure literal（同樣合法的寫法，用來分辨兩者是否表現不同）

@Observable
@MainActor
final class MVVMCSendModel {
  struct State: Equatable, Sendable {
    var a: Int = 0
    var b: Int = 0
  }
  var state = State()
}

struct MVVMCSendRefSplitView: View {
  let viewModel: MVVMCSendModel

  var body: some View {
    let _ = BodyCounter.shared.bump("sendref.parent")
    VStack {
      SectionA(value: viewModel.state.a, send: handleA)
      SectionB(value: viewModel.state.b, send: handleB)
    }
  }

  @MainActor private func handleA(_ action: SectionA.Action) {
    switch action { case .didTap: viewModel.state.a += 1 }
  }

  @MainActor private func handleB(_ action: SectionB.Action) {
    switch action { case .didTap: viewModel.state.b += 1 }
  }
}

private extension MVVMCSendRefSplitView {
  struct SectionA: View {
    enum Action: Sendable { case didTap }
    let value: Int
    let send: @MainActor (Action) -> Void
    var body: some View {
      let _ = BodyCounter.shared.bump("sendref.A")
      Text("A \(value)").onTapGesture { send(.didTap) }
    }
  }

  struct SectionB: View {
    enum Action: Sendable { case didTap }
    let value: Int
    let send: @MainActor (Action) -> Void
    var body: some View {
      let _ = BodyCounter.shared.bump("sendref.B")
      Text("B \(value)").onTapGesture { send(.didTap) }
    }
  }
}

struct MVVMCInlineSendSplitView: View {
  let viewModel: MVVMCSendModel

  var body: some View {
    let _ = BodyCounter.shared.bump("inline.parent")
    VStack {
      SectionA(value: viewModel.state.a, send: { _ in viewModel.state.a += 1 })
      SectionB(value: viewModel.state.b, send: { _ in viewModel.state.b += 1 })
    }
  }
}

private extension MVVMCInlineSendSplitView {
  struct SectionA: View {
    enum Action: Sendable { case didTap }
    let value: Int
    let send: @MainActor (Action) -> Void
    var body: some View {
      let _ = BodyCounter.shared.bump("inline.A")
      Text("A \(value)").onTapGesture { send(.didTap) }
    }
  }

  struct SectionB: View {
    enum Action: Sendable { case didTap }
    let value: Int
    let send: @MainActor (Action) -> Void
    var body: some View {
      let _ = BodyCounter.shared.bump("inline.B")
      Text("B \(value)").onTapGesture { send(.didTap) }
    }
  }
}
