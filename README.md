# MVVMC

> 一套為 SwiftUI + UIKit 混合架構設計的 iOS 導航架構模式。

MVVMC 在 MVVM 基礎上加入 **HostController（C 層）**，解決 SwiftUI 在 UIKit 導航環境下的責任分離問題。四層職責嚴格分離，任一層的改動不影響其他層。

---

## 四層架構

| 層 | 檔案命名 | 職責 |
|---|---|---|
| M | `FeatureViewModel+Models.swift` | State / Domain Models / DTOs |
| VM | `FeatureViewModel.swift` | `@Observable @MainActor`，`doAction` 單一進入點 |
| V | `FeatureView.swift` | 純 SwiftUI，零導航邏輯、零業務邏輯 |
| C | `FeatureHostController.swift` | UIKit 橋接，Router 導航唯一責任者 |

### 資料流

```
使用者操作
  → View: Task { await viewModel.doAction(.view(.xxx)) }
  → VM: handleViewAction → doAction(.apiRequest(...))
  → VM: handleAPIRequest → API → doAction(.apiResponse(...))
  → VM: handleAPIResponse → 更新 state → View 自動刷新

導航:
  → VM: onRoute?(.toXxx)
  → HostController → AppRouter.shared.to(vc, from: self)

跨 VC 回傳:
  → 子 VM: await onCallback?(.result)
  → 父 HostController → AppRouter.shared.back(from: self) → 處理結果
```

---

## AppRouter

`AppRouter.shared` 是 App 唯一導航入口，HostController 不直接呼叫 `navigationController` / `present` / `dismiss`。

```swift
// Push（原生右滑返回）
AppRouter.shared.to(DetailHostController(...), from: self)
AppRouter.shared.to(FilterHostController(...), from: self, style: .modal)
AppRouter.shared.to(SomeHostController(...), from: self, style: .fade)

// Sheet
AppRouter.shared.sheet(SettingsHostController(...), from: self)
AppRouter.shared.sheet(SomeHostController(...), from: self, detents: [.medium()])

// 後退（自動判斷 pop / dismiss）
AppRouter.shared.back(from: self)
AppRouter.shared.backTo(targetVC, from: self)
AppRouter.shared.backToRoot(from: self)

// Tab
AppRouter.shared.tab(1, from: self)

// Deeplink（fullScreen，自動注入 Close button）
AppRouter.shared.deeplink(SomeHostController(...))
```

---

## Deeplink / Push Notification

```swift
// Sources/App/Deeplink.swift — URL 解析 + VC 建立集中在一個地方
enum Deeplink {
  case settings
  case postDetail(id: Int)

  init?(url: URL) { ... }

  @MainActor func makeHostController() -> UIViewController { ... }
}

// SceneDelegate — 三個入口統一走 AppRouter.deeplink()
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
  guard let url = URLContexts.first?.url,
        let deeplink = Deeplink(url: url) else { return }
  AppRouter.shared.deeplink(deeplink.makeHostController())
}
```

推播 payload 約定：`{ "deeplink": "myapp://posts/1" }`，`Deeplink(url:)` 直接複用。

---

## MCP Server

本 repo 附帶 MCP server，讓 Claude Code 在任何專案都能取得 MVVMC 規範。

### 安裝

```bash
git clone https://github.com/shinrenpan/MVVMC
cd MVVMC/mcp-server
npm install && npm run build
claude mcp add mvvmc -s user node "$PWD/dist/index.js"
```

### 提供的 Tools

| Tool | 說明 |
|---|---|
| `get_architecture_overview` | 整體架構與資料流 |
| `get_layer_guide` | 指定層（M / VM / V / C）規範與範例 |
| `get_approuter_guide` | AppRouter 完整 API |
| `get_deeplink_guide` | Deeplink + Push Notification 模式 |

---

## 這個 Repo

| 目錄 | 用途 |
|---|---|
| `Sources/` | Demo 實作（可跑的 Xcode 專案） |
| `mcp-server/` | MCP server 原始碼 |
| `.claude/skills/` | Claude Code skill 規範 |

### Demo 專案

```bash
open MVVMCDemo.xcodeproj
```

包含：

- **PostList** — 完整四層，API 模擬、Router 導航、Filter（modal）、UserDetail（fade）
- **PostDetail** — 跨 feature 傳 primitive，C 層組裝 ViewModel
- **PostFilter** — `onCallback` 跨 VC 回傳範例
- **UserDetail** — fade 轉場
- **Profile** — Tab 導航（`AppRouter.tab()`）
- **Settings** — Sheet 範例（`AppRouter.sheet()`）
- **Deeplink Demo** — URL Scheme + Push Notification 觸發

---

## Tech Stack

- iOS 17+
- Swift 5.9+（Swift 6 concurrency 相容）
- SwiftUI + UIKit 混合
- `@Observable`（Swift Observation framework）
- XcodeGen（`xcodegen generate` 更新 project file）
