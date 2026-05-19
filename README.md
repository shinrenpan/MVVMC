# MVVMC

> 一套為 SwiftUI + UIKit 混合架構設計的 iOS 架構模式。

MVVMC 是在 MVVM 的基礎上加入 **Coordinator（HostController）** 層，解決 SwiftUI 在 UIKit 導航環境下的責任分離問題。四層職責嚴格分離，任一層的改動不影響其他層。

---

## 四層架構

```
M  ─ ViewModel+Models.swift   State / Domain Models / DTOs
VM ─ ViewModel.swift          @Observable @MainActor，doAction 單一進入點
V  ─ View.swift               純 SwiftUI，零導航邏輯
C  ─ HostController.swift     UIKit 橋接，Router 導航唯一責任者
```

### 資料流

```
View ──doAction(.view)──▶ ViewModel ──doAction(.route)──▶ onAction? ──▶ HostController
                              │
                         doAction(.apiRequest)
                              │
                         doAction(.apiResponse)
                              │
                         state 更新 ──▶ View 自動刷新
```

### ViewModel 核心結構

```swift
@MainActor
@Observable
final class FeatureViewModel {
  enum Action: Sendable {
    case view(ViewAction)       // View 的使用者操作
    case route(Router)          // 導航意圖 → HostController
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  @ObservationIgnored
  var onAction: (@MainActor (Action) -> Void)?

  func doAction(_ action: Action) async { ... }
}
```

### HostController 核心結構

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {
  private let viewModel: FeatureViewModel
  private var tasks: [String: Task<Void, Never>] = [:]

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    tasks["onAppear"]?.cancel()
    tasks["onAppear"] = Task { await viewModel.doAction(.view(.onAppear)) }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    tasks.values.forEach { $0.cancel() }
    tasks.removeAll()
    viewModel.onAction = nil
  }
}
```

---

## 這個 Repo

| 目錄 | 用途 |
|---|---|
| `Sources/` | Demo 實作（可跑的 Xcode 專案） |
| `Templates/` | Xcode File Template |
| `.claude/skills/` | AI coding 規範（swift-model / swift-viewmodel / swiftui-expert / swift-hostcontroller / swift-concurrency） |

### Demo 專案

```bash
open MVVMCDemo.xcodeproj
```

目前包含：
- **PostList** — 完整四層，含 API 模擬、Router 導航
- **PostDetail** — 精簡四層，展示 Detail 接收外部資料的模式

### Xcode Template 安裝

```bash
cp -r Templates/MVVMC\ Feature.xctemplate \
  ~/Library/Developer/Xcode/Templates/File\ Templates/MVVMC/
```

安裝後重啟 Xcode，New File 對話框會出現 **MVVMC** 分類。輸入 Feature 名稱即可同時產生 M / VM / V / C 四個檔案。

---

## Tech Stack

- Swift 5.9+（目標 Swift 6 相容）
- SwiftUI + UIKit 混合
- iOS 17+
- `@Observable`（Swift Observation framework）
