# Host 生命週期與任務管理

完整實作請見：`DracoApp/Sources/Shared/HostTaskLifecycleManaged.swift`

本文件定義 HostController 的異步任務生命週期管理基礎設施，涵蓋 `AnyHostingController`、`HostTaskLifecycleManaged`、`TaskLifecycleManager` 三個核心元件，以及 `UIViewController.isRemoving` 的移除判定邏輯。

---

## 何時該用

使用此基礎設施的時機：

- ✅ HostController 內部會啟動 `Task { ... }` 執行異步工作（API 呼叫、long-polling、資料串流等）
- ✅ 需要在畫面「真正被移除」時統一取消所有 in-flight task，避免 race condition 或記憶體洩漏
- ✅ 需要以 **tag** 管理多個並行任務，後發任務會自動取消同 tag 的前一個任務（例如輸入搜尋的 debounce-style 取消）
- ✅ 需要確保 ViewModel 的 `onAction` / `onCallback` closure 在畫面移除時被清空，切斷 retain cycle

**不需要使用的情境**：

- ❌ HostController 完全不啟動任何 Task

---

## 核心元件總覽

| 元件 | 類型 | 職責 |
|------|------|------|
| `AnyHostingController` | protocol | 標記型別為 `UIHostingController`，作為 extension 的約束條件 |
| `HostTaskLifecycleManaged` | protocol | 宣告 Host 擁有 `taskManager`，並提供 `manageTask(tag:task:)` / `cancelTasksAndCleanup()` 預設實作 |
| `TaskLifecycleManager<VM>` | final class | 以 `[String: Task]` map 管理任務、持有 ViewModel 弱參考、負責清空 closure |
| `UIViewController.isRemoving` | computed property | 遞迴判定自身或容器是否真正被移除，避免誤殺 RootViewController |

---

## 如何整合進 HostController

### 步驟 1：讓 HostController 採用 `HostTaskLifecycleManaged`

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView>, HostTaskLifecycleManaged {

  lazy var taskManager: TaskLifecycleManager = .init(viewModel: viewModel)
  let viewModel: FeatureViewModel

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

### 步驟 2：在 `viewDidDisappear` 觸發清理

```swift
// MARK: - Lifecycle
extension FeatureHostController {

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelTasksAndCleanup()   // 內部會檢查 isRemoving
    }
}
```

### 步驟 3：以 `manageTask(tag:task:)` 啟動受管任務

```swift
// MARK: - Lifecycle
extension FeatureHostController {

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    manageTask(tag: "onAppear", task: Task {
      await viewModel.doAction(.view(.onAppear))
    })
  }
}
```

---

## 核心規則

### `HostTaskLifecycleManaged` 協議

- ✅ `taskManager` 宣告為 `lazy var`，表達「依賴 `self.viewModel`」的語意
- ❌ 不要把 `taskManager` 宣告成 optional

### Tag 命名慣例

`manageTask(tag:task:)` 的 tag 字串**直接以 string literal 內聯撰寫**，不提取為常數：

```swift
// ✅ 正確：tag 緊貼在使用處，一眼看出用途
manageTask(tag: "onAppear", task: Task { ... })
manageTask(tag: "badge_observation", task: Task { ... })

// ❌ 不這樣做：常數定義在別處，讀者需要 scroll 至常數位置確認
private enum TaskTag {
    static let onAppear = "onAppear"
}
manageTask(tag: TaskTag.onAppear, task: Task { ... })
```

> **理由**：tag 是實作細節，讀者在看到 `manageTask` 的呼叫時即可理解其語意，無需跳轉至常數定義。提取常數只會打斷編碼流程。

### `TaskLifecycleManager`

- ✅ ViewModel 採用 `weak var`，由 HostController 持有 strong reference
- ✅ `manage(tag:_:)` 覆寫同 tag 前先 cancel，保證同名任務只會存在一個
- ✅ `cancelTasksAndCleanup()` 除了取消任務，也會把 `viewModel.onAction` / `viewModel.onCallback` 設為 nil

### `UIViewController.isRemoving`

- ✅ 判定順序：自身 → 容器（Nav / TabBar） → 遞迴問 parent（三層）
- ❌ 絕對不要用 `parent == nil && navigationController == nil` 判定移除，會誤殺 RootViewController
- ✅ 只在 `viewDidDisappear` 階段呼叫，其他時機不可信賴

---

## 常見錯誤

| 錯誤寫法 | 問題 | 正確做法 |
|----------|------|----------|
| 在 HostController 直接寫 `Task { ... }` 沒受管 | 畫面移除後 task 還在跑 | 一律走 `manageTask(tag:task:)` |
| `taskManager` 宣告為 optional | 存取時需要解包，語意不清 | 改為 `lazy var` |
| `TaskLifecycleManager` 以 strong reference 持有 ViewModel | Host 釋放後 ViewModel 仍被 manager 綁住 | `weak var viewModel` |
| 在 `viewWillDisappear` 呼叫 cleanup | 使用者只是暫離（push 下一頁），回來後 task 全沒了 | 改在 `viewDidDisappear` + `isRemoving` 守衛 |
| 忘記在 `cancelTasksAndCleanup()` 清 `onAction` / `onCallback` | ViewModel 持有 Host 的 closure 形成 retain cycle | manager 內主動設 nil |
| `isRemoving` 只檢查 `isMovingFromParent` | dismiss modal、TabBar 被換掉時判定錯誤 | 走完整三層檢查（自身 → 容器 → 遞迴 parent） |

---

## 與既有規範的銜接

- ViewModel 結構（`onAction` / `onCallback` / `doAction`）請見主 `SKILL.md` 與 `swift-viewmodel` skill
- HostController 基礎模板（Init / viewDidLoad / listenSelfAction / handleSelfRouter）請見主 `SKILL.md`
- 本文件僅聚焦「任務生命週期」這一條軸線，不覆寫其他章節的規範
