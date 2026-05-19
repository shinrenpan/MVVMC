# SwiftUI 開發規範與架構指南

## 核心哲學
- **角色定位**：資深 iOS 工程師（效能與架構專家）
- **開發風格**：「重複造輪子派」——比起依賴第三方庫，更傾向建立高封裝、低耦合、可完全掌控的自定義組件
- **終極目標**：極致的渲染效能、明確的代碼語意、高度的模組可移植性

---

## 1. 檔案結構與組件嵌套

- **單一檔案原則**：主視圖與其專屬子視圖放在同一個檔案
- **極致封裝**：所有子視圖必須標記為 `private`
- **嵌套模式**：一律使用 `private extension` 嵌套子組件

**嚴禁：**
- Top-level 平鋪子視圖
- 使用 `@ViewBuilder` Computed Property（即 `var foo: some View`）拆分 body

**建議：**
- 當 `body` 過長時，使用 `@ViewBuilder private func` 拆分，而非 Computed Property
  ```swift
  // ✅ 建議：function 有括號，語意清楚是「body 拆分」而非「組件」
  @ViewBuilder private func userSection() -> some View { ... }

  // ❌ 禁止：Computed Property 語意模糊，難以與組件區分
  private var userSection: some View { ... }
  ```

---

## 2. 數據流管理 (Data Flow)

- **觀測框架**：全面採用 iOS 17+ 的 `@Observable` 框架
- **精準注入**：子組件只拿取「最小必要」數據
- **禁止**：將整個 ViewModel 實例直接傳入子組件

**傳遞機制：**
| 情境 | 方式 |
|------|------|
| ReadOnly | 直接透過 `let` 參數傳遞 |
| Read-Write | 透過 `@Binding` 傳遞，父層藉由 `@Bindable` 產生綁定 |

**Binding vs Action 的選擇邊界：**
- **值的雙向同步** → `@Binding`：子組件需要回寫一個值給父層（例如 TextField 輸入、Toggle 開關），不帶語意，只是資料同步
- **事件的語意通知** → `enum Action`：子組件發生了某件事，需要通知父層決策（例如按鈕點擊、選單選取），帶有明確的業務語意

```swift
// ✅ 值同步 → Binding（query 改變就直接回寫，不需要語意包裝）
struct SearchBar: View {
    @Binding var query: String
    var body: some View {
        TextField("Search", text: $query)
    }
}

// ✅ 事件通知 → Action（Submit 是一個帶語意的事件，父層需要決策）
struct SearchBar: View {
    enum Action: Sendable { case submitDidTap }
    @Binding var query: String
    let send: (Action) -> Void
    var body: some View {
        TextField("Search", text: $query)
        Button("Submit") { send(.submitDidTap) }
    }
}
```

---

## 3. 多層級通訊規範 (Action Handling)

- **模式**：Intent-based Action Pattern（MVI/TCA 靈魂）
- **需要對外通訊的層**必須定義自己專屬的 `enum Action`（啟動條件見下方）
- **Action 嵌套位置**：`enum Action` 必須**嵌套在該層的 View struct 內**，與 View 緊耦合
- **Sendable 強制**：所有 `enum Action` 必須標註 `Sendable`，與 swift-viewmodel skill 規範對齊
- **中間層（Parent）**負責將底層（Child）的 Action 對映給上層（GrandParent）
- **參數命名統一**：Action closure 定義端一律命名為 `let send: (Action) -> Void`；呼叫端 `send:` 為最後一個參數時，允許 trailing closure，否則用 `send:` 標籤明確標示
- **目的**：確保每一層組件都能獨立拆卸使用，不產生跨層級的命名空間污染

```swift
// ✅ 正確：Action 包在 View 裡，標註 Sendable
struct ListSection: View {
    enum Action: Sendable {
        case addToCart(Product)
    }
    let send: (Action) -> Void
}

// ❌ 錯誤：Action 在 View 外的獨立命名空間
private extension ProductListView {
    enum List { enum Action { case addToCart(Product) } }
    struct ListSection: View { ... }
}

// ❌ 錯誤：缺少 Sendable
struct ListSection: View {
    enum Action {  // 應為 enum Action: Sendable
        case addToCart(Product)
    }
}
```

### enum Action 的啟動條件

`enum Action` 是**該層需要主動向上層發送事件**時才需要定義的，並非每個 View 都強制。

**需要 enum Action 的情境**：
- 該層有使用者互動元素（按鈕、輸入、Menu、Toggle 等）
- 該層有需要通知父層的內部事件（生命週期、狀態變化）

**不需要 enum Action 的情境**：
- **純展示元件**：只把資料顯示出來，無任何使用者互動
- **純佈局 / 純透傳層**：只負責組合排列子層，或將子層 closure 原封透傳給上層，自身不產生任何事件

```swift
// ✅ 純展示元件：不需要 enum Action
struct UserCardSection: View {
    let user: User

    var body: some View {
        HStack {
            AsyncImage(url: user.avatarURL)
            VStack {
                Text(user.name)
                Text(user.bio)
            }
        }
    }
}

// ✅ 純佈局 / 純透傳層：不需要 enum Action，直接透傳子層 closure
struct OverviewSection: View {
    let chartData: [ChartItem]
    let listData: [ListItem]
    let send: (ListSection.Action) -> Void

    var body: some View {
        VStack {
            ChartSection(data: chartData)
            ListSection(items: listData, send: send)
        }
    }
}
```

**禁止的反模式**：

不要為了滿足「每層有 enum Action」的形式而定義空 enum 或單 case 包裝 enum：

```swift
// ❌ 為形式而存在的空 enum
struct UserCardSection: View {
    enum Action: Sendable {}
    let send: (Action) -> Void
}

// ❌ 單 case 包裹子層 enum，毫無資訊量
struct OverviewSection: View {
    enum Action: Sendable {
        case list(ListSection.Action)
    }
    let send: (Action) -> Void
}
```

### Action 命名應反映「該層發生的事」

每層的 `enum Action` 應從**該層自身視角**描述事件，而非預設上層需要的業務語意。

```swift
// ❌ 錯誤：子層 Action 用了父層的業務語意
struct ListCellMenu: View {
    enum Action: Sendable {
        case closePositionDidTap(DisplayItem)   // 「close position」是業務概念
        case adjustmentDidTap(DisplayItem)      // 不是 Menu 這層發生的事
    }
}

// ✅ 正確：子層 Action 描述該層真實事件
struct ListCellMenu: View {
    enum MenuItem { case close, adjust, performance }
    enum Action: Sendable {
        case menuItemDidTap(MenuItem)           // Menu 上有選項被選了
    }
}

// 中間層做真正的 Mapping，補上業務語意
case .menuItemDidTap(.close):
    send(.closePositionDidTap(item))
case .menuItemDidTap(.adjust):
    send(.adjustmentDidTap(item))
```

### 純 Forwarding 視為設計缺陷訊號

當你發現自己在寫純 Forwarding——**子父 Action 同 case、同 associated value，中間層只是轉手**——這通常意味著子層的 Action 命名已被父層業務語意污染：

```swift
// ❌ 純 Forwarding：中間層沒做任何加工
case .closePositionDidTap(let item):
    send(.closePositionDidTap(item))
case .adjustmentDidTap(let item):
    send(.adjustmentDidTap(item))
```

遇到這種情況，回頭重新設計子層命名，讓它從子層自身視角描述事件，中間層轉換為真正的 Mapping。

**例外允許**：
- 中間層的職責是**佈局組合或狀態整合**（例如把 N 個 L3 排列成 List），而非語意加工
- 該層對該 Action 確實沒有額外語意可加，且子層 Action 命名已從子層視角設計
- 此時 Forwarding 是誠實的「我不加工」表達

但若整個中間層的 Action 處理**全部都是 Forwarding，沒有任何 Mapping、佈局組合、狀態整合的職責**，這個中間層應該被消除——讓父層直接持有 L3，而不是用 Forwarding 合理化中間層的存在。

**嚴禁：**
- 使用 `@Environment` 傳遞自定義 Action

---

## 4. 組件命名與 Extension 分組規則

### 命名規則
| 層級 | 規則 | 範例（View 名稱為 `ProductListView`） |
|------|------|--------------------------------------|
| L2 | 省略 View 名稱前綴，**統一使用 `Section` 後綴** | `ListSection`（非 `ProductListSection`） |
| L3 | 沿用 L2 前綴（省略 `Section`），**語意自由命名** | `ListRow`、`ListCartBadge`、`ListInfo` |
| L4+ | 遞迴沿用直屬父層前綴，語意自由命名 | `ListRowIcon`（從 ListRow 深挖） |

**關鍵原則**：
- 前綴代表「從哪裡長出來」，而非「屬於哪個 View」
- L2 的 `Section` 後綴是唯一強制後綴；L3+ 後綴由語意決定（`Row`、`Info`、`Card`、`Badge`... 等），不強制統一

### Extension 分組規則
- **同前綴的所有組件**必須放在**同一個** `private extension` 下
- 一個 extension = 一個功能島嶼，所有相關組件集中管理
- 各組件的 `enum Action` 嵌套在自己的 View struct 內（見 §3）

```swift
// ✅ 正確：List 家族全部集中，Action 各自包在自己的 View 內
private extension ProductListView {
    struct ListSection: View {                                   // L2
        enum Action: Sendable { case addToCart(Product) }
        ...
    }
    struct ListRow: View {                                       // L3
        enum Action: Sendable { case rowDidTap }
        ...
    }
    struct ListCartBadge: View { ... }                           // L4，無 Action 也可
}

// ❌ 錯誤：分散在不同 extension
private extension ProductListView {
    struct ListSection: View { ... }
}
private extension ProductListView {
    struct ListRow: View { ... }        // 應和 ListSection 同一個 extension
}
```

### 跨 Section 共用組件的處理

當一個 L3 零件需要被**多個不同 Section 共用**時，不應強行塞進某一個 Section 的 `private extension`（會造成反向依賴）。這種情況代表該組件已超出單一 Section 的範疇，應**提拔為獨立的 L1 檔案**：

```swift
// ❌ 錯誤：TagBadge 塞進 ListSection 的 extension，FilterSection 反向依賴
private extension ProductListView {
    struct ListSection: View { ... }
    struct TagBadge: View { ... }   // 但 FilterSection 也需要用它
}

// ✅ 正確：TagBadge 獨立成自己的檔案，作為可跨頁面複用的共用組件
// TagBadge.swift（獨立 L1，public 或 internal）
struct TagBadge: View {
    let tag: Tag
    var body: some View { ... }
}

// 各 Section 直接引用
private extension ProductListView {
    struct ListSection: View {
        // 直接使用 TagBadge，無需包在 private extension 內
    }
}
```

> **判斷原則**：一旦一個組件需要跨兩個以上的 View 檔案使用，它就不再「專屬」於任何一個，應獨立成共用組件。共用組件不屬於任何頁面的 `private extension`，也不應帶有頁面前綴。

---

## 5. 深度與扁平化的決策準則 (Refactoring)

- **三層限制**：邏輯嵌套建議控制在 3 層以內（L1 → L2 → L3）

**向下深挖到 L4**：僅適用於「無狀態」的純 UI 裝飾零件（不需要與 VM 通訊）

**向上提拔為獨立 L2**：當 L3 組件出現以下任一情況：
1. 開始擁有複雜的業務邏輯
2. Action 的處理邏輯開始複雜，難以在父層簡單 switch 消化（數量本身不是門檻，邏輯複雜度才是）
3. 必須經過兩層以上的中繼站才能傳遞一個 Binding

**向下消除 L2（讓 L1 直接持有 L3）**：當一個中間層出現以下情況：
1. 自身沒有任何佈局組合、狀態整合的職責
2. 所有 Action 處理全部是純 Forwarding（子父 case 同名、同 associated value，中間層零加工）
3. 消除後 L1 直接持有 L3，代碼反而更清晰

> 純 Forwarding 是設計缺陷訊號，詳見 §3「純 Forwarding 視為設計缺陷訊號」。消除 L2 前，先確認是否能透過重新設計子層 Action 命名來解決（讓 Forwarding 變成真正的 Mapping），而不是直接消除層級。

---

## 6. 三層架構實作模板

### View 持有 ViewModel 的規範

本架構搭配 `swift-hostcontroller` skill 使用，採 **UIHostingController + SwiftUI View** 模式。

- ✅ ViewModel 由 **HostController 建立並持有**
- ✅ View 透過 `let viewModel: FeatureViewModel` 接收引用
- ❌ **禁止**：View 用 `@State private var viewModel = FeatureViewModel()` 自建

```swift
// ✅ 正確：View 接收外部注入的 ViewModel
struct FeatureView: View {
    let viewModel: FeatureViewModel
}

// ❌ 錯誤：View 自建 ViewModel
struct FeatureView: View {
    @State private var viewModel = FeatureViewModel()
}
```

**理由**：
- ViewModel 生命週期由 HostController 管理（UIKit 導航棧）
- 與 Router、Coordinator 整合需要外部建立 VM
- 此規範與 `swift-hostcontroller` skill 對齊（該 skill 明確禁止 View 自建 ViewModel）

### 模板

```swift
// Level 1: GrandParent（接收 HostController 注入的 ViewModel）
struct FeatureView: View {
    let viewModel: FeatureViewModel

    var body: some View {
        @Bindable var bVM = viewModel
        MainSection(text: $bVM.state.name, val: viewModel.state.score) { action in
            switch action {
            case .updateDidTap:
                Task { await viewModel.doAction(.view(.updateDidTap)) }
            }
        }
    }
}

private extension FeatureView {
    // Level 2: Parent（中繼站 / 佈局層）
    struct MainSection: View {
        enum Action: Sendable { case updateDidTap }

        @Binding var text: String
        let val: Int
        let send: (Action) -> Void
        var body: some View {
            SubComponent(value: val) { childAction in
                switch childAction {
                case .triggerDidTap: send(.updateDidTap)
                }
            }
        }
    }

    // Level 3: Child（獨立輪子 / 零件層）
    struct SubComponent: View {
        enum Action: Sendable { case triggerDidTap }

        let value: Int
        let send: (Action) -> Void
        var body: some View {
            Button("\(value)") { send(.triggerDidTap) }
        }
    }
}
```

### L1 與 ViewModel 的銜接規則

L1 在處理 L2 上拋的 Action 時，必須走 `viewModel.doAction(.view(...))`，**禁止呼叫 ViewModel 上的其他 public method**。此規範與 swift-viewmodel skill 對齊（ViewModel 唯一進入點是 `doAction(_:)`）。

```swift
// ✅ 正確
case .updateDidTap:
    Task { await viewModel.doAction(.view(.updateDidTap)) }

// ❌ 禁止：繞過 doAction 直接呼叫
case .updateDidTap:
    viewModel.doSomething()

// ❌ 禁止：直接 await（必須包在 Task 裡）
case .updateDidTap:
    await viewModel.doAction(.view(.updateDidTap))
```

### Action case 命名風格

ViewAction case 採用**事件風格**——表達「使用者做了什麼」而非「ViewModel 該做什麼」：

```swift
// ✅ 事件風格（推薦）
case orderHistoryButtonDidTap
case investButtonDidTap
case rebalanceDidTap

// ❌ 動詞風格（避免）
case showOrderHistory
case startInvesting
case rebalance
```

事件風格的好處：View 層只描述客觀事件，業務語意（要做什麼）由 ViewModel 內部決定，符合 MVI/TCA 的 Intent 概念。

### L1 多 Action handler 的拆分（建議）

當 L1 持有多個 L2 且各自都有 Action 時，把 switch 寫在 body 內會讓 body 過於擁擠：

```swift
// ⚠️ 可運作但 body 雜亂
var body: some View {
    ScrollView {
        TopSection(...) { action in
            switch action {
            case .orderHistoryButtonDidTap:
                Task { await viewModel.doAction(.view(.orderHistoryButtonDidTap)) }
            }
        }
        InvestSection(...) { action in
            switch action {
            case .investButtonDidTap:
                Task { await viewModel.doAction(.view(.investButtonDidTap)) }
            }
        }
        ListSection(...) { action in
            switch action {
            case let .needRebalance(strategyId): ...
            case let .closePositionDidTap(item): ...
            // ...更多 case
            }
        }
    }
}
```

**建議寫法**：把每個 L2 的 Action handler 抽成 `handleXxxAction(_:)` private func：

```swift
// ✅ body 簡潔，handler 各自獨立
// handleXxxAction 寫在 FeatureView struct 本體內（非 private extension 內）
// 屬於 L1 的協調邏輯，與 body 同層
struct FeatureView: View {
    let viewModel: FeatureViewModel

    var body: some View {
        ScrollView {
            TopSection(..., send: handleTopAction)
            InvestSection(..., send: handleInvestAction)
            ListSection(..., send: handleListAction)
        }
    }

    private func handleTopAction(_ action: TopSection.Action) {
        switch action {
        case .orderHistoryButtonDidTap:
            Task { await viewModel.doAction(.view(.orderHistoryButtonDidTap)) }
        }
    }

    private func handleInvestAction(_ action: InvestSection.Action) { ... }
    private func handleListAction(_ action: ListSection.Action) { ... }
}

// private extension 內只放子組件 struct，不放 handler func
private extension FeatureView {
    struct TopSection: View { ... }
    struct InvestSection: View { ... }
    struct ListSection: View { ... }
}
```

**性質**：建議而非強制。何時抽出由開發者依 body 可讀性自行判斷——L2 數量少且 Action case 也少時，inline switch 反而更直觀。

---

## 7. 效能優化標準

### `@ViewBuilder func` vs `struct View` 的本質差異

`@ViewBuilder private func` 只是把 `body` 拆開寫，提升**可讀性**，但不解決**效能**問題。

```swift
// PortfolioView.body 執行時，以下所有 func 全部重新執行
// 只要 ViewModel 任何屬性改變，整個 View 樹全部重跑
var body: some View {
    topBar()        // @ViewBuilder func — 無法跳過
    listSection()   // @ViewBuilder func — 無法跳過
    marqueeSection() // @ViewBuilder func — 無法跳過
}
```

獨立的 `struct View` 則讓 SwiftUI 能做**屬性等價性檢查（Structural Identity）**：

```swift
// SwiftUI diffing：props 沒變 → 整個 ListSection.body 直接跳過
ListSection(items: state.items, send: send)
```

| | `@ViewBuilder func` | `struct View`（L2/L3）|
|---|---|---|
| 本質 | 同一個 body 的延伸 | 獨立的 View 單元 |
| SwiftUI diffing | ❌ 無法跳過 | ✅ props 不變就跳過整個 body |
| 適用場景 | 提升可讀性，無效能需求 | 需要效能隔離 |
| 代碼成本 | 低（直接寫 func） | 高（需定義 struct、Action、參數） |

---

### 拆與不拆的決策準則

**應該拆成獨立 `struct`（效能優先）：**
1. 資料來源是**高頻更新**的（WebSocket、Timer、動畫）
2. 區塊的**核心資料獨立**，更新來源與其他區塊不同（不需要 100% 無共用，共用少數 config 或環境變數是可接受的）
3. 區塊本身**夠複雜**，有自己的 Action 或子組件

**不需要拆（可讀性優先）：**
1. 資料幾乎**靜態不變**（頁面標題、固定按鈕）
2. 區塊**非常簡單**，拆出去只增加樣板代碼
3. 區塊資料與父層高度耦合，拆了反而需要傳很多參數

**灰色地帶判斷：**
> 問自己：「這個區塊的資料，在其他區塊更新時會跟著變嗎？」
> - 會 → `@ViewBuilder func` 即可，反正都要重跑
> - 不會 → 拆成 `struct`，讓 SwiftUI 幫你跳過

---

### 實際案例

以一個「商品列表頁」為例，頁面包含：標題列（靜態）、商品列表（使用者操作後更新）、即時價格跑馬燈（高頻更新）：

```swift
// ❌ 全部用 @ViewBuilder func
// 即時價格每秒更新 → 整個頁面包含標題列和商品列表全部重跑
var body: some View {
    headerBar()      // 靜態標題，但跟著重跑
    productList()    // 使用者操作才更新，但跟著重跑
    priceTicker()    // 高頻更新，拖累整個頁面
}

// ✅ 依更新頻率決定是否拆 struct
var body: some View {
    // 靜態 → @ViewBuilder func 即可，省去 struct 的樣板成本
    headerBar()

    // 使用者操作才更新，且資料獨立 → 拆成 struct
    // items 沒變時 SwiftUI 直接跳過，不受 priceTicker 更新影響
    ProductListSection(items: state.items, send: send)

    // 高頻更新，且核心資料獨立 → 拆成 struct
    // 每秒更新只重跑這個 struct，不影響 ProductListSection
    PriceTickerSection(prices: state.prices)
}
```

---

- **渲染跳過**：確保子組件為獨立 `struct`，以利 SwiftUI 透過屬性等價性檢查跳過不必要的重繪
- **延遲讀取**：數據讀取應發生在最深層的子組件，避免父層 body 因無關屬性變動而導致全域重繪

```swift
// ❌ 父層提前讀取：viewModel.user.name 變動 → L1 body 重跑 → ProfileSection 重建
// 即使 ProfileSection 只顯示 user.name，其他屬性的變動也會拖動它
var body: some View {
    ProfileSection(name: viewModel.user.name, bio: viewModel.user.bio)
    StatsSection(count: viewModel.stats.count)
}

// ✅ 延遲讀取：把整個 user 傳進去，讓 ProfileSection 自己決定讀哪些欄位
// SwiftUI 在 ProfileSection.body 執行時才真正讀取屬性，追蹤範圍更精準
var body: some View {
    ProfileSection(user: viewModel.user)
    StatsSection(stats: viewModel.stats)
}
```

- **現代 API**：數值變動應搭配 `.contentTransition(.numericText())`

---

## 8. 開發陷阱與防呆

### ForEach 中的 @State 身份錯位

當 `ForEach` 內的子組件持有 `@State`，SwiftUI 預設用「結構性身份」（位置）而非「資料身份」識別 view，列表順序變動時狀態會跟著位置走而非資料走，導致狀態錯位。

```swift
// ⚠️ 列表重排時，isExpanded 會留在原本的位置上，跑到錯誤的元素
struct ChildView: View {
    let item: Item
    @State private var isExpanded = false
    ...
}

ForEach(items, id: \.id) { item in
    ChildView(item: item)
}
```

**修正**：父層加上 `.id(item.id)`，把 view 身份綁到資料 id：

```swift
ForEach(items, id: \.id) { item in
    ChildView(item: item)
        .id(item.id)
}
```

**副作用**：列表重排時 view 會重建，`@State` 會重置（使用者看到展開狀態消失）。

- 若重置是**可接受的行為**（例如展開狀態是暫態 UI，離開頁面後不需保留），`.id(item.id)` 本身就是完整的解法，不需要進一步處理。
- 若需要狀態**跨重排保留**，才應將狀態提升到 ViewModel state 層。

**狀態提升的具體做法**：把 `@State` 移出子組件，改存在 ViewModel 的 `State` 中，以 item id 作為 key：

```swift
// ViewModel State（參考 swift-model skill）
struct State {
    var items: [Item] = []
    var expandedItemIDs: Set<Item.ID> = []   // 原本在子組件的 @State
}

// L1：把對應 item 的展開狀態傳入子組件
ForEach(viewModel.state.items, id: \.id) { item in
    ChildView(
        item: item,
        isExpanded: viewModel.state.expandedItemIDs.contains(item.id)
    ) { action in
        switch action {
        case .expandDidTap:
            Task { await viewModel.doAction(.view(.expandDidTap(item.id))) }
        }
    }
}

// 子組件：純展示，不持有 @State
struct ChildView: View {
    enum Action: Sendable { case expandDidTap }
    let item: Item
    let isExpanded: Bool
    let send: (Action) -> Void
}
```

狀態的 Model 定義放在 `FeatureViewModel+Models.swift`，詳見 `swift-model` skill。

---

## 9. 灰色地帶判斷原則

遇到規範未明確涵蓋的情況時：
1. 優先考慮「效能」與「可移植性」哪個更重要
2. 說明判斷理由，讓使用者知道為何這樣選擇
3. 若有更好的替代方案，一併列出供參考

---

## 10. Slot 模式（@ViewBuilder）

當容器層需要保留**結構與樣式**，但允許呼叫方自由填入**內容**時，使用 `@ViewBuilder` Slot 模式：

```swift
struct CardContainer<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .overlay(content)
    }
}
```

### 適用層級

- **L2 / L3** 作為容器角色時最常見（例如 `CardSection`、`ModalRow`）
- L1 通常不需要 Slot，L1 的職責是組合已知的 L2，而非提供開放插槽

### Slot 容器是否需要 enum Action？

Slot 容器本身通常是**純包裝層**——只負責外框的樣式，不產生自己的事件。依 §3 啟動條件：

```swift
// ✅ 純包裝容器：不需要 enum Action
// 容器只管圓角與陰影，互動邏輯由 content 內部自行定義
struct CardContainer<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .shadow(radius: 4)
            .overlay(content)
    }
}
```

若容器本身**也有互動**（例如整張卡片可點擊），才需要加上自己的 `enum Action`：

```swift
// ✅ 容器有自身事件：需要 enum Action
struct TappableCard<Content: View>: View {
    enum Action: Sendable { case cardDidTap }
    @ViewBuilder let content: Content
    let send: (Action) -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .overlay(content)
            .onTapGesture { send(.cardDidTap) }
    }
}
```

### 何時用 Slot vs 一般參數傳遞

| 情境 | 建議 |
|------|------|
| 容器外框固定，內容由呼叫方完全決定 | Slot（`@ViewBuilder`） |
| 內容有限且可列舉（如標題 + 副標題） | 一般 `let` 參數 |
| 內容需要與容器雙向溝通（Binding、Action） | 優先考慮一般參數；若 content 本身複雜，可 Slot + closure 並用（容器提供 closure 參數，content 仍走 Slot） |
| 內容本身複雜，包含多個子組件 | Slot（避免把複雜 init 堆在容器上） |

---

## 11. 參數管理策略（body 過長時）

### 啟動條件（建議性質）

當 View struct 的**參數**數量讓 init 開始顯得擁擠時，停下來思考：

> 「這些參數彼此語意相關嗎？是不是其實同一個 Model 的不同欄位？」

**參考點**：
- 1-2 個參數 → 通常無需介入
- 3-4 個參數 → 開始檢查語意內聚性
- 5 個以上 → 強烈建議重構

**參考點不是強制門檻**——3 個參數但語意完全無關，維持原狀比強行包 Model 更乾淨；5 個參數但真的都互不相關（罕見），也可保留現狀並加註原因。

**參數計算範圍**：所有 init 參數（`let` / `@Binding` / closure）皆計入。但 closure 通常承擔通訊職責，視覺權重較低，閱讀時可酌情忽略。

### 真正的判斷依據

1. **語意內聚**：參數是否來自同一個 Model 的多個欄位？
   → 是 → 方案 B（Model Slice）
2. **跨來源**：參數是否來自多個 ViewModel 或混雜來源？
   → 是 → 方案 A（Config Struct）
3. **彼此獨立**：參數彼此無關且都必要？
   → 維持原狀，視為合理設計

---

### 優先：方案 B — Model Slice
當 body 參數過多影響可讀性時，優先直接傳入 Model slice，Binding 單獨傳遞：

```swift
// L1：@Bindable 統一在 body 內宣告，拆分 func 時以參數傳入
struct UserProfileView: View {
    let viewModel: UserProfileViewModel

    var body: some View {
        @Bindable var bVM = viewModel
        userSection(bVM: bVM)
    }

    // bVM 透過參數傳入，避免在 func 內重新宣告
    @ViewBuilder private func userSection(bVM: Bindable<UserProfileViewModel>) -> some View {
        UserSection(
            user: viewModel.state.user,   // Model slice（ReadOnly）
            bio: $bVM.state.user.bio      // Binding 單獨傳（Read-Write）
        ) { action in ... }
    }
}

// L2：接收 slice，自行決定往下傳哪些欄位
struct UserSection: View {
    enum Action: Sendable {
        case saveDidTap
    }

    let user: User
    @Binding var bio: String
    let send: (Action) -> Void
}
```

> **規則**：`@Bindable` 一律在 `body` 內宣告，不在 func 內部重新建立。拆分後的 `@ViewBuilder private func` 若需要 Binding，必須把 `bVM: Bindable<VM>` 作為參數接收，而非自行宣告新的 `@Bindable`。

**優點：**
- 零額外定義成本
- 數據流向一眼清楚
- L2 承擔分解責任，符合「精準注入」精神

**注意：** Model 新增欄位時，L2 不會被強迫更新，需靠 code review 補償。

---

### 備用：方案 A — Config Struct
以下情況才考慮引入 Config：
- 參數來源混雜（非單一 Model）
- 需要跨多個 ViewModel 組合數據

```swift
struct UserSection: View {
    enum Action: Sendable {
        case saveDidTap
    }
    
    struct Config {
        let name: String
        var bio: Binding<String>
        let friendCount: Int
    }
    let config: Config
    let send: (Action) -> Void
}
```

Config 定義在「被呼叫的層」，由「呼叫方」負責組裝。各層皆適用，非強制。
