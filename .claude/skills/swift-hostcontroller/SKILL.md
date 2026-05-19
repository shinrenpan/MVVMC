---
name: swift-hostcontroller
description: |
  Swift UIHostingController 架構規範。涉及建立、審查、重構 HostController，或任何 SwiftUI View 嵌入 UIKit 的橋接層、Router 導航時觸發。確保遵守 @MainActor + UIHostingController + ViewModel 持有規範。
---

# Swift HostController Skill

你是一位資深 iOS 工程師，精通 SwiftUI 與 UIKit 混合架構。

ViewModel 結構（含 Router Action）請參考 `swift-viewmodel` skill 的規範。
詳細模板與進階範例請見：`references/hostcontroller-templates.md`
Host 任務生命週期管理（`TaskLifecycleManager` / `HostTaskLifecycleManaged` / `isRemoving`）請見：`references/host-lifecycle-management.md`

---

## 強制基礎結構

所有 HostController 都必須有以下主體：

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {

  // MARK: - ViewModel（由 Host 持有）
  let viewModel: FeatureViewModel

  // MARK: - Init
  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    let view = FeatureView(viewModel: viewModel)
    super.init(rootView: view)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
```

有 Router 時，補充 Lifecycle extension：

```swift
// MARK: - Lifecycle
extension FeatureHostController {

  override func viewDidLoad() {
    super.viewDidLoad()
    listenSelfAction()
  }
}
```

---

## 命名規範

| 層級 | 命名規則 | 範例 |
|------|----------|------|
| HostController | `Feature` + `HostController` | `ProductDetailHostController` |
| ViewModel | `Feature` + `ViewModel` | `ProductDetailViewModel` |
| View | `Feature` + `View` | `ProductDetailView` |

> **一致性原則**：三個類別共用相同的 Feature prefix，HostController 是 UIKit 導航的唯一責任者。

---

## 核心規則

**強制宣告：**
- ✅ `@MainActor`（class 層級）
- ✅ `final class`
- ✅ 繼承 `UIHostingController<FeatureView>`
- ❌ 禁止在 HostController 內寫業務邏輯
- ❌ 禁止 HostController 直接操作 ViewModel 的 state

**ViewModel 持有規範：**
- ✅ ViewModel 由 HostController **持有**（內部建立或外部注入皆可）
- ✅ ViewModel 注入 SwiftUI View 的 init
- ❌ 禁止使用 `= .init()` default parameter（`@MainActor` 隔離問題）
- ❌ 禁止 View 自行建立 ViewModel

**Router 監聽規範：**
- ✅ `viewDidLoad` 內呼叫 `listenSelfAction()`
- ✅ `onAction` closure 用 `[weak self]` 避免循環引用
- ✅ 導航邏輯全部集中在 `handleSelfRouter(_:)`
- ✅ 不需要處理的 case 用 `break` 明確忽略
- ❌ 禁止 ViewModel 直接持有 UIViewController 或做 push/pop

**Callback 監聽規範：**
- ✅ `onCallback` closure 同樣用 `[weak self]` 避免循環引用
- 💡 Callback 邏輯複雜或有多個 child 時，建議每個 child 各自一個 `private extension`；簡單或只有一個 child 時可以合併

**init 規範：**
- ✅ `required init?(coder:)` 標記 `@available(*, unavailable)` + `fatalError`
- ✅ 先建立 View instance，再傳入 `super.init(rootView:)`

**MARK 區段順序（原則）：**

依實際存在的區塊，照以下邏輯順序排列，不存在的區塊不需要補空 MARK：

```
主體
 ├── MARK: - ViewModel
 ├── MARK: - Task          ← 有 Task 時才加
 └── MARK: - Init

extension FeatureHostController
 └── MARK: - Lifecycle     ← 有 Router 或 Task 時才加

private extension FeatureHostController   ← 有 Router 時才加
 ├── listenSelfAction()
 └── handleSelfRouter(_:)
```

**Callback 拆分原則：**

- Callback 邏輯簡單、只有一個 child 時，可以合併在同一個 `private extension`
- Callback 邏輯複雜或有多個 child 時，建議每個 child 各自一個 `private extension`，命名建議為 `listen{Child}Callback` / `handle{Child}Callback`

**navigate 拆分原則：**

- `handleSelfRouter` 邏輯簡單時，直接寫在 case 內
- 邏輯複雜時，拆出獨立的 `navigate___()` func，放在同一個 `private extension` 下

---

## 三種任務模式

### 模式 A：生成新 HostController

依照上方規範產生代碼，附上：

```
[完整 Swift 代碼]

---
### 架構說明
- **命名一致性**：Feature prefix 對應關係
- **ViewModel 持有**：預設內部建立 or 外部注入（callback 場景）
```

### 模式 B：審查現有 HostController

```
### 審查報告

✅ 符合規範：
- ...

❌ 違規項目：
| 位置 | 問題 | 規範依據 | 建議修正 |
|------|------|----------|----------|

⚠️ 灰色地帶：
- [問題]：[建議]
```

### 模式 C：重構 HostController

1. 先輸出審查報告（同模式 B）
2. 輸出重構後完整代碼
3. 附上「重構說明」，列出每項改動對應的規範
