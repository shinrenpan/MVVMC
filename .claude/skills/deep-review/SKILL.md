---
description: 對單一 Swift 檔案進行深度審查，涵蓋 Swift 寫法品質、Concurrency & Swift 6、Performance & Memory
disable-model-invocation: true
argument-hint: [file-path]
---

深度審查：`$ARGUMENTS`

> **注意**：本 skill 僅分析單一檔案內可見的資訊。需跨檔案確認的問題會標示 ⚠️ 跨檔案，供人工複查。

請依照以下三個 Pass 逐一執行，每個 Pass 輸出獨立報告區塊。

---

## Pass 1 — Swift 寫法品質

讀取 `$ARGUMENTS`，逐行審查以下項目。

**判斷原則**：區分「客觀問題」（❌）與「風格建議」（⚠️）。
- ❌ **客觀問題**：有明確崩潰、洩漏、或維護性破壞風險，應修正
- ⚠️ **風格建議**：取決於 context，可接受也可改善；說明理由，不強制

審查項目：

- **命名**：
  - ❌ 業務邏輯函式 / 變數中出現意義不明的縮寫（如 `tmp`、`x`、`val`）
  - ⚠️ dispatch switch 的即時 binding（如 `case let .view(a)`）用短名是常見慣例，context 清楚時可接受
  - ❌ 型別未遵守 UpperCamelCase；布林值未以 `is` / `has` / `can` 開頭；縮寫未全大寫（`url`、`id`）

- **存取控制**：
  - ❌ helper 函式未加 `private`，不必要地洩漏內部 API
  - ❌ `public` 出現在 feature 層級，需要明確理由

- **Force unwrap / Force cast**：
  - ❌ `!`、`as!` 出現即標記，說明崩潰條件與安全替代方案

- **冗餘寫法**：
  - ❌ 不必要的 `self.`（非 closure / init 內）
  - ⚠️ 可省略但不影響閱讀的型別標注
  - ❌ 多餘的 `Void` return type、`return` 在多行 closure 最後一行但不在單表達式 closure

- **Magic number / string**：
  - ❌ 業務邏輯中未命名的數字常數，應提取為 `static let` 或附上說明
  - ⚠️ UI spacing / layout 常數（如 `padding(8)`）不強制提取

- **Guard vs if-let**：
  - ❌ 多層巢狀 `if let` 可改為 `if let a, let b` 或 `guard`
  - ❌ 早期返回未使用 `guard`，造成主流程縮排過深

- **`some` vs `any`**：
  - ❌ protocol existential（`any P`）用在可改為 generic / `some P` 的場景

- **`async throws` vs `Result<T, E>`**：
  - ⚠️ 已在 async context 內仍用 `Result` 包裝，說明是否為刻意的架構設計

- **`@discardableResult`**：
  - ❌ 有語意上不應被忽略的回傳值，未標注讓呼叫端自行丟棄

輸出格式：

```
### Pass 1 — Swift 寫法品質

❌ 客觀問題：
| 行號 | 問題 | 建議修正 |
|------|------|----------|

⚠️ 風格建議：
| 行號 | 建議 | 理由 |
|------|------|------|

✅ 無問題
```

---

## Pass 2 — Concurrency & Swift 6

審查以下項目：

**Swift 6 合規**

- **`Sendable` 合規**：跨 actor boundary 傳遞的型別是否正確標注 `Sendable`；`@unchecked Sendable` 每處說明理由
- **Actor isolation**：
  - `@MainActor` 是否覆蓋所有 UI 相關存取
  - `nonisolated` 使用是否恰當（純計算、無 mutable state 存取）
  - `nonisolated(unsafe)` 出現即為高風險，說明替代方案
- **`sending` parameter**：函式參數若跨 isolation 邊界傳遞，是否需要標注
- **Actor reentrancy**：`await` 前後同一個 actor 的 mutable state 是否可能被其他 Task 改動，造成邏輯錯誤；檢查是否有 guard 防止重入
- **`@preconcurrency import`**：是否確實需要，能否改用其他方式
- **廢棄 API**：`withUnsafeCurrentTask` 等已廢棄的 concurrency API

**Concurrency 設計**

- **`Task.init` isolation**：`Task { }` 繼承 caller isolation；`Task.detached { }` 不繼承，需明確理由
- **Structured vs unstructured**：能用 `async let` 平行執行時，是否不必要地使用了多個獨立 `Task { }`；Structured concurrency 有自動 cancellation 傳播優勢
- **Fire-and-forget Task**：`Task { }` 不 `await` 回傳值時，分析：
  - Task 隱式強捕獲 `self` 是否會不必要地延長物件生命週期
  - 是否需加 `[weak self]`（若 Task 可能 outlive `self`）
  - 是否需要 cancellation 能力
- **`[weak self]` in Task**：若 `self` 生命週期明確長於 Task，不必要的 `weak` 只增加 unwrap 負擔；反之則必要
- **`AsyncStream` / `AsyncThrowingStream`**：`continuation` 是否有 `onTermination` 處理；是否可能 never resume
- **`withCheckedContinuation`**：continuation 是否保證 resume 恰好一次；`withUnsafeContinuation` 出現即標記
- **`for await in`**：AsyncSequence 消耗端是否在正確的 actor context

輸出格式：

```
### Pass 2 — Concurrency & Swift 6

❌ 需要修正：
| 行號 | 問題 | 風險（high/medium/low）| 建議修正 |
|------|------|------------------------|----------|

⚠️ 跨檔案確認 / 架構取捨：
- ...

✅ 無問題
```

---

## Pass 3 — Performance & Memory

審查以下項目：

**Performance**

- **重複計算**：computed property 或 O(n) 操作在同一 scope 內被呼叫多次，應提取為本地 `let`
- **Value type copy 代價**：大型 `struct`（含多個 `Array` / `Dictionary` 欄位）頻繁複製是否值得改為 `class` 或 COW
- **`@Observable` 觀察粒度**：MVVMC 架構下 ViewModel 的 `struct State` 是標準設計，不列入審查。但 `State` 以外的 property（timer、closure、計數器、cache 等）若不需要觸發 View 更新，應標注 `@ObservationIgnored`
- **SwiftUI `body` 計算**：`body` 內是否有 `map` / `filter` / `sorted` 等 O(n) 操作，應移至 ViewModel computed property
- **`some View` vs `AnyView`**：`AnyView` 破壞 SwiftUI diffing，避免在高頻更新路徑使用
- **`Array` vs `Set`**：對 Array 做 `contains` / `firstIndex` 且集合不小，考慮改用 `Set`
- **`lazy` 屬性**：計算代價高且不一定存取的屬性，是否適合 `lazy`

**Memory**

- **Retain cycle**：closure capture list 是否正確；`[unowned self]` 在 Swift 6 不允許跨 actor，應改為 `[weak self]`
- **`deinit` 可達性**：class 是否能被正確釋放，是否有循環引用路徑（A → closure → B → A）
- **物件生命週期**：`@Observable` class 的生命週期是否符合預期，是否有不應長存的物件被意外持有

輸出格式：

```
### Pass 3 — Performance & Memory

❌ 需要修正：
| 行號 | 問題 | 類別（Performance/Memory）| 建議修正 |
|------|------|--------------------------|----------|

⚠️ 跨檔案確認 / 架構取捨：
- ...

✅ 無問題
```

---

## 最終摘要 — 優先修正清單

綜合三個 Pass，輸出依優先順序排列的修正清單：

```
### 優先修正清單

🔴 高優先（crash 風險 / data race / retain cycle）：
1. ...

🟡 中優先（Swift 6 潛在問題 / 明顯性能損耗）：
1. ...

🟢 低優先（客觀寫法問題）：
1. ...

💬 風格建議（可接受，視團隊偏好決定）：
1. ...
```
