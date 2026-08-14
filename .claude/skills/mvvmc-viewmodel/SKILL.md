---
name: mvvmc-viewmodel
description: |
  MVVMC VM 層架構規範。涉及建立、審查、重構 @Observable ViewModel，或處理 doAction / Action enum（ViewAction、APIRequest、APIResponse）、onRoute、onCallback、API 請求與錯誤如何寫進 state 時觸發。確保遵守 @Observable + @MainActor + final class 三合一規範，以及 doAction 單一進入點。
---

# MVVMC ViewModel Skill

你是一位資深 iOS 工程師，專精於 Swift Observation framework 與 clean architecture。

State 結構請參考 `mvvmc-model` skill 的規範。

- 可貼的模板與範例：`references/viewmodel-templates.md`
- **場景模式**（run once / 錯誤流動 / 併發 / 深層回傳 / 輪詢 / 分頁 / 表單）：`references/patterns.md`

---

## 強制基礎結構

```swift
@Observable
@MainActor
final class FeatureViewModel {
    var state: State = .init()

    func doAction(_ action: Action) async {
        switch action {
        ...
        }
    }
}
```

---

## 核心規則

**強制宣告：**
- ✅ `@Observable` / `@MainActor` / `final class`
- ❌ 禁止繼承任何 ViewModel protocol
- ❌ 禁止 `ObservableObject` / `@Published`

**doAction 規範：**
- ✅ 唯一進入點，內部只做 `switch` dispatch
- ❌ 禁止可從 View 直接呼叫的業務邏輯 func（應透過 doAction）
- 💡 Action 種類多時，建議每層各自一個 `private extension`；單層或簡單的 ViewModel 可以合併
- 💡 handle 內以語意判斷是否拆出獨立 private func；邏輯簡單且無命名價值時直接寫在 case 內即可

**Action 命名（不強制全部實作，依需求取捨）：**

| Action 種類 | 命名 | 說明 |
|---|---|---|
| UI 事件 | `ViewAction` | 描述「UI 發生了什麼」（what happened） |
| API 請求 | `APIRequest` | 發起網路請求 |
| API 回應 | `APIResponse` | 處理網路回應，更新 state |

所有 Action enum 需為 `Sendable`，依情境放在合適的 `extension` 下。

> **子頁 callback 回傳的結果也歸 `ViewAction`**（例如 `didFilterUser(id:)`）。它嚴格說不是「使用者在本頁做了什麼」，但它是**這個畫面收到的輸入**，仍屬 View 層的入口。不需要為它多開第四種 Action 類別——多一種分類換不到任何清晰度。

**onRoute / onCallback：**

- `onRoute` — HostController 設定，接收導航意圖後執行導航
  - 型別：`(@MainActor (Router) -> Void)?`，同步
  - ViewModel 呼叫：`onRoute?(.toDetail(post))`（不經過 doAction dispatch）
  - why 不走 doAction：導航不改 state、也不需要 async，效果歸 C 層執行；`doAction` 專責狀態轉移，`onRoute`/`onCallback` 是交給 C 處理副作用的逃生口
- `onCallback` — 父 HostController 設定，接收跨 VC 回傳值
  - 型別：`(@MainActor (Callback) async -> Void)?`，async（避免呼叫端需要包 Task）
  - ViewModel 呼叫：`await onCallback?(.didSelectUser(id: user.id))`（在 doAction 內 await）
  - **payload 傳 primitive，不傳 Domain Model**——與 HostController 的 init 同一個理由：耦合是雙向的（見 `mvvmc-structure`）
- ℹ️ **`Router` 與 `Callback` 的 payload 規則不同**：`Router` 是 feature **內部**的 VM → C 通道，可以帶 Domain Model（`toDetail(post)`）；`Callback` 會**跨出 feature 邊界**到父層，所以必須 primitive。跨 feature 的 primitive 化在 C 層的 `handleRouter` 完成（`OrderDetailHostController(id: order.id)`）
- ✅ 兩者只在有實際需求時才宣告
- ✅ **`Router` / `Callback` enum 預設加 `Equatable`**——`mvvmc-testing` 用 `#expect(received == .toDetail(post))` 驗證導航意圖與跨 VC 回傳，沒有 `Equatable` 就寫不出這類測試。純值 enum 隱含 `Equatable`，帶 associated value 時要顯式加（裡面的 Domain Model 本來就該是 `Equatable`）
- ✅ 必須標注 `@ObservationIgnored`
- ✅ 非 UI 相關的 property 一律標注 `@ObservationIgnored`

**什麼算「導航」——`onRoute` 的邊界：**

| 副作用 | 誰做 | 判準 |
|---|---|---|
| push / pop / sheet / tab 切換 / dismiss<br>**以及任何需要 present 一個 VC 的東西**（`UIActivityViewController` 分享面板、系統相機、`SFSafariViewController`…） | `onRoute?(...)` → C 層 | **會改變 App 內的畫面堆疊** |
| 開啟外部 URL（`UIApplication.shared.open`）、Haptic、寫剪貼簿、寫 UserDefaults | ViewModel 直接執行 | 不改變畫面堆疊，做完就結束 |

VM 直接做第二類是刻意的——為它們繞一圈 `onRoute` 只是把單行呼叫拆成三個地方（Router case、handleRouter 分支、C 層實作），換不到任何解耦。判準是「畫面堆疊」而不是「有沒有碰到 UIKit」。

> ⚠️ **「分享」是最容易判錯的一個**，因為它聽起來不像導航：
> - SwiftUI 的 `ShareLink` —— V 層自己處理，VM 完全不介入
> - `UIActivityViewController` —— **必須 present**，所以走 `onRoute?(.toShare(url))` → C 層 `AppRouter.shared.sheet(...)`
>
> 判斷時問的是「**這件事會不會 present 東西上來**」，不是「這件事聽起來像不像導航」。凡是需要一個 presenting VC 才做得到的，一律歸 C——否則 VM 就得持有 `UIViewController`，那是 `mvvmc-hostcontroller` 的硬性禁令。
>
> **但 SwiftUI 原生的 `.alert` / `.confirmationDialog` 不算**：它們不需要你拿到 presenting VC，V 層自己就做得到。硬套「會 present 就走 C 層」會逼出 `UIAlertController`，讓 C 層寫互動邏輯又得起 Task 呼叫 `doAction`——那兩件事都是 hostcontroller 明文禁止的。判準的精神是「**你得自己弄到一個 VC 才做得到嗎**」，見 `mvvmc-view`〈Alert 與確認對話框〉。

> `@Observable` 追蹤所有 stored property；closure 或非 UI 狀態若未標注 `@ObservationIgnored`，會觸發不必要的 View re-render。

---

## 場景模式（詳見 `references/patterns.md`）

以下情境的職責分配已有規範，遇到時**先查該節**再動手——它們多半是「兩三條硬規則夾殺後只剩一種寫法」的情況：

| 情境 | 一句話原則 |
|---|---|
| **Run once**（viewDidLoad 等價） | `isFirstAppear` 與 `pullToRefresh` 是兩個語意不同的 ViewAction，導向同一個 APIRequest；guard 寫在 VM |
| **錯誤的流動** | `Error` 與 DTO 同構，都止步於 `handleAPIResponse`；State 只存已翻譯的結果。樂觀更新合法 |
| **多支 API 併發** | 每支各自一組 Request/Response case、狀態各自追蹤；併發用 `async let` |
| **深層回傳** | 逐層中繼，中繼層不 pop、只有終點做一次 `backTo`。鏈長到第三層就回頭考慮合併 feature |
| **週期性更新（輪詢）** | 迴圈在 VM、**`.task` 只能掛 L1**（掛在子組件上會靜默失效，因為 `send` 是同步 closure）；不要用 Bool 旗標防重入（會 fail-closed）。另外**先確認 M 層已把高頻欄位拆出低頻 Model**（見 `mvvmc-model`），否則 View 拆得再細也沒用 |
| **分頁載入** | 「首次載入」與「載入更多」是兩件事，即使打同一支 endpoint 也要各自追蹤狀態 |
| **表單頁** | 輸入緩衝屬 State 不是 Domain Model；驗證是 computed property；防重送 guard 在 VM |


## 明確不在規範範圍的事

以下都屬於各人／各團隊的既有習慣，**MVVMC 不表態**。列在這裡是為了讓「沒寫」是個明確的決定，而不是遺漏——避免有人（或 AI）自行發明一套再宣稱那是 MVVMC 的要求。

**1. 網路層怎麼發請求**

endpoint 定義在哪個檔、叫什麼名字、用 `URLSession` 還是第三方、錯誤怎麼包——不規範。

> demo 把 endpoint 放在 `FeatureViewModel+APIs.swift`（見 `Sources/Pages/PostList/`），那只是**其中一種擺法**。

**2. ViewModel 怎麼取得依賴**（service / repository / 快取）

DI 從 `init` 注入、singleton、static 方法——都可以，看團隊習慣。

> 補充一點事實供選擇時參考：MVVMC 的測試從 `.apiResponse` 注入結果（見 `mvvmc-testing`），**不需要換掉 service 就能測 ViewModel**。所以在這個架構裡，DI 是工程偏好，不是為了可測試性而被迫付出的成本。

**3. 非父子關係的跨 VM 通訊**

Tab A 改了資料要讓 Tab B 反映——共享 store、通知機制、回到畫面時重新載入，都由專案自行決定。`onRoute` / `onCallback` 只處理父子關係，不會被擴充成通用的事件匯流排。

---

**但這三件事不在「不規範」之列**——它們是 MVVMC 的邊界，一律遵守：

- ✅ `handleAPIRequest` 拿到結果後轉成 `.apiResponse(...)` 回到 `doAction`，不在 request 端直接改 state 的資料欄位
- ✅ 寫進 state 的必須是 Domain Model（`toDomain()` 之後），DTO 止步於 `handleAPIResponse`
- ❌ 審查時不得以「endpoint 沒有獨立檔案」「沒有 APIManager」「沒有用 DI」這類理由開單

---

## 三種任務模式

| 模式 | 做什麼 |
|---|---|
| **A：生成** | 依上方規範產生代碼。使用者未要求就只給代碼；要說明時講這幾件事：**State 設計**、**Action 分層**（ViewAction / APIRequest / APIResponse 各自職責）、**資料流**（View 觸發到 state 更新的完整路徑） |
| **B：審查** | 輸出報告：✅ 符合規範 / ❌ 違規（表格：位置、問題、規範依據、建議修正）/ ⚠️ 灰色地帶（說明判斷理由） |
| **C：重構** | 先出審查報告（同 B）→ 重構後完整代碼 → 「重構說明」列出每項改動對應的規範條目 |
