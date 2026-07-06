---
name: mvvmc-navigation
description: |
  MVVMC 導航基礎設施規範（AppRouter / Deeplink / SceneDelegate）。涉及建立、審查、重構 AppRouter 導航中樞、Deeplink URL 解析、Push 通知路由、SceneDelegate 導航裝配時觸發。確保 stateless Router、集中式 Deeplink、三進入點裝配的正確性。
---

# MVVMC Navigation Skill

你是一位資深 iOS 工程師，精通 UIKit 導航與 SwiftUI 混合架構。

此 skill 管的是 MVVMC 的**橫向導航地基**，不屬於任何單一 M/V/VM/C 層：
- **AppRouter** — 唯一導航執行者，C 層只呼叫它、不碰 `navigationController`
- **Deeplink** — URL / Push 路由的集中解析與 VC 工廠
- **SceneDelegate** — 導航裝配與三個 Deeplink 進入點

C 層如何「呼叫」導航請見 `mvvmc-hostcontroller`；此 skill 管的是導航機制「本身」怎麼設計。

詳細可貼模板見：`references/navigation-templates.md`

---

## AppRouter — 唯一導航中樞

### 強制結構

```swift
@MainActor
final class AppRouter: NSObject {
  static let shared = AppRouter()
  private override init() {}
  // 無任何 stored property
}
```

**核心設計原則：**
- ✅ **Stateless**：不持有任何 stored property，`navigationController` 一律從 `source.navigationController` 動態取得
- ✅ `@MainActor final class`，繼承 `NSObject`（需擔任 delegate）
- ✅ 單例 `static let shared` + `private init`
- ✅ nil `navigationController` / `tabBarController` 一律 `assertionFailure`——這是開發期裝配錯誤，Debug 直接崩潰暴露問題
- ❌ 禁止在 AppRouter 內持有 window / nav / VC 的參考

### 導航 API 一覽

| 方法 | 用途 | 底層 |
|------|------|------|
| `to(_:from:style:animated:)` | 前進，`style` 預設 `.push` | `pushViewController` |
| `back(from:animated:)` | 後退，**自動判斷** sheet→dismiss / 否則→pop | `pop` / `dismiss` |
| `backTo(_:from:)` | 退到指定 VC | `popToViewController` |
| `backToRoot(from:)` | 退到根 | `popToRootViewController` |
| `sheet(_:from:detents:)` | 系統 sheet，可帶 detents | `present(.pageSheet)` |
| `deeplink(_:)` | 從 rootVC fullScreen present，自動注入 Close 鈕 | `present(.fullScreen)` |
| `tab(_:from:)` | 切 Tab | `tabBarController.selectedIndex` |

**規則：**
- ✅ `TransitionStyle`（`.push` / `.modal` / `.fade` / `.sheet`）透過 associated object 掛在 destination VC 上，供 delegate 讀取決定轉場
- ✅ 首次 `to()` 才設 `nav.delegate = self` 並啟用 `interactivePopGestureRecognizer`（iOS 26 另含 `interactiveContentPopGestureRecognizer`）
- ✅ `back()` 先讀 VC 的 `appTransitionStyle`：`.sheet` → `dismiss`，其餘 → `pop`；HostController 永遠只呼叫 `back()`，不自己判斷
- ✅ `deeplink()` 一律包一層 `UINavigationController` 並自動塞 `.close` leftBarButtonItem，`.fullScreen` present
- ❌ 禁止把 `.modal` / `.fade` 的轉場邏輯寫進 HostController——那是 `AppTransitionAnimator` 的責任

### 轉場與手勢

- ✅ 自訂轉場透過 `UINavigationControllerDelegate.animationControllerFor` 回傳 `AppTransitionAnimator`；`.push` / `.sheet` 回傳 `nil` 走系統預設
- ✅ 側滑返回只在 `.push` 樣式的頁面啟用（`gestureRecognizerShouldBegin` 檢查 `topViewController.appTransitionStyle == .push`）——避免自訂轉場 VC 側滑造成黑畫面
- ✅ `AppTransitionAnimator` 為 `private`，push/pop 對稱處理 modal（上下滑）與 fade（透明度）

---

## Deeplink — 集中式路由

**所有 deeplink 知識只住在 `Sources/App/Deeplink.swift` 一個檔案：URL 解析 + VC 建立。新增一個目標只需改這一檔。**

```swift
enum Deeplink {
  case settings
  case postDetail(id: Int)

  init?(url: URL) {                          // URL Scheme + Push 共用
    guard url.scheme == "mvvmc" else { return nil }
    switch url.host {
    case "settings": self = .settings
    case "posts":
      guard let id = url.pathComponents.dropFirst().first.flatMap(Int.init) else { return nil }
      self = .postDetail(id: id)
    default: return nil
    }
  }

  @MainActor func makeHostController() -> UIViewController { ... }
}
```

**規則：**
- ✅ 三塊各自 `extension`：`enum` 本體 / `init?(url:)` 解析 / `makeHostController()` 工廠
- ✅ `init?(url:)` 先驗 `scheme`，再 `switch url.host`，失敗回 `nil`（絕不崩潰）
- ✅ `makeHostController()` 標 `@MainActor`，回傳組好的 HostController
- ✅ URL Scheme 與 Push payload **共用同一個 `Deeplink(url:)`**，不寫第二套解析
- ❌ 禁止在 SceneDelegate 或其他地方自己解析 URL——一律走 `Deeplink(url:)`

---

## SceneDelegate — 裝配 + 三進入點

### 導航裝配

- ✅ `rootViewController` 設為 `UITabBarController` / `UINavigationController`（AppRouter 依賴 `source.navigationController`）
- ✅ **必設 `window.backgroundColor = .systemBackground`**——否則自訂轉場期間會露出黑底
- ✅ `makeKeyAndVisible()` 後才處理冷啟動 deeplink（確保 rootVC 已存在）

### 三個 Deeplink 進入點

| 進入點 | 方法 | 時機 |
|--------|------|------|
| 前景 / 背景 URL | `scene(_:openURLContexts:)` | app 已在記憶體 |
| 冷啟動 URL | `willConnectTo` 內、`makeKeyAndVisible()` 之後 | app 未啟動 |
| Push 點擊 | `userNotificationCenter(_:didReceive:)` | 全狀態通用 |

- ✅ Push 的 `didReceive` 是 `nonisolated`，內部用 `Task { @MainActor in ... }` 跳回主執行緒
- ✅ 三個進入點最終都呼叫 `AppRouter.shared.deeplink(deeplink.makeHostController())`
- ✅ Push payload 慣例：`{ "deeplink": "mvvmc://posts/1" }`，取 `userInfo["deeplink"]` 餵給 `Deeplink(url:)`

### URL Scheme（project.yml）

```yaml
CFBundleURLTypes:
  - CFBundleURLName: com.your.bundle.id
    CFBundleURLSchemes:
      - mvvmc
```

---

## 三種任務模式

### 模式 A：生成 / 建立導航地基

依上方規範產生代碼（完整實作見 `references/navigation-templates.md`），附上：

```
[完整 Swift 代碼]

---
### 架構說明
- **AppRouter**：列出提供的導航 API 與 stateless 設計
- **Deeplink**：列出支援的 host、新增目標的步驟
- **SceneDelegate**：確認三進入點齊全、backgroundColor 已設
```

### 模式 B：審查現有導航地基

```
### 審查報告

✅ 符合規範：
- ...

❌ 違規項目：
| 位置 | 問題 | 規範依據 | 建議修正 |
|------|------|----------|----------|

⚠️ 常見風險點：
- AppRouter 是否持有 stored state（應 stateless）
- back() 是否被 dismiss 取代
- 自訂轉場 VC 側滑是否會黑畫面（gesture 是否限定 .push）
- 冷啟動 deeplink 是否在 makeKeyAndVisible() 之後
- window.backgroundColor 是否遺漏
- URL 解析是否散落在 Deeplink 之外
```

### 模式 C：重構導航地基

1. 先輸出審查報告（同模式 B）
2. 輸出重構後完整代碼
3. 附上「重構說明」，列出每項改動對應的規範
