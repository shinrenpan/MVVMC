---
name: swift-model
description: |
  Swift Model 建模規範。涉及建立 State、Domain Model、DTO、FeatureViewModel+Models.swift 時觸發。確保三層抽象正確分離，DTO 透過 toDomain() 轉換為 Domain Model。
---

# Swift Model Skill

你是一位資深 iOS 工程師，專注於資料層建模。

此 Skill 的職責範圍是 **`FeatureViewModel+Models.swift` 的內容**，不涉及 ViewModel 本身的實作。

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
  struct State: Sendable {
    var items: [Item] = []
  }
}
```

- `struct`（值類型），遵守 `Sendable`
- 所有屬性給定預設值（確保 `.init()` 無參數可用）
- 欄位只能是 Domain Model、Swift 原生型別、`Optional`

**例外：Detail View 必帶初始資料**

```swift
extension PostDetailViewModel {
  struct State: Sendable {
    let post: Post
  }
}
```

若把欄位改成 `Optional` 會讓 View 層到處 `if let`，且語意上頁面不存在「沒有資料」的狀態，才用此例外。

---

### Domain Models

- 每個獨立 Model 各自一個 `extension`
- 遵守 `Sendable`，有 `id` 時遵守 `Identifiable`
- `let` 用於不可變欄位，`var` 用於可變欄位
- 禁止回傳 UI framework 型別（`Color`、`Font`、`Image`）的 computed property

**L2 規則**（只被一個父 Model 使用的 enum/struct）：

```swift
// MARK: - Domain Models

extension FeatureViewModel {
  struct Order: Identifiable, Sendable {
    let id: String
    var status: OrderStatus  // L2
    var totalAmount: Double
  }

  // L2：只被 Order 使用 → 同一個 extension，加 Order Prefix
  enum OrderStatus: String, Sendable {
    case pending, confirmed, shipped
  }
}
```

被多個 Model 共用 → 各自獨立 `extension`。

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
- property 命名直接使用 API response key（snake_case），不需要 `CodingKeys`
- `toDomain()` 負責轉換與過濾，取捨欄位是 `toDomain()` 的事
- State 不持有 DTO，UI 層對 DTO 的存在完全透明

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
