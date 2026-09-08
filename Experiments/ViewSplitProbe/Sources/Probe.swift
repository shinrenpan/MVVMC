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
