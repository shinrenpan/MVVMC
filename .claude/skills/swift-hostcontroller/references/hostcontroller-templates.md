# HostController Templates

詳細模板與進階情境參考。

---

## Template 1：最簡版

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {

  // MARK: - ViewModel
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

---

## Template 2：帶 Dependency

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {

  // MARK: - ViewModel
  let viewModel: FeatureViewModel

  // MARK: - Init
  init(product: Product) {
    let viewModel = FeatureViewModel(product: product)
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

---

## Template 3: 有 Router

```swift
// MARK: - Lifecycle
extension FeatureHostController {
  override func viewDidLoad() {
    super.viewDidLoad()
    listenSelfAction()
  }
}

// MARK: - Router
private extension FeatureHostController {
  func listenSelfAction() {
    viewModel.onAction = { [weak self] action in
      switch action {
      case .apiRequest, .apiResponse, .view:
        break

      case let .router(router):
        self?.handleSelfRouter(router)
      }
    }
  }

  func handleSelfRouter(_ router: FeatureViewModel.Router) {
    switch router {
    case .toDetail:
      ...
    }
  }
}
```

---

## Template 4: 有 Callback

```swift
// MARK: - Lifecycle
extension FeatureHostController {
  override func viewDidLoad() {
    super.viewDidLoad()
    listenSelfAction()
  }
}

// MARK: - Router
private extension FeatureHostController {
  func listenSelfAction() {
    viewModel.onAction = { [weak self] action in
      switch action {
      case .apiRequest, .apiResponse, .view:
        break

      case let .router(router):
        self?.handleSelfRouter(router)
      }
    }
  }

  func handleSelfRouter(_ router: FeatureViewModel.Router) {
    switch router {
    case .toDetail:
      let detail = DetailHostController(viewModel: .init())
      listenDetailCallback(detail.viewModel)
      navigationController?.pushViewController(detail, animated: true)
    }
  }
}

// MARK: - Detail Callback
private extension FeatureHostController {
  func listenDetailCallback(_ viewModel: DetailViewModel) {
    viewModel.onCallback = { [weak self] action in
      switch action {
      case let .callback(callback):
        self?.handleDetailCallback(callback)
      }
    }
  }

  func handleDetailCallback(_ callback: DetailViewModel.Callback) {
    switch callback {
      ...
    }
  }
}
```

---

## Template 5: 有 Task
`HostTaskLifecycleManaged` 參考 `references/host-lifecycle-management.md`

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView>, HostTaskLifecycleManaged {

  // MARK: - ViewModel
  let viewModel: FeatureViewModel

  // MARK: - Task
  let taskManager: TaskLifecycleManager<FeatureViewModel>

  // MARK: - Init
  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    self.taskManager = TaskLifecycleManager(viewModel: viewModel)
    let view = FeatureView(viewModel: viewModel)
    super.init(rootView: view)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Lifecycle
extension FeatureHostController {

  // viewWillAppear：適用於每次出現都需要刷新的場景
  // viewDidLoad 內的 manageTask：適用於只執行一次的初始化場景
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    manageTask(tag: "onAppear", task: Task {
      await viewModel.doAction(.view(.onAppear))
    })
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    cancelTasksAndCleanup()
  }
}
```

---

## Template 6: 組合場景（Router + Callback + Task）

真實 HostController 常同時具備三種模式，以下示範正確的組合結構。

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView>, HostTaskLifecycleManaged {

  // MARK: - ViewModel
  let viewModel: FeatureViewModel

  // MARK: - Task
  let taskManager: TaskLifecycleManager<FeatureViewModel>

  // MARK: - Init
  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    self.taskManager = TaskLifecycleManager(viewModel: viewModel)
    let view = FeatureView(viewModel: viewModel)
    super.init(rootView: view)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Lifecycle
extension FeatureHostController {

  override func viewDidLoad() {
    super.viewDidLoad()
    listenSelfAction()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    manageTask(tag: "onAppear", task: Task {
      await viewModel.doAction(.view(.onAppear))
    })
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    cancelTasksAndCleanup()   // 同時取消 task + 清空 onAction / onCallback
  }
}

// MARK: - Router
private extension FeatureHostController {

  func listenSelfAction() {
    viewModel.onAction = { [weak self] action in
      switch action {
      case .apiRequest, .apiResponse, .view:
        break

      case let .router(router):
        self?.handleSelfRouter(router)
      }
    }
  }

  func handleSelfRouter(_ router: FeatureViewModel.Router) {
    switch router {
    case .toDetail:
      let detail = DetailHostController(viewModel: .init())
      listenDetailCallback(detail.viewModel)
      navigationController?.pushViewController(detail, animated: true)

    case .toOther:
      navigateToOther()
    }
  }

  func navigateToOther() {
    ...
  }
}

// MARK: - Detail Callback
private extension FeatureHostController {

  func listenDetailCallback(_ viewModel: DetailViewModel) {
    viewModel.onCallback = { [weak self] action in
      switch action {
      case let .callback(callback):
        self?.handleDetailCallback(callback)
      }
    }
  }

  func handleDetailCallback(_ callback: DetailViewModel.Callback) {
    switch callback {
    case .didFinish:
      ...
    }
  }
}
```

> **組合重點**：
> - `cancelTasksAndCleanup()` 在 `viewDidDisappear` 會一併清空 `onAction` / `onCallback`，不需手動設 nil。
> - `listenSelfAction()` 永遠在 `viewDidLoad`，與是否有 Task 無關。
> - 每個 child Callback 各自一個 `private extension`，Router 本身也是獨立的 `private extension`。

---

## 常見錯誤對照表

| ❌ 錯誤寫法 | ✅ 正確寫法 | 原因 |
|------------|------------|------|
| 缺少 `@MainActor` | `@MainActor final class ...` | SwiftUI + UIKit 橋接必須在主執行緒 |
| 沒有監聽 `onAction` | `viewDidLoad` 內呼叫 `listenSelfAction()` | Router 需要 HostController 接管 |
| closure 未用 `[weak self]` | `{ [weak self] action in` | 避免 HostController 與 ViewModel 循環引用 |
| ViewModel 直接做 `push` | 透過 `onAction?(.router(...))` 轉發 | ViewModel 不應持有 UIKit 依賴 |
| 導航邏輯散落在 `listenSelfAction` | 集中在獨立的 `handleSelfRouter(_:)` | 單一職責，易於維護 |
| `required init?(coder:)` 未標 unavailable | 加上 `@available(*, unavailable)` | 防止 Storyboard 誤用 |
| 有 Task 時未實作 `cancelTasksAndCleanup` | `viewDidDisappear` 實作 | HostController retain cycle |
| `taskManager` 宣告為 `lazy var` | `let taskManager`，在 `init` 建立 | `@MainActor lazy var` 有 Swift Concurrency 隔離警告，且初始化時機不可控 |
| Callback listener 寫在同一個 extension | 每個 child 各自一個 `private extension` | 多個 callback 時易混淆，單一職責 |
| child 建立後先 push 再 listen callback | listen 必須在 push / present 之前 | push 後 child 可能立即觸發 callback，此時 listener 尚未設定，回調遺失 |
| 有 Router 時，因為加了 Task 就省略 `listenSelfAction` | 有 Router 時，無論是否有 Task，`viewDidLoad` 都要呼叫 `listenSelfAction` | Task 與 Router 監聽是獨立的，互不影響 |

---
