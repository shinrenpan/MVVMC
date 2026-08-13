---
name: mvvmc-model
description: |
  MVVMC M 層建模規範。涉及建立 State、Domain Model、DTO、FeatureViewModel+Models.swift 時觸發。確保三層抽象正確分離，DTO 透過 toDomain() 轉換為 Domain Model。
---

# MVVMC Model Skill

你是一位資深 iOS 工程師，專注於資料層建模。

此 Skill 的職責範圍是 **`FeatureViewModel+Models.swift` 的內容**，不涉及 ViewModel 本身的實作。

完整範例（State / Domain Models / DTOs 三區塊齊全）見：`references/example.md`

---

## 設計哲學

常見三個區塊：**State / Domain Models / DTOs**，不強制全部實作，但各區塊用獨立 `extension` 隔開：

| 區塊 | 抽象層次 | 消費者 |
|------|----------|--------|
| `State` | UI 狀態 | SwiftUI View，直接綁定 |
| `Domain Models` | 業務語意 | ViewModel 邏輯、State |
| `DTOs` | API 原始資料 | Network Layer，解碼後立即 mapping |

**State**：UI 可直接消費的乾淨狀態，DTO 的存在對 UI 層完全透明。

**DTO**：保留 API response 所有欄位，只負責解碼與 `toDomain()` 轉換，轉換邏輯屬於 DTO 自身。

---

## 核心規範

### State

```swift
// MARK: - State

extension FeatureViewModel {
  struct State: Equatable, Sendable {
    var items: [Item] = []
  }
}
```

- `struct`（值類型），遵守 `Equatable` 與 `Sendable`
- 所有屬性給定預設值（確保 `.init()` 無參數可用）
- **預設加 `Equatable`**（例外見下方〈Equatable 規則〉）
- 欄位型別採**黑名單**：只禁兩類，其餘自由（見下方〈State 欄位型別〉）

#### State 欄位型別

| 禁止 | 為什麼 |
|------|--------|
| **DTO**（任何未經 `toDomain()` 的解碼結果） | DTO 是拋棄式髒資料。一旦進 State 就會被 View 讀到，API 欄位改名會直接打穿到 UI——這是 M 層三段抽象存在的唯一理由 |
| **UI framework 型別**（`Color` / `Font` / `Image` / `UIImage` / View 型別） | 顯示決策屬 V 層。寫進 State 會讓 Model 綁死 UI framework，也讓單元測試被迫 import SwiftUI |

除此之外皆可，包含：

- Domain Model 與其集合
- Swift 原生型別、`Optional`
- **純 UI 狀態**：請求狀態容器、展開中的 id 集合、捲動位置、選取狀態、分頁游標等

> **純 UI 狀態的形狀不在規範範圍**——要不要包成 `api` 容器、狀態 enum 有哪些 case、叫什麼名字，屬個人／團隊習慣，本 skill 不介入，審查時也不得以此開單。唯一要求：若該型別讓 `State` 失去 `Equatable`，走〈Equatable 規則〉的例外處理並註明原因。

```swift
extension FeatureViewModel {
  struct State: Equatable, Sendable {
    var isFirstAppear: Bool = true       // ✅ 原生型別
    var items: [Item] = []               // ✅ Domain Model
    var selectedID: Item.ID? = nil       // ✅ Optional
    var api: API = .init()               // ✅ 純 UI 狀態容器（形狀自訂）
    var expandedIDs: Set<Item.ID> = []   // ✅ 純 UI 狀態

 // var dtos: [ItemDTO] = []             // ❌ DTO 外洩
 // var titleColor: Color = .primary     // ❌ UI framework 型別
  }
}
```

**例外：Detail View 必帶初始資料**

```swift
extension PostDetailViewModel {
  struct State: Equatable, Sendable {
    let post: Post
  }
}
```

若把欄位改成 `Optional` 會讓 View 層到處 `if let`，且語意上頁面不存在「沒有資料」的狀態，才用此例外。

此例外的代價：`let post` 無預設值 → **同時放棄第 46 行的無參 `.init()`**，`State()` 會編不過。因此 Preview／Mock／測試不能再用「先無參建 State 再塞值」的套路，必須改成帶參注入 `State(post: .mock)`。

---

### Domain Models

- 每個獨立 Model 各自一個 `extension`
- 遵守 `Equatable` 與 `Sendable`，有 `id` 時遵守 `Identifiable`
- **預設加 `Equatable`**（例外見下方〈Equatable 規則〉）
- 純值 `enum`（無 associated value）本身已隱含 `Equatable`，不需顯式宣告
- `let` 用於不可變欄位，`var` 用於可變欄位
- 禁止回傳 UI framework 型別（`Color`、`Font`、`Image`）的 computed property
- **Domain Model 不跨 feature 共用**：兩個 feature 都要「貼文」時各自定義各自的 `Post`，只帶自己需要的欄位；跨界傳 primitive（見 `mvvmc-structure`）

**L2 規則**（只被一個父 Model 使用的 enum/struct）：

```swift
// MARK: - Domain Models

extension FeatureViewModel {
  struct Order: Identifiable, Equatable, Sendable {
    let id: String
    var status: OrderStatus  // L2
    var totalAmount: Double
  }

  // L2：只被 Order 使用 → 同一個 extension，加 Order Prefix
  // 純值 enum 已隱含 Equatable，只宣告 Sendable 即可
  enum OrderStatus: String, Sendable {
    case pending, confirmed, shipped
  }
}
```

被多個 Model 共用 → 各自獨立 `extension`。

---

### Equatable 規則

**預設全加**：`State` 與 Domain Model 一律遵守 `Equatable`。它們由 Domain Model 與原生型別組成，compiler 自動合成、零成本。好處：

- 測試可直接 `#expect(vm.state == expected)`，不必逐欄位比對
- SwiftUI `.onChange(of:)` / `.animation(value:)` / diffing 需要 `Equatable`

**判斷順序**：先加，遇到以下三種情形才省略（compiler 只擋得住第 1 條，2、3 靠人判斷）：

| # | 情形 | 處理 |
|---|------|------|
| 1 | 含**無法合成 Equatable 的成員**（最常見是閉包 `() -> Void`；也包括 `Any` / `[String: Any]`、非 Equatable 的 class 或第三方型別） | 閉包情形先問「能否移回 VM（`@ObservationIgnored`）？」；其餘（或真的移不走）→ 手寫 `==` 跳過該成員，或改存可比較的替代值 |
| 2 | **一次性丟棄的事件型別**（Log 紀錄、推播 payload 等 write-only / fire-and-forget） | 不加，語意同 DTO |
| 3 | 持有**大型二進位 / 陣列**（數百 MB）且 `==` 會落在 hot path | 優先改為只存 id / URL / version token；非存不可 → 手寫 `==` 比對版本號 / hash，而非逐 byte |

省略時於型別上方以註解說明原因。

---

### DTOs

```swift
// MARK: - DTOs

extension FeatureViewModel {
  struct ItemDTO: Codable, Sendable {
    var item_id: String
    var item_name: String
    var created_at: String

    func toDomain() -> Item? {
      guard !item_id.isEmpty else { return nil }
      return .init(id: item_id, name: item_name)
    }
  }
}
```

- `Codable & Sendable` struct
- **保留 API response 所有欄位**，忠實反映 API 合約
- property 命名直接對齊 API response key（API 是 snake_case 就寫 snake_case，不強制任何風格），不需要 `CodingKeys`
  - **why**：DTO 是拋棄式的「髒資料」，值得關注的是 Domain Model 而非 DTO。命名與 API 維持 1:1 有兩個好處——(1) 好 debug：log / 斷點看到的欄位名就是 API 回的原始 key；(2) 好跟 backend 溝通：兩邊講的是同一個字，中間不隔一層 CodingKeys 翻譯。清理（改 camelCase、取捨欄位）是 `toDomain()` 的責任，髒命名到 `toDomain()` 為止不得外洩
- `toDomain()` 負責轉換與過濾，取捨欄位是 `toDomain()` 的事
- State 不持有 DTO（見〈State 欄位型別〉），UI 層對 DTO 的存在完全透明
- **DTO 不加 `Equatable`**：解碼後立即 `toDomain()` 丟棄，從不參與相等比較，維持 `Codable & Sendable` 即可

---

## Mock 資料

Mock 是 Domain Model 的延伸，供 Preview 與測試使用，因此歸屬 M 層。獨立成 `FeatureNameMocks.swift`，**整檔以 `#if DEBUG` 包裹**，正式 build 不含這些代碼。

```swift
// FeatureNameMocks.swift
#if DEBUG
extension FeatureViewModel.Item {
  static let mock: Self = .init(id: "1", name: "Sample")
  static let mocks: [Self] = [
    .init(id: "1", name: "Sample A"),
    .init(id: "2", name: "Sample B"),
  ]
}
#endif
```

- ✅ `static let mock`（單筆）/ `static let mocks`（多筆）掛在 **Domain Model** 上，不掛在 State 或 DTO
- ✅ 整個 `FeatureNameMocks.swift` 用 `#if DEBUG` 包住，可選檔案
- ✅ Preview 端透過 `state.items = .mocks` 注入（Preview 寫法屬 V 層，見 `mvvmc-view`）
- ❌ 禁止 mock 出現在非 `#if DEBUG` 區塊

---

## 三種任務模式

### 模式 A：新建 Models 檔案

依照上方規範產生代碼，附上「設計說明」：

```
[完整 Swift 代碼]

---
### 設計說明
- **State 欄位**：...
- **Domain Model 設計**：...
- **DTO 設計**：...（若有）
```

### 模式 B：審查現有 Models

```
### 審查報告

✅ 符合規範：
- ...

❌ 違規項目：
| 位置 | 問題 | 規範依據 | 建議修正 |
|------|------|----------|----------|

⚠️ 灰色地帶：
- ...
```

### 模式 C：重構 Models

1. 先輸出審查報告
2. 輸出重構後完整代碼
3. 附上「重構說明」，列出每項改動對應的規範
