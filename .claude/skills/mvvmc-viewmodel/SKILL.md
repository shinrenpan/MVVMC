---
name: mvvmc-viewmodel
description: |
  MVVMC VM 層架構規範。涉及建立、審查、重構 @Observable ViewModel，或處理 doAction / Action enum（ViewAction、APIRequest、APIResponse）、onRoute、onCallback、API 請求與錯誤如何寫進 state 時觸發。確保遵守 @Observable + @MainActor + final class 三合一規範，以及 doAction 單一進入點。
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

- guard 寫在 VM：**View 不自行判讀 State 做流程決策**（不由 View 檢查 `isFirstAppear` 決定要不要打 API），流程控制權留在 ViewModel

  > 這與 V 層允許用 `@Binding` 綁 state 欄位（`TextField` 輸入）**不衝突**：綁定是「值的雙向同步」，流程判斷才是 VM 的專屬職責。兩者的分界見 `mvvmc-view` §2〈Binding vs Action 的選擇邊界〉——會改變「接下來要做什麼」的一律走 Action。
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

```swift
// 兩支一起發，各自走自己的 request → response 鏈
case .isFirstAppear:
  guard state.isFirstAppear else { return }
  state.isFirstAppear = false
  async let categories: Void = doAction(.apiRequest(.fetchCategories))
  async let products: Void = doAction(.apiRequest(.fetchProducts))
  _ = await (categories, products)
```

> 這裡沒有違反「`doAction` 單一進入點」——併發的是**兩次對 `doAction` 的呼叫**，不是繞過它。單一進入點管的是「誰能觸發狀態轉移」，不是「一次只能觸發一個」。

- ✅ 分開追蹤才能表達「A 好了 B 還在轉」「A 失敗但 B 成功」這類真實狀態
- ❌ 合併成單一「載入中」旗標會讓任一支失敗就整頁報錯，也無法局部重試
- 💡 有防重入需求時，也是**每支各自判斷**，不是共用一個閘門

> 狀態欄位長什麼樣（要不要包成容器、有哪些 case）是 M 層的事，且**形狀不在規範範圍**——見 `mvvmc-model`〈State 欄位型別〉。

---

## 分頁載入

分頁的重點不在游標怎麼存，而在**「首次載入」與「載入更多」是兩件不同的事**——即使它們打的是同一支 endpoint：

- ✅ **各自一組 `APIRequest` / `APIResponse` case、各自追蹤狀態**
  > why：狀態欄位只有一格 `.error`。兩者共用的話，第 2 頁失敗會蓋掉第 1 頁的 `.success`，View 就再也無法表達「內容還在、只是下一頁沒載到」——那正是分頁最常見的情境
- ✅ 首次載入是 **replace**，載入更多是 **append**
- ✅ **「還有沒有下一頁」是 state**（來自 API 回應），不要在 View 端用「這次回傳筆數 < pageSize」去猜
- ✅ **觸發時機由 VM 判斷**：View 只回報「列表底部出現了」這個事件，至於要不要真的載入（還有沒有下一頁、是不是正在載入、上一次是不是失敗了）全部是 VM 的 guard
  > 讓 View 比對 `item.id == items.last?.id` 來決定要不要載入，等於 View 讀 state 做流程決策
- ❌ **下一頁失敗後不要自動重打**：footer 還留在畫面上，不加條件就會變成無限重試迴圈。改由使用者按重試觸發

游標的形式（page number / cursor / offset）、pageSize 放哪，屬專案自訂，不在規範範圍。

---

## 表單頁

- ✅ **輸入緩衝屬 `State`，不是 Domain Model**——使用者還沒送出的東西不是業務實體。純表單頁**可以沒有 Domain Models 區塊**，不要為了湊格式硬造一個沒有消費者的型別
- ✅ **驗證是推導值**：`isValid` 寫成 State 的 computed property（見 `mvvmc-model`），不要另存一個會不同步的 stored 欄位，更不要在 View 裡判斷
- ✅ **送出中要同時表達三件事**：按鈕 loading、欄位不可編輯、**不能重複送出**——最後一項是 VM 的 guard，不是靠 UI 禁用來保證
- ✅ **送出失敗必須保留使用者的輸入**：失敗只寫狀態欄位，不要清空輸入緩衝
- ✅ **送給 API 的 request DTO 放 DTOs 區塊**，由 `handleAPIRequest` 從輸入緩衝組出來
  > 不要在 State 的型別上寫 `toDTO()`——那會讓輸入緩衝反過來知道 API 合約，等於把 DTO 的髒污染回 State 層

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
