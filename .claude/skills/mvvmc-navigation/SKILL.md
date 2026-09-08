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

> **預設立場**：MVVMC **強烈建議採 `UINavigationController`（push-based）codebase**，本 skill 的 `AppRouter`（含以 `appTransitionStyle` 驅動的 `back()` 與 `.modal`/`.fade` 自訂轉場）即以此為基準。少數導航結構確實不適用時（例如常駐 sheet 疊 fullScreen modal）可改用 present-based 例外變體，其 `back()` 通常改以「nav stack 還有沒有上一層」判斷 pop/dismiss、不需 `appTransitionStyle`——但這是**例外，非通則**。

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

### 你的 Router 必須覆蓋的格子（**檢查表，不是 API 表面積**）

> ⚠️ **這一節列的是「要能做到什麼」，不是「必須叫什麼名字」。** 下方 demo 的七個方法是**其中一種填法**，不是規範要求——它是 `Sources/App/AppRouter.swift` 的 API 表面積被鏡射進來的（見 commit `df7ebbb`），而那個 app 剛好有 tab bar、以 push 為主、sheet 為輔。**三個真實專案的 Router 表面積沒有一個跟它吻合**，那不是那三個專案的錯。
>
> 對齊方式：在專案的 CLAUDE.md 寫一張「哪個方法對應哪一格」的對照表即可，**不需要改任何程式碼**。審查時查的是覆蓋率，不是方法名。

導航是**四個獨立的決定**，`deeplink()` 的病就是把四個焊進一個名字裡（無 source ＋ fullScreen ＋ 包 nav ＋ 注入 Close）：

| 維度 | 有哪些值 | 誰決定 |
|---|---|---|
| **① 轉場方式** | push／present-fullScreen／present-pageSheet／切換根容器分頁 | 呼叫端 |
| **② 來源** | `.vc(x)` 從 x 出發／`.root` 只有 window／**`.topMost(from: x)` 沿 presentation chain 走到最上層** | 呼叫端 |
| **③ 目的地自帶 nav stack 嗎** | 要（內部有 master→detail）／不要（單一頁） | **目的地**，不是轉場方式 |
| **④ 誰提供離開的入口** | 系統手勢（pageSheet 下滑）／nav bar 返回鈕（push）／目的地自己的 toolbar | **目的地** |

**②的 `.topMost` 不是選配。** 畫面上一旦有常駐 sheet 佔住 presentation slot，從 host controller 直接 present 會「already presenting」——這是規範自己在〈預設立場〉承認的 present-based 例外變體，而它**必須有一格可以落**，否則走那條路的專案會從「規範明文承認的例外」退化成「連座標系都對不上」。

**③④ 歸目的地不歸 Router**，這是〈Close 鈕〉那條的根據：

- ❌ **Router 不得往目的地的 `navigationItem` 塞按鈕。** 理由不只是「Router 畫 UI 就不是 Router」——那顆注入的按鈕在 C 層與 V 層之外被建立，**沒有 `viewModel` 可以呼叫**，於是它結構上不可能遵守 `mvvmc-hostcontroller`「導覽列按鈕的點擊要走 `doAction`」那條硬規則。更實際的是它**不知道那一頁關閉時該做什麼**——送出中的表單（VM 有防重送 guard）、要發 `onCallback` 的頁、有草稿的頁，它一律直接關掉，VM 全程不知情
- ✅ **目的地在 V 層自己提供關閉入口**：`.toolbar` → `send(.closeDidTap)` → `doAction` → `onRoute?(.dismiss)` → C 層 `back(from:)`。**這是規範對其他每一顆按鈕已經要求的路徑，不需要新規則**

**⚠️ 冷啟動的 deeplink 需要建一組 VC，不是一個。** 通知點進去的正確行為多數不是 present 而是**導航**（切到對應分頁、把該頁推上那個 stack），這樣系統返回鈕自然存在、使用者「往回按看得到列表」的心智模型才成立。但冷啟動時那個 stack 是空的——**只 present 一個詳情頁會得到一個孤兒頁面，而那個問題的根因是「工廠方法回傳單一 VC」，不是 fullScreen。** 需要 `setViewControllers([列表, 詳情])` 的路徑，`Deeplink.makeHostController()` 的回傳型別要能表達「一組 VC ＋ 一個呈現意圖」。fullScreen present 保留給真正該是 modal 的 deeplink（獨立 onboarding、強制更新頁）。

---

### demo 的填法（`Sources/App/AppRouter.swift`，**參考不是規範**）

| 方法 | 用途 | 底層 |
|------|------|------|
| `to(_:from:style:animated:)` | 前進，`style` 預設 `.push` | `pushViewController` |
| `back(from:animated:)` | 後退，**自動判斷** sheet→dismiss / 否則→pop | `pop` / `dismiss` |
| `backTo(_:)` | 退到指定 VC（**無 `from:`**——見下） | `popToViewController` |
| `backToRoot(from:)` | 退到根 | `popToRootViewController` |
| `sheet(_:from:detents:)` | 系統 sheet，可帶 detents | `present(.pageSheet)` |
| `deeplink(_:)` | 收 `Deeplink.Destination`：`.navigate(tab:stack:)` 切分頁並推上脈絡／`.present(_:)` 真 modal。**不注入 Close 鈕** | `selectedIndex` + `setViewControllers` ／ `present(.fullScreen)` |
| `tab(_:from:)` | 切 Tab | `tabBarController.selectedIndex` |

**規則：**
- ✅ `TransitionStyle`（`.push` / `.modal` / `.fade` / `.sheet`）透過 associated object 掛在 destination VC 上，供 delegate 讀取決定轉場
- ⚠️ **`.sheet` 是「關閉方式」不是「視覺樣式」**：它代表「以 present 呈現、`back()` 必須走 dismiss」。所以 `deeplink()` 的 fullScreen present 也標成 `.sheet`——名字看起來矛盾，但改掉它就會讓 `back()` 誤走 pop。要動這個 enum 前，先確認 `back()` 的分支邏輯
- ✅ 首次 `to()` 才設 `nav.delegate = self` 並啟用 `interactivePopGestureRecognizer`（iOS 26 另含 `interactiveContentPopGestureRecognizer`）
- ✅ `back()` 先讀 VC 的 `appTransitionStyle`：`.sheet` → `dismiss`，其餘 → `pop`；HostController 永遠只呼叫 `back()`，不自己判斷
- ℹ️ **只有承重的地方才有 `from:`**：`back(from:)` 的 source 真的在做事（讀 `appTransitionStyle` 決定 pop 還是 dismiss）；`backToRoot(from:)` 沒有 destination 可推導 stack，`from:` 是唯一來源；**`backTo` 的 source 只用來取 nav，而 destination 本來就在那個 stack 裡——那是死參數，已刪除**。三個方法形狀不一致是設計，不是疏漏
- ℹ️ **`back(from:)` 的 `from:` 是「從誰的導航環境退」，不是「誰要被關掉」**。所以父 HostController 在子 VM 的 `onCallback` 裡寫 `AppRouter.shared.back(from: self)` 是正確的——退的是那個 nav stack 的 top VC（也就是子頁），不是 `self`。子頁自己呼叫 `back(from: self)` 同樣成立，兩種寫法等價
- ✅ `deeplink()` 的 `.present` 分支包一層 `UINavigationController`、`.fullScreen` present；**`.navigate` 分支保留該分頁既有的根**（那就是「往回按看得到的列表」），只把目的地推上去
- ❌ **`deeplink()` 不得注入 Close 鈕**——那顆按鈕在 C 層與 V 層之外被建立、沒有 `viewModel` 可呼叫，結構上不可能遵守「導覽列按鈕要走 `doAction`」，而且它不知道那一頁關閉時該做什麼。關閉入口由目的地在 V 層自己提供
  > **demo 的教訓**：`PostDetailHostController` 同時被 push（從列表）與 deeplink 使用。要它自己長一顆 Close 鈕，就得知道自己是怎麼被呈現的——那是耦合外洩。**把 deeplink 從「present 一個」改成「切分頁 + 推上脈絡」之後，系統返回鈕自然存在，這個問題整個消失。** 這一半不是選配，它是讓「不注入 Close 鈕」變得實作得出來的前提
- ❌ 禁止把 `.modal` / `.fade` 的轉場邏輯寫進 HostController——那是 `AppTransitionAnimator` 的責任

### 轉場與手勢

- ✅ 自訂轉場透過 `UINavigationControllerDelegate.animationControllerFor` 回傳 `AppTransitionAnimator`；`.push` / `.sheet` 回傳 `nil` 走系統預設
- ✅ 側滑返回只在 `.push` 樣式的頁面啟用（`gestureRecognizerShouldBegin` 檢查 `topViewController.appTransitionStyle == .push`）——避免自訂轉場 VC 側滑造成黑畫面
- ⚠️ **已知限制：無法「只關掉某一頁的側滑」**。手勢政策與視覺轉場綁在同一個 `TransitionStyle` enum 上，所以想擋掉側滑（例如表單填到一半不該被隨手滑掉）就只能把該頁改成 `.modal` / `.fade`，連帶改變轉場動畫。`.navigationBarBackButtonHidden(true)` 只擋得住返回鈕、擋不住側滑。真的需要時，得在 `TransitionStyle` 之外另加一個手勢旗標——目前規範沒有這條，屬未解決的設計限制
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

| 模式 | 做什麼 |
|---|---|
| **A：生成** | 依上方規範產生代碼。使用者未要求就只給代碼；要說明時講這幾件事：**AppRouter** 提供的導航 API、**Deeplink** 支援的 host 與新增步驟、**SceneDelegate** 三進入點是否齊全 |
| **B：審查** | 輸出報告：✅ 符合規範 / ❌ 違規（表格：位置、問題、規範依據、建議修正）/ ⚠️ 灰色地帶（說明判斷理由） |
| **C：重構** | 先出審查報告（同 B）→ 重構後完整代碼 → 「重構說明」列出每項改動對應的規範條目 |


審查時的常見風險點：AppRouter 是否持有 stored state、`back()` 是否被 `dismiss` 取代、自訂轉場 VC 側滑是否會黑畫面、冷啟動 deeplink 是否在 `makeKeyAndVisible()` 之後、`window.backgroundColor` 是否遺漏、URL 解析是否散落在 `Deeplink` 之外。
