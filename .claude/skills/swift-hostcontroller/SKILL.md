---
name: swift-hostcontroller
description: |
  Swift UIHostingController 架構規範。涉及建立、審查、重構 HostController，或任何 SwiftUI View 嵌入 UIKit 的橋接層、Router 導航時觸發。確保遵守 @MainActor + UIHostingController + 純 Router 規範。
---

# Swift HostController Skill

你是一位資深 iOS 工程師，精通 SwiftUI 與 UIKit 混合架構。

ViewModel 結構（含 Router）請參考 `swift-viewmodel` skill 的規範。
詳細模板請見：`references/hostcontroller-templates.md`

---

## 強制基礎結構

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {

  private let viewModel: FeatureViewModel

  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    super.init(rootView: FeatureView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
```

---

## 命名規範

| 層級 | 命名規則 | 範例 |
|------|----------|------|
| HostController | `Feature` + `HostController` | `PostListHostController` |
| ViewModel | `Feature` + `ViewModel` | `PostListViewModel` |
| View | `Feature` + `View` | `PostListView` |

---

## 核心規則

**強制宣告：**
- ✅ `@MainActor`（class 層級）
- ✅ `final class`
- ✅ 繼承 `UIHostingController<FeatureView>`
- ❌ 禁止在 HostController 內寫業務邏輯
- ❌ 禁止 HostController 直接操作 ViewModel 的 state
- ❌ 禁止 HostController 啟動 Task 觸發 ViewModel 邏輯（Lifecycle 由 SwiftUI `.task` 負責）

**ViewModel 持有規範：**
- ✅ ViewModel 由 HostController 持有（`private let`）
- ✅ ViewModel 注入 SwiftUI View 的 init
- ❌ 禁止 View 自行建立 ViewModel

**純 Router 規範：**
- ✅ `viewDidLoad` 設定 `viewModel.onRoute`，監聽導航意圖
- ✅ `onRoute` closure 用 `[weak self]`
- ✅ 導航邏輯集中在 `handleRouter(_:)`
- ❌ 禁止 ViewModel 直接持有 UIViewController 或做 push/pop
- ❌ 不需要 `viewDidDisappear` 清空 closure（ViewModel 由 HostController 持有，`[weak self]` 已足夠）

**onCallback 規範（Modal 回傳）：**
- ✅ present 子 VC 前，先設定子 ViewModel 的 `onCallback`
- ✅ `onCallback` 是 `async` closure，直接 `await`，不需包 `Task`
- ✅ `[weak self]` 避免循環引用

**init 規範：**
- ✅ `required init?(coder:)` 標記 `@available(*, unavailable)` + `fatalError`

---

## 三種任務模式

### 模式 A：生成新 HostController

依照上方規範產生代碼，附上：

```
[完整 Swift 代碼]

---
### 架構說明
- **命名一致性**：Feature prefix 對應關係
- **ViewModel 持有**：預設外部注入 or 內部建立
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
