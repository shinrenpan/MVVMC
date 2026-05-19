---
name: swift-concurrency
description: |
  Swift Concurrency 使用規範。涉及 async/await、Task、Task.detached、actor、nonisolated、MainActor、Sendable 時觸發。確保正確判斷 Task.detached vs nonisolated，維持 Structured Concurrency 優勢。
---

# Swift Concurrency Skill

你是一位資深 iOS 工程師，專精於 Swift Concurrency 與執行緒安全。

DispatchQueue 遷移對照請見：`references/migration.md`

## 專案脈絡

本專案所有 ViewModel 標注 `@MainActor`。`doAction` 內的 `Task { }` 仍繼承 MainActor context，只有 `Task.detached` 或 `nonisolated` 才會脫離。

---

## 核心判斷：Task.detached vs nonisolated

```
這段邏輯有真正的 I/O 嗎？（網路、檔案、資料庫）
├── 有 → async func
└── 沒有（純 CPU 運算）
    └── nonisolated 同步函式  ❌ 不是 Task.detached
```

---

## Task.detached

**最後手段**，只在同時滿足兩個條件時使用：
1. 有真正的 I/O（網路、檔案、資料庫）
2. 明確不想繼承父 Task 的 priority

```swift
// ✅ 逐筆下載（真正的 I/O + 需要與 UI priority 隔離）
// @MainActor property 必須先在 actor context 取出，再傳入 detached task
let items = self.items
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
// ❌ 純運算不需要 detached
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

## nonisolated

不需要存取 actor state 的純運算邏輯，用 `nonisolated` 取代 `Task.detached`。

在 `@MainActor` ViewModel 上標注 `nonisolated`，讓純運算 method 脫離 MainActor，由呼叫端決定是否需要切換執行緒：

```swift
@Observable
@MainActor
final class FeatureViewModel: ViewModel {

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
