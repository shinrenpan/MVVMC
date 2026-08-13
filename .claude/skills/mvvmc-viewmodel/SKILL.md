---
name: mvvmc-viewmodel
description: |
  MVVMC VM 層架構規範。涉及建立、審查、重構 @Observable ViewModel 時觸發。確保遵守 @Observable + @MainActor + final class 三合一規範，以及 doAction 單一進入點。
---

# MVVMC ViewModel Skill

你是一位資深 iOS 工程師，專精於 Swift Observation framework 與 clean architecture。

State 結構請參考 `mvvmc-model` skill 的規範。
詳細模板與範例請見：`references/viewmodel-templates.md`

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

**onRoute / onCallback：**

- `onRoute` — HostController 設定，接收導航意圖後執行導航
  - 型別：`(@MainActor (Router) -> Void)?`，同步
  - ViewModel 呼叫：`onRoute?(.toDetail(post))`（不經過 doAction dispatch）
  - why 不走 doAction：導航不改 state、也不需要 async，效果歸 C 層執行；`doAction` 專責狀態轉移，`onRoute`/`onCallback` 是交給 C 處理副作用的逃生口
- `onCallback` — 父 HostController 設定，接收跨 VC 回傳值
  - 型別：`(@MainActor (Callback) async -> Void)?`，async（避免呼叫端需要包 Task）
  - ViewModel 呼叫：`await onCallback?(.didSelectUser(user))`（在 doAction 內 await）
- ✅ 兩者只在有實際需求時才宣告
- ✅ 必須標注 `@ObservationIgnored`
- ✅ 非 UI 相關的 property 一律標注 `@ObservationIgnored`

**什麼算「導航」——`onRoute` 的邊界：**

| 副作用 | 誰做 | 判準 |
|---|---|---|
| push / pop / sheet / tab 切換 / dismiss | `onRoute?(...)` → C 層 | **會改變 App 內的畫面堆疊** |
| 開啟外部 URL（`UIApplication.shared.open`）、分享、Haptic、複製到剪貼簿 | ViewModel 直接執行 | 不改變畫面堆疊，做完就結束 |

VM 直接做第二類是刻意的——為它們繞一圈 `onRoute` 只是把單行呼叫拆成三個地方（Router case、handleRouter 分支、C 層實作），換不到任何解耦。判準是「畫面堆疊」而不是「有沒有碰到 UIKit」。

> `@Observable` 追蹤所有 stored property；closure 或非 UI 狀態若未標注 `@ObservationIgnored`，會觸發不必要的 View re-render。

---

## 常見模式：Run once（viewDidLoad 等價）

**問題**：SwiftUI 的 `.onAppear` / `.task` 每次畫面出現都會觸發，沒有 UIKit `viewDidLoad` 的等價物。

**做法**：`isFirstAppear` 與 `pullToRefresh` 是兩個**語意不同**的 ViewAction，但導向同一個 APIRequest：

```swift
enum ViewAction: Sendable {
  case isFirstAppear
  case pullToRefresh
}

enum APIRequest: Sendable {
  case loadData
}
```

```swift
// View
.task { await viewModel.doAction(.view(.isFirstAppear)) }
.refreshable { await viewModel.doAction(.view(.pullToRefresh)) }
```

```swift
// ViewModel
case .isFirstAppear:
  guard state.isFirstAppear else { return }
  state.isFirstAppear = false
  await doAction(.apiRequest(.loadData))

case .pullToRefresh:
  await doAction(.apiRequest(.loadData))
```

- guard 寫在 VM，**View 不碰 State**，state 的所有權仍在 ViewModel
- `isFirstAppear` 用名字表達「只跑一次」的語意；`loadData` 保持乾淨，不帶生命週期假設
- 兩個入口分開，日後要讓下拉刷新多做一件事（清快取、重置分頁）不必動到首次載入

---

## 錯誤的流動

**`Error` 與 DTO 同構：兩者都是髒資料，都止步於 `handleAPIResponse`。**

```
network throws  →  handleAPIRequest 接住，包成自訂錯誤
                →  .apiResponse(.xxx(.failure(...)))
                →  handleAPIResponse 翻成「可以直接顯示的東西」寫進 state
                →  View 直接顯示，不做任何錯誤判讀
```

```swift
// handleAPIRequest：接住 throw，轉成 Action，不在這裡改 state 的資料欄位
do {
  let dtos = try await PostListAPI.fetch()
  await doAction(.apiResponse(.fetchPosts(.success(dtos))))
} catch {
  await doAction(.apiResponse(.fetchPosts(.failure(.message(error.localizedDescription)))))
}

// handleAPIResponse：翻譯 → 寫 state
case let .fetchPosts(.failure(.message(msg))):
  state.api.fetchPosts = .error(msg)
```

- ✅ State 存的是**已翻譯的結果**（訊息字串，或自訂的 `Equatable` 錯誤 enum）
- ❌ State 不存 `any Error` / `URLError` / `DecodingError`——網路細節不該滲進 UI，且 `Error` 不 `Equatable`，會讓 `State` 失去 `Equatable`（見 `mvvmc-model`〈State 欄位型別〉）
- ❌ View 不做錯誤判讀（`if error is URLError`）——要顯示什麼在 VM 就決定完
- 💡 錯誤要分流（可重試 / 需重新登入 / 純提示）時，做成自訂的 `Equatable` 錯誤 enum 存進 state，讓 View 用 `switch` 顯示；仍然不是把原始 `Error` 丟過去

---

## 多個 API 的並發

一個 feature 同時要打多支 API 時，**每支各自一組 `APIRequest` / `APIResponse` case、狀態也各自追蹤**：

```swift
enum APIRequest: Sendable {
  case fetchProfile
  case fetchOrders
}
```

- ✅ 併發用 `async let` / `TaskGroup`（見 `swift-concurrency`），結果各自 dispatch 回自己的 `.apiResponse`
- ✅ 分開追蹤才能表達「A 好了 B 還在轉」「A 失敗但 B 成功」這類真實狀態
- ❌ 合併成單一「載入中」旗標會讓任一支失敗就整頁報錯，也無法局部重試
- 💡 有防重入需求時，也是**每支各自判斷**，不是共用一個閘門

> 狀態欄位長什麼樣（要不要包成容器、有哪些 case）是 M 層的事，且**形狀不在規範範圍**——見 `mvvmc-model`〈State 欄位型別〉。

---

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

### 模式 A：生成新 ViewModel

依照 `references/viewmodel-templates.md` 產生代碼，若使用者未要求則省略架構說明；若需要則附上：

```
[完整 Swift 代碼]

---
### 架構說明
- **State 設計**：每個 state 屬性的用途
- **Action 分層**：ViewAction / APIRequest / APIResponse 各自的職責
- **資料流**：從 View 觸發到 state 更新的完整路徑
```

### 模式 B：審查現有 ViewModel

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

### 模式 C：重構 ViewModel

1. 先輸出審查報告（同模式 B）
2. 輸出重構後完整代碼
3. 附上「重構說明」，列出每項改動對應的規範
