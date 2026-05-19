# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 用途

本專案是作者個人的 MVVMC 開發準則，透過討論、改進、Demo 驗證持續演進。
MVVMC 是作者自行設計的 iOS 架構模式，準則面向個人與協作團隊使用。

---

## 架構：MVVMC

四層職責嚴格分離，SwiftUI + UIKit 混合架構，iOS 17+。

| 層 | 檔案命名 | 職責 |
|---|---|---|
| M | `FeatureViewModel+Models.swift` | State / Domain Models / DTOs |
| VM | `FeatureViewModel.swift` + `FeatureViewModel+APIs.swift` | `@Observable @MainActor`，`doAction` 單一進入點 |
| V | `FeatureView.swift` | 純 SwiftUI，零導航邏輯 |
| C | `FeatureHostController.swift` | UIKit 橋接，Router 導航唯一責任者 |

### Feature 建立順序

M → VM → V → C

### 標準檔案結構

```
Pages/FeatureName/
├── FeatureNameViewModel+Models.swift   ← M
├── FeatureNameViewModel.swift          ← VM
├── FeatureNameViewModel+APIs.swift     ← VM（EndPoint 定義，視需要）
├── FeatureNameView.swift               ← V
├── FeatureNameMocks.swift              ← Mock（#if DEBUG，視需要）
└── FeatureNameHostController.swift     ← C
```

---

## 各層詳細規範

### M — Models

三個區塊，各自獨立 `extension`，不可混用：

| 區塊 | 抽象層次 | 消費者 |
|---|---|---|
| `State` | UI 狀態 | SwiftUI View，直接綁定 |
| `Domain Models` | 業務語意 | ViewModel 邏輯、State |
| `DTOs` | API 原始資料 | Network Layer，解碼後立即 mapping |

- `State` 是 `struct`，遵守 `Sendable`，所有欄位給定預設值
- `API` 是 State 內的子 struct，每個 API 對應一個狀態欄位（`.prepare / .loading / .success / .error`）
- DTO 是 `Codable & Sendable` struct，提供 `toDomain()` 轉換為 Domain Model，轉換邏輯屬於 DTO 自身
- State 不持有 DTO，UI 層對 DTO 的存在完全透明

```swift
// MARK: - State
extension FeatureViewModel {
  struct State: Sendable {
    var api: API = .init()
    var items: [Item] = []
  }

  struct API: Sendable {
    var getItems: APIStatus = .prepare
  }
}

// MARK: - Domain Models
extension FeatureViewModel {
  struct Item: Identifiable, Sendable {
    let id: String
    var name: String
  }
}

// MARK: - DTOs
extension FeatureViewModel {
  struct ItemDTO: Codable, Sendable {
    var item_id: String
    var item_name: String

    func toDomain() -> Item? {
      guard !item_id.isEmpty else { return nil }
      return .init(id: item_id, name: item_name)
    }
  }
}
```

### VM — ViewModel

- `@MainActor @Observable final class`
- 單一進入點：`func doAction(_ action: Action) async`，內部只做 `switch` dispatch
- `Action` enum 固定四個 namespace：

```swift
enum Action: Sendable {
  case view(ViewAction)           // 來自 View 的使用者操作
  case route(Router)              // 導航意圖，透過 onAction? 送至 HostController
  case apiRequest(APIRequest)     // 呼叫 API
  case apiResponse(APIResponse)   // 處理 API 回應，更新 state
}
```

- `onAction` — HostController 設定，接收 `.route` 事件後執行導航
- `onCallback` — 父 HostController 設定，接收跨 VC 回傳值
- Router 不自行導航，統一呼叫 `onAction?(.route(router))` 後由 C 處理
- 非 UI 相關的 property（closure 等）標注 `@ObservationIgnored`

### V — View

- `viewModel` 以 `let` 持有（`@Observable` 自動追蹤，不需 `@State` 或 `@Bindable`）
- 使用者互動統一：`Task { await viewModel.doAction(.view(.xxx)) }`
- 子 View 做成 `private extension FeatureView { struct SubView: View {...} }`
- 子 View 若需回傳 action，接收 `let doAction: @MainActor (Action) -> Void` closure
- Model 的顯示輔助 extension 放 View 檔最頂部：`private extension FeatureViewModel.SomeModel { var color: Color { ... } }`
- **零導航邏輯，零業務邏輯**

### C — HostController

- `@MainActor final class`，繼承 `UIHostingController<FeatureView>`
- **純 Router**：push / present / dismiss 全在這裡，不做任何 task 管理
- `viewDidLoad`：設定 `viewModel.onAction` 監聽 `.route` 事件
- `viewDidDisappear`：清空 `onAction` / `onCallback` closure，防止 retain cycle
- HostController 不管 lifecycle 觸發，不持有任何 Task
- 監聽子 VC 回傳：present 前設定 `childViewModel.onCallback`

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {
  private let viewModel: FeatureViewModel

  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    super.init(rootView: FeatureView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onAction = { [weak self] action in
      guard case let .route(router) = action else { return }
      self?.handleRouter(router)
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    viewModel.onAction = nil
  }
}
```

---

## 資料流

```
使用者操作
  → View: Task { await viewModel.doAction(.view(.xxx)) }
  → VM handleViewAction → doAction(.apiRequest / .route)

API 請求:
  → VM handleAPIRequest → 呼叫 API → doAction(.apiResponse)
  → VM handleAPIResponse → 更新 state → View 自動刷新

導航:
  → VM: onAction?(.route(.toXxx))
  → HostController → push / present

跨 VC 回傳:
  → 子 VM: onCallback?(.callback(.xxx))
  → 父 HostController → 處理結果
```

---

## Xcode Template

新建 Feature 使用 Xcode File Template，不使用 `feature-new` skill（已移除）。

Template 原始檔：`Templates/MVVMC Feature.xctemplate/`

安裝（新機器時執行）：
```bash
cp -r Templates/MVVMC\ Feature.xctemplate ~/Library/Developer/Xcode/Templates/File\ Templates/MVVMC/
```

使用：Xcode → New File → MVVMC → MVVMC Feature → 輸入 Feature 名稱（如 `UserProfile`）

產生四個檔案：
- `FeatureViewModel+Models.swift` — State、Domain Models、DTOs 骨架
- `FeatureViewModel.swift` — `@Observable @MainActor`、`doAction` 單一進入點
- `FeatureView.swift` — SwiftUI placeholder + Preview
- `FeatureHostController.swift` — 純 Router（viewDidLoad 設 onAction，viewDidDisappear 清 onAction）

---

## 常見情境

### 只執行一次（viewDidLoad 等價）

**問題**：SwiftUI 的 `.onAppear` / `.task` 每次畫面出現都觸發，沒有天然的 `viewDidLoad` 等價。

**解法**：`isFirstAppear` 和 `pullToRefresh` 是語意不同的兩個 ViewAction，都指向同一個 APIRequest。

```swift
enum ViewAction: Sendable {
  case isFirstAppear
  case pullToRefresh
}

enum APIRequest: Sendable {
  case loadData
}
```

```swift
// View
.task {
  await viewModel.doAction(.view(.isFirstAppear))
}

.refreshable {
  await viewModel.doAction(.view(.pullToRefresh))
}
```

```swift
// ViewModel
case .isFirstAppear:
  guard state.isFirstAppear else { return }
  state.isFirstAppear = false
  await doAction(.apiRequest(.loadData))

case .pullToRefresh:
  await doAction(.apiRequest(.loadData))
```

- `isFirstAppear` action 名稱本身說明了 run once 語意
- `loadData` 乾淨，不帶任何 lifecycle 假設
- View 不直接碰 State，ViewModel 仍是唯一責任者

---

## Mock / Preview

```swift
// FeatureNameMocks.swift — 整個檔案包 #if DEBUG
#if DEBUG
extension FeatureViewModel.SomeDomainModel {
  static let mock: Self = .init(...)
  static let mocks: [Self] = [...]
}
#endif

// View 底部 Preview
#if DEBUG
#Preview("狀態描述") {
  let vm = FeatureViewModel()
  vm.state.items = .mocks
  return FeatureView(viewModel: vm)
}
#endif
```
