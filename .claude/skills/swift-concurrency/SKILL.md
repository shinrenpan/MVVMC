---
name: swift-concurrency
description: |
  Swift Concurrency 使用規範。涉及 async/await、Task、Task.detached、@concurrent、nonisolated、actor、MainActor、Sendable 時觸發。確保正確判斷離開主 actor 的工具，維持 Structured Concurrency 優勢。
---

# Swift Concurrency Skill

你是一位資深 iOS 工程師，專精於 Swift Concurrency 與執行緒安全。

> 基準 **Swift 6.3**（目前 GA；本地 toolchain 6.3.1）。並發模型自 **6.2「Approachable Concurrency」** 起有重大轉向，本 skill 以此為基準——先讀下方〈Swift 6.2+ 心智模型〉再看判斷樹。標記為 **6.4** 的 API 屬 WWDC 2026 預告、**尚未正式 release**，勿在現行 toolchain 使用。

DispatchQueue 遷移對照請見：`references/migration.md`

---

## Swift 6.2+ 心智模型（先讀這段）

6.2「Approachable Concurrency」翻轉了預設，很多舊觀念要更新：

- **模組預設 `@MainActor`**：`Package.swift` 可設 `defaultIsolation(MainActor.self)`，整個模組預設主 actor 隔離，不必到處手動標 `@MainActor`。
- **`nonisolated async func` 預設跑在呼叫端 actor**（`nonisolated(nonsending)`，SE-0461）——**不再自動跳到背景**。所以「標了 `nonisolated` 的 async 就會脫離主 actor」這個舊觀念已不成立。
- **要並行 / 離開 actor 得明講**：async function 標 **`@concurrent`** 才會跑到並發 pool。
- **6.3 Region-based isolation 正式可用**：編譯器能證明更多情況的資料安全，`Sendable` 假陽性大減。

## 專案脈絡

本專案所有 ViewModel 標注 `@MainActor`（或由模組層級 `defaultIsolation(MainActor.self)` 統一預設）。`doAction` 內的 `Task { }` **繼承當前 actor（即 MainActor），不會脫離**。要真正離開主 actor：async 工作用 `@concurrent`（結構化），非結構化才用 `Task.detached`；純同步運算用 `nonisolated func`。

---

## 核心判斷：離開主 actor 的三種工具

```
要把工作移出主 actor 嗎？
├── 純 CPU 運算、不碰 actor state
│   └── nonisolated 同步 func        ← 呼叫端決定在哪跑，零 Task 開銷
├── async 工作要並行 / 離開主 actor（阻塞 I/O、重運算）
│   └── @concurrent async func       ← 6.2+ 標準做法，結構化、可取消
└── 需要「非結構化 + 脫離 priority / task-local」才用
    └── Task.detached                ← 最後手段，罕見
```

- ❌ 純運算包 `Task.detached` 或 `@concurrent`——用 `nonisolated` 同步 func 就好
- ⚠️ 一般 `async func`（未標 `@concurrent`）在 6.2+ 會**跟著呼叫端 actor 跑**，不會自己脫離

---

## @concurrent：離開主 actor 的首選（6.2+）

async 工作若要真正跑在背景（阻塞 I/O、重運算），標 `@concurrent`。它是**結構化**的，享有自動取消與 priority 繼承，優先於 `Task.detached`。

在 `@MainActor` 型別上，方法預設是主 actor 隔離；要離開就同時標 `nonisolated`（脫離主 actor）與 `@concurrent`（async body 跑在並發 pool，而非呼叫端 actor）：

```swift
@Observable
@MainActor
final class FeatureViewModel {

    // 離開主 actor 跑重運算；回到 doAction 存 state 時，編譯器自動切回主 actor
    nonisolated @concurrent
    func decodeThumbnails(_ data: [Data]) async -> [UIImage] {
        data.compactMap { UIImage(data: $0) }
    }
}
```

- 只標 `nonisolated`（不標 `@concurrent`）→ 6.2+ 會跑在呼叫端 actor，**沒離開主 actor**
- 純同步、不 async 的運算 → 用下方 `nonisolated func`，不需要 `@concurrent`

---

## nonisolated（純同步運算）

不需要存取 actor state 的**純同步**運算，用 `nonisolated func` 取代 `Task.detached`，由呼叫端決定在哪跑：

```swift
@Observable
@MainActor
final class FeatureViewModel {

    // ✅ 純運算標注 nonisolated，不占用 MainActor
    nonisolated func toDomains(_ dtos: [DTO]) -> [Domain] {
        dtos.compactMap { $0.toDomain() }
    }

    nonisolated func sorted(_ items: [Item], by sort: SortType) -> [Item] {
        items.sorted { ... }
    }

    // 呼叫端在 @MainActor context，直接同步使用，不需要任何 Task
    private func handleResponse(_ dtos: [DTO]) async {
        state.items = sorted(toDomains(dtos), by: state.currentSort)
    }
}
```

---

## Task.detached

**最後手段**（在 6.2+ 更罕見，多數離開主 actor 的需求改用 `@concurrent`）。只在同時滿足時才用：
1. 需要**非結構化**（脫離父 Task 的取消樹 / task-local 值）
2. 明確不想繼承父 Task 的 priority

```swift
// @MainActor property 必須先在 actor context 取出，再傳入 detached task
let items = self.items
// .background 只是示範用的「某個不繼承父 Task 的 priority」；實際 priority 依情境選，不是規定值
Task.detached(priority: .background) { [weak self] in
    guard let self else { return }
    for item in items {
        if Task.isCancelled { break }
        let updated = await self.downloadImage(for: item)
        await self.updateItem(updated)
    }
}
```

**禁止情境：**

```swift
// ❌ 純運算不需要 detached（也不需要 @concurrent）
let result = await Task.detached(priority: .userInitiated) {
    items.sorted { ... }     // 排序
    dtos.compactMap { ... }  // mapping
    UIImage(data: data)      // 解碼
}.value

// ❌ .task {} 內禁止再包 Task.detached（雙重脫離）
.task(id: item.id) {
    self.image = await Task.detached { UIImage(data: data) }.value
}
```

---

## Task 取消（cancellation）

Swift 的取消是**協作式**的：取消只是設旗標，程式要主動檢查才會停。

**兩種 Task 的關鍵差異：**

- **`.task {}`（SwiftUI modifier）**：綁 View 生命週期，**離開畫面自動取消**——「run once」pattern 就靠它。
- **`Task {}`（非結構化，如 doAction 內）**：**不會自動取消**，要自己存 handle 手動 `cancel()`。

**檢查取消：** `Task.isCancelled`（Bool，自己 return/break）、`try Task.checkCancellation()`（丟 `CancellationError`）、`Task.sleep` 被取消會自動丟錯。

**典型場景：搜尋即打即查（取消前一次）：**

```swift
@ObservationIgnored private var searchTask: Task<Void, Never>?

case .searchTextChanged(let text):
    searchTask?.cancel()                                // 取消上一次
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))  // debounce
        if Task.isCancelled { return }
        await doAction(.apiRequest(.search(text)))
    }
```

- **6.3+**：`Task { try await ... }` 若**未處理**丟出的錯誤，編譯器會**警告**——要嘛在 Task 內處理，要嘛存下 Task 之後檢查。
- **6.4（尚未 GA，屆時可用）**：關鍵清理不想被取消打斷，用 `withTaskCancellationShield { }`。目前 toolchain（6.3.1）**還沒有此 API**，先用「在清理前檢查完取消、清理本身不再檢查」的手動寫法替代：

```swift
// Swift 6.4 起：
await withTaskCancellationShield {
    await database.close()   // shield 內 Task.isCancelled 恆為 false
}
```

---

## 同時執行多個任務

```
需要同時跑多個任務嗎？
├── 數量固定 → async let
├── 數量動態（loop）→ TaskGroup
└── 不需要等結果 → 多個 Task {}（注意錯誤處理）
```

```swift
// async let：同時發出，await 才等結果
async let user = fetchUser()
async let posts = fetchPosts()
let (u, p) = await (user, posts)

// TaskGroup：動態數量，離開 } 自動等待
await withTaskGroup(of: UIImage?.self) { group in
    for item in items { group.addTask { await self.downloadImage(item) } }
    return await group.reduce(into: []) { $0.append($1) }
}
```

---

## Sendable

`Sendable` = 可安全跨並發邊界（actor / Task）傳遞的型別。Swift 6 靠它在**編譯期**擋資料競爭。

- **值型別自動符合**：所有成員都 `Sendable` 的 `struct` / `enum` 自動 `Sendable`（本專案 State / Domain / DTO 皆是）。
- **`@MainActor` 型別隱含 `Sendable`**：actor 隔離本身保證安全。
- **class 要 `final` + 全不可變**才安全；否則得 `@unchecked Sendable` 自己負責。
- **6.3 `weak let`**：有 `weak var` 成員而被迫 `@unchecked` 的 class，改成 `weak let`（不可變）即可正常 `Sendable`。
- **6.3 `~Sendable`**：某型別刻意不該 `Sendable`，用 `~Sendable` 明講（且不擋子類別 Sendable）。
- **6.3 Region-based isolation** 正式可用：以前要硬加 `@Sendable` / `@unchecked` 的地方，很多已不需要。

---

## Actor 隔離策略

```
這份狀態會被多個地方同時讀寫嗎？
├── 不會
│   ├── 唯讀、無狀態 → nonisolated
│   └── 只有一個 actor 存取 → 跟著那個 actor 走（通常是 @MainActor）
└── 會（跨 actor 讀寫）→ actor
```

```swift
// ✅ @MainActor：只有 UI 層存取
@MainActor
final class ToastManager {
    static let shared = ToastManager()
    var currentToast: Toast?
}

// ✅ actor：跨 actor 的共享可變狀態
actor TokenManager {
    private var accessToken: String?
    func token() -> String? { accessToken }
    func update(_ token: String) { accessToken = token }
}

// ❌ 錯誤：用 @MainActor 保護跨 actor 的資源 → 每次存取都強制切回 MainActor
@MainActor
final class DataCache {
    var cache: [String: Data] = [:]
}
```

### ⚠️ Actor 可重入（reentrancy）

actor 方法遇到 `await` 會**讓出**，其他呼叫可能**插隊**進來——「檢查後再動作」的不變式可能在 `await` 前後被破壞。經典坑：token 刷新去重。

```swift
actor TokenManager {
    private var token: String?
    private var refreshTask: Task<String, Error>?

    func validToken() async throws -> String {
        if let token { return token }
        // ❌ 直接 await refresh()：兩個呼叫會各刷一次（await 期間互相插隊）
        // ✅ 快取 in-flight Task，重入的呼叫共用同一次刷新
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await refresh() }
        refreshTask = task
        defer { refreshTask = nil }
        let new = try await task.value
        token = new
        return new
    }
}
```
