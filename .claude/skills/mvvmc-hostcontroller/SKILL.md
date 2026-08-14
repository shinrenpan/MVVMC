---
name: mvvmc-hostcontroller
description: |
  MVVMC C 層架構規範。涉及建立、審查、重構 HostController，或任何 SwiftUI View 嵌入 UIKit 的橋接層、Router 導航時觸發。確保遵守 @MainActor + UIHostingController + 純 Router 規範。
---

# MVVMC HostController Skill

你是一位資深 iOS 工程師，精通 SwiftUI 與 UIKit 混合架構。

ViewModel 結構（含 Router）請參考 `mvvmc-viewmodel` skill 的規範。
詳細模板請見：`references/hostcontroller-templates.md`

---

## 強制基礎結構

### 標準：外部傳入 ViewModel

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

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }
}

// 導航邏輯一律集中在這裡，不 inline 在 closure 裡
private extension FeatureHostController {
  func handleRouter(_ router: FeatureViewModel.Router) {
    switch router {
    case let .toDetail(item):
      AppRouter.shared.to(DetailHostController(id: item.id), from: self)
    }
  }
}
```

### 變體：傳入原始參數，內部建立 ViewModel

適用於「跨 feature 橋接」情境，呼叫端（父 HostController）傳入 primitive，C 層負責組裝 ViewModel：

```swift
@MainActor
final class PostDetailHostController: UIHostingController<PostDetailView> {

  private let viewModel: PostDetailViewModel

  init(id: Int, title: String, body: String) {
    let post = PostDetailViewModel.Post(id: id, title: title, body: body)
    self.viewModel = PostDetailViewModel(post: post)
    super.init(rootView: PostDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
```

優點：父 HostController 不需要知道子 ViewModel 的 Domain Model 型別，跨 feature 邊界以 primitive 傳遞，避免型別耦合。

> 這是 MVVMC「Domain Model 不跨 feature」的執行點——**為什麼**不共用、參數多到難看時該怎麼辦，見 `mvvmc-structure`。

**兩種 init 形狀怎麼選**（同一個專案裡並存是正常的）：

| 這一頁需要回傳結果給父層嗎 | 用哪種 | 為什麼沒得選 |
|---|---|---|
| 不需要 | **變體**：父層傳 primitive，子 C 層自己組 VM | 父層完全不需要認識子 ViewModel 的型別 |
| 需要（要接 `onCallback`） | **標準**：父層先建子 VM、掛好 `onCallback`，再 `init(viewModel:)` | 要掛 callback 就必須先拿到那個 VM 實例，沒有別的辦法 |

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
- ✅ 所有導航透過 `AppRouter.shared`（`to / sheet / back / backTo / backToRoot / tab`）
- ℹ️ `AppRouter.shared.deeplink(_:)` 也是導航 API，但它從 rootVC present、不需要 `from:`，呼叫端是 SceneDelegate 而非 HostController（見 `mvvmc-navigation`）
- ❌ 禁止直接呼叫 `navigationController?.pushViewController` / `present` / `dismiss`
- ❌ 禁止 ViewModel 直接持有 UIViewController 或做導航
- ❌ 不需要 `viewDidDisappear` 清空 closure（ViewModel 由 HostController 持有，`[weak self]` 已足夠）

**onCallback 規範（跨 VC 回傳）：**
- ✅ 導航子 VC 前，先設定子 ViewModel 的 `onCallback`
- ✅ `onCallback` 是 `async` closure，直接 `await`，不需包 `Task`
- ✅ `[weak self]` + `guard let self` 避免循環引用與 optional chaining
- ✅ 回傳後透過 `AppRouter.shared.back(from: self)` 返回，不用 `dismiss`

**init 規範：**
- ✅ `required init?(coder:)` 標記 `@available(*, unavailable)` + `fatalError`

**導覽列（title / toolbar）歸誰：**
- ✅ 優先用 SwiftUI 的 `.navigationTitle` / `.toolbar`，寫在 V 層
  > why：導覽列按鈕的點擊要走 `doAction`，而 C 層**禁止啟動 Task 觸發 ViewModel**——按鈕放 `navigationItem.rightBarButtonItem` 就必然違規
- ✅ 只有 SwiftUI 設不到的（`navigationItem` 的特殊配置、`largeTitleDisplayMode` 的細節行為）才留在 C 層，且僅限「設定外觀」不含互動

---

## 三種任務模式

| 模式 | 做什麼 |
|---|---|
| **A：生成** | 依上方規範產生代碼。使用者未要求就只給代碼；要說明時講這幾件事：**命名一致性**（Feature prefix 對應）、**ViewModel 持有**（外部注入 or C 層組裝）、**AppRouter 使用**（每個 to / back 對應的導航情境） |
| **B：審查** | 輸出報告：✅ 符合規範 / ❌ 違規（表格：位置、問題、規範依據、建議修正）/ ⚠️ 灰色地帶（說明判斷理由） |
| **C：重構** | 先出審查報告（同 B）→ 重構後完整代碼 → 「重構說明」列出每項改動對應的規範條目 |
