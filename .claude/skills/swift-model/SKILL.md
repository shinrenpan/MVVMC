---
name: swift-model
description: |
  Swift Model 建模規範。涉及建立 State、Domain Model、DTO、FeatureViewModel+Models.swift 時觸發。確保三層抽象正確分離，DTO 透過 DomainConvertible 轉換為 Domain Model。
---

# Swift Model Skill

你是一位資深 iOS 工程師，專注於資料層建模。

完整範例請見：`references/example.md`

此 Skill 的職責範圍是 **`FeatureViewModel+Models.swift` 的內容**，不涉及 ViewModel 本身的實作。

---

## 設計哲學

三個區塊各自代表不同的抽象層次，**不可混用**：

| 區塊 | 抽象層次 | 消費者 |
|------|----------|--------|
| `State` | UI 狀態 | SwiftUI View，直接綁定 |
| `Domain Models` | 業務語意 | ViewModel 邏輯、State |
| `DTOs` | API 原始資料 | Network Layer，解碼後立即 mapping |

**State**：UI 可直接消費的乾淨狀態，DTO 的存在對 UI 層完全透明。

**DTO**：只負責解碼與 `toDomain()` 轉換，轉換邏輯屬於 DTO 自身，ViewModel 只負責呼叫。

---

## 禁止事項

- ❌ 禁止 Model / DTO 定義在全域（必須嵌套在 `extension FeatureViewModel`）
- ❌ 禁止 `State` 使用 `class`
- ❌ 禁止 `State` 放入 DTO 型別或容錯包裝器（`@SafeBox`、`@SafeArray`）
- ❌ 禁止不相關的多個 Model 塞進同一個 `extension`
- ❌ 禁止把 L2 子資料拆出去獨立 `extension`
- ❌ 禁止超過兩層巢狀（L1 + L2）；L3 需求必須提升為獨立 L1 Model
- ❌ 禁止 DTO property 自行轉換命名（必須保留 API 原始 key）
- ❌ 禁止省略 `// MARK: - State`、`// MARK: - Domain Models`、`// MARK: - DTOs` 區塊標題
- ❌ 禁止 Domain Model 混入 DTOs 區塊，或 DTO 混入 Domain Models 區塊
- ❌ 禁止 DTO 單獨宣告 `Codable` 或 `Sendable`，必須遵守 `DomainConvertible`

---

## 必須遵守

- ✅ 所有 Model / State / DTO 存放在 `FeatureViewModel+Models.swift`
- ✅ 使用 `extension FeatureViewModel { ... }` 嵌套模式
- ✅ 檔案結構固定：`State` → `Domain Models` → `DTOs`
- ✅ 每個獨立 Model / DTO 各自一個 `extension`
- ✅ DTO 遵守 `DomainConvertible`，實作 `toDomain()` 與 `defaultInstance()`
- ✅ DTO property 保留 API 原始 key，視容錯需求包 `@SafeBox` / `@SafeArray`

---

## 核心規範

### State

```swift
// MARK: - State

extension FeatureViewModel {
    struct State: Sendable {
        var orders: [Order] = []
        var isLoading: Bool = false
        var selectedOrder: Order? = nil
        var errorMessage: String? = nil
    }
}
```

- `struct`（值類型），遵守 `Sendable`
- 所有屬性給定預設值（確保 `.init()` 無參數可用）
- 欄位只能是 Domain Model、Swift 原生型別、`Optional`

**例外：Detail View 必帶初始資料**

若 Feature 是 Detail 頁面，且核心資料必須由外部注入（如 `News`、`Order`），欄位可以省略預設值，改由 ViewModel 的自訂 `init` 初始化：

```swift
// ✅ Detail View：core data 必要，無合理預設值
extension NewsDetailViewModel {
    struct State: Sendable {
        let news: News
    }
}

@Observable
@MainActor
final class NewsDetailViewModel: ViewModel {
    var state: State

    init(news: News) {
        state = .init(news: news)
    }
}
```

**判斷依據**：若把欄位改成 `Optional` 會讓 View 層到處 `if let`，且語意上這個頁面不存在「沒有資料」的狀態，就屬於此例外。反之，只要頁面有空狀態（loading、error），仍應給預設值。

---

### Domain Models

- 每個獨立 Model 各自一個 `extension`
- 盡量遵守 `Sendable`，有 `id` 時遵守 `Identifiable`
- `let` 用於不可變欄位，`var` 用於可變欄位

**Computed Property 規則**

無副作用的展示輔助 computed property 可以放在 Domain Model，但有嚴格限制：

- ✅ 允許：純邏輯推導（`var isBull: Bool { regime == "bull" }`）
- ✅ 允許：純字串格式化（`var displayScore: String { ... }`）
- ❌ 禁止：回傳 UI framework 型別（`Color`、`Font`、`Image`）
- ❌ 禁止：依賴外部服務（`PerformanceKit`、`LanguageManager`）

```swift
// ✅ 純邏輯 / 純格式化：可接受
struct Indicator: Sendable {
    let score: Double
    var isBullish: Bool { signal == "bullish" }
    var displayScore: String { ... }
}

// ❌ 禁止：Domain Model import SwiftUI，回傳 Color
struct Indicator: Sendable {
    var color: Color { isBullish ? .green04 : .red01 }  // ❌
}
```

`Color` 等 UI 型別的判斷邏輯移至 View 層，由 View 根據 Domain Model 的 bool 自行決定顏色。

#### L2 規則

L2 = 只被一個父 Model 使用的 enum/struct：
- 與父 Model 放在**同一個 `extension`**
- 命名加上**父 Model 名稱作為 Prefix**（語意足夠清楚時可不加）

```swift
// MARK: - Domain Models

extension FeatureViewModel {
    struct Order: Identifiable, Sendable {
        let id: UUID
        var status: OrderStatus   // L2
        var items: [OrderItem]    // L2
        var totalAmount: Double
    }

    // L2：只被 Order 使用 → 同一個 extension，加 Order Prefix
    enum OrderStatus: String, Sendable {
        case pending, confirmed, shipped, delivered, cancelled
    }

    struct OrderItem: Identifiable, Sendable {
        let id: UUID
        var productName: String
        var quantity: Int
    }
}
```

**判斷標準：**
- 只被一個 Model 使用 → L2，同一個 extension，加父 Model Prefix
- 被多個 Model 共用，或是頂層獨立概念 → 各自獨立 `extension`，不加 Prefix

#### L3 禁止：提升為 L1

```swift
// ❌ L3 巢狀（Order → OrderAddress → OrderAddressGeoPoint）
extension FeatureViewModel {
    struct OrderAddress: Sendable {
        var geoPoint: OrderAddressGeoPoint  // L3，禁止
    }
}

// ✅ GeoPoint 提升為獨立 L1
extension FeatureViewModel {
    struct OrderAddress: Sendable {
        var geoPoint: GeoPoint
    }
}

extension FeatureViewModel {
    struct GeoPoint: Sendable {  // 獨立 L1，不加父層 Prefix
        var lat: Double
        var lng: Double
    }
}
```

---

### DTOs

DTO 依角色分三類，協議要求不同：

| 類型 | 判斷依據 | 協議 |
|------|----------|------|
| **Root DTO** | 直接傳入 `APIManager.request()` 的型別 | `DomainConvertible`（強制） |
| **Sub-DTO（純結構）** | 巢狀在 Root DTO 內，由父層 `toDomain()` 負責轉換 | `Codable & Sendable` |
| **Sub-DTO（字典值）** | 作為 `@SafeBox var dict: [String: SomeDTO]` 的 value | `SafeValue & DefaultProvider` |

**Root DTO** 必須實作：
- `static func defaultInstance() -> Self`：屬性全為預設值的實例，供容錯機制使用
- `func toDomain() -> DomainModel?`：轉換為 Domain Model；不合法資料 guard 後回傳 `nil`

**Sub-DTO** 不需要 `toDomain()`——轉換邏輯由父層 Root DTO 統一負責。

```swift
// ✅ Root DTO：直接被 APIManager 消費，負責映射整筆回應
struct MarketRegimeDTO: DomainConvertible {
    typealias DomainModel = MarketRegime
    @SafeBox var date: String
    var indicators: IndicatorsDTO          // Sub-DTO，由此層負責轉換

    func toDomain() -> MarketRegime? {
        guard !date.isEmpty else { return nil }
        return .init(date: date, indicators: indicators.toIndicatorList())
    }
}

// ✅ Sub-DTO（純結構）：只負責解碼，映射由父層處理
struct IndicatorsDTO: Codable, Sendable {
    var trend_ma: IndicatorItemDTO
    var vix: IndicatorItemDTO

    func toIndicatorList() -> [Indicator] { ... }  // 輔助方法，非 toDomain()
}
```

property 命名保留 API 原始 key（snake_case）：
- 基本型別 → `@SafeBox var field_name: Type`
- 陣列 → `@SafeArray var items: [ItemDTO]`
- 子 DTO（巢狀物件）→ 直接宣告，不需包裝
- L2 子 DTO → 同一個 `extension`，加父 DTO 名稱（去掉 `DTO` 後綴）作為 Prefix

💡 DTO 後綴統一使用 `DTO`（而非 `Response`、`Model`、`Data`）

```swift
// MARK: - DTOs

extension FeatureViewModel {
    struct OrderDTO: DomainConvertible {
        typealias DomainModel = Order

        @SafeBox var order_id: String
        @SafeBox var order_status: String
        @SafeBox var total_amount: Double
        @SafeArray var items: [OrderItemDTO]

        static func defaultInstance() -> OrderDTO {
            OrderDTO(
                order_id: SafeBox(wrappedValue: ""),
                order_status: SafeBox(wrappedValue: ""),
                total_amount: SafeBox(wrappedValue: 0),
                items: SafeArray(wrappedValue: [])
            )
        }

        func toDomain() -> Order? {
            guard !order_id.wrappedValue.isEmpty else { return nil }
            return Order(
                id: UUID(uuidString: order_id.wrappedValue) ?? UUID(),
                status: OrderStatus(rawValue: order_status.wrappedValue) ?? .pending,
                items: items.wrappedValue.compactMap { $0.toDomain() },
                totalAmount: total_amount.wrappedValue
            )
        }
    }

    // L2：只被 OrderDTO 使用 → 同一個 extension，加 Order Prefix
    struct OrderItemDTO: DomainConvertible {
        typealias DomainModel = OrderItem

        @SafeBox var item_id: String
        @SafeBox var product_name: String
        @SafeBox var quantity: Int

        static func defaultInstance() -> OrderItemDTO {
            OrderItemDTO(
                item_id: SafeBox(wrappedValue: ""),
                product_name: SafeBox(wrappedValue: ""),
                quantity: SafeBox(wrappedValue: 0)
            )
        }

        func toDomain() -> OrderItem? {
            guard !item_id.wrappedValue.isEmpty else { return nil }
            return OrderItem(
                id: UUID(uuidString: item_id.wrappedValue) ?? UUID(),
                productName: product_name.wrappedValue,
                quantity: quantity.wrappedValue
            )
        }
    }
}
```

---

## 三種任務模式

### 模式 A：新建 Models 檔案

1. 詢問 Feature 名稱（若未提供）
2. 確認是否有 API 串接（決定是否需要 DTOs 區塊）
3. 輸出完整代碼，附上「設計說明」

```
// FeatureViewModel+Models.swift
[代碼]

---
### 設計說明
- **State 欄位**：...
- **Domain Model 設計**：...
- **L2 判斷**：...
- **DTO 設計**：...（若有）
```

### 模式 B：新增欄位或 Model

1. 確認屬於哪個區塊（State / Domain Models / DTOs）
2. 確認是獨立 Model 還是某個 Model 的 L2
3. 輸出差異，說明放置位置與命名理由

### 模式 C：審查現有 Models

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
