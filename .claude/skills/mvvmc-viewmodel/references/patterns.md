# ViewModel 場景模式

`SKILL.md` 定義的是 VM 的**形狀**（三合一宣告、`doAction` 單一進入點、Action 分層）。這份文件是**場景模式**：遇到特定情境時，職責該怎麼分配。

每一節都可以獨立閱讀，遇到對應情境時再查。

---

## Run once（viewDidLoad 等價）

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
- ✅ **樂觀更新是允許的**：送出成功後直接把 state 改成預期結果（不等重新載入），即使那個 Domain Model 是 VM 自己構造的。「寫進 state 的必須是 `toDomain()` 之後的東西」約束的是**資料來源**（DTO 不得外洩到 UI），不是禁止 VM 生成 Domain Model
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

## 深層回傳（結果要跨越中間頁）

`onCallback` 定義的是**單層**父子關係。但 wizard（步驟 1→2→3，最後一步的結果要回到起點）這類流程需要跨層回傳，做法是**逐層中繼**：

- ✅ 每一層把子層的 callback 轉成自己的 callback 往上拋
- ✅ **中繼層不做 pop**，只轉發；**只有終點做一次** `AppRouter.shared.backTo(目標VC, from: self)` 一次退到位
  > 照 `mvvmc-hostcontroller` 模板「每個 callback 分支都配一個 `back(from:)`」寫，深層回傳會連放三次 pop 動畫
- ✅ 中繼層的 `ViewAction` 會多出 `childDidFinish` 這種與自身業務無關的 case——那是中繼的必要成本，審查時不該當成違規
- ⚠️ **中繼鏈到第三層還在長，回頭問「這幾頁是不是該合併成一個 feature」**（見 `mvvmc-structure`〈feature 邊界〉）。wizard 的每一步共用同一份草稿、只服務同一個流程，合成一個 feature 用 `step` enum 驅動往往更簡單

「回上一步」則相反：子層回報 `didGoBack`，由**父層** `AppRouter.shared.back(from: self)`。

---

## 週期性更新（輪詢）

- ✅ **迴圈寫在 VM，由 View 的 `.task` 啟動**：`.task { await viewModel.doAction(.view(.statusDidAppear)) }`，VM 內 `while !Task.isCancelled { ... try await Task.sleep(...) }`
  > 這是唯一同時滿足三條硬規則的做法：C 層不得起 Task、View 不做流程決策、取消要有人負責。`.task` 綁 View 生命週期，離開畫面時**結構化地**取消整條鏈
- ✅ 每輪之間用 `try await Task.sleep(...)`，被取消時自動丟錯結束迴圈
- ✅ 只有首次才寫 `.loading`，之後的輪詢靜默更新——否則畫面每 N 秒閃一次
- ✅ **`.task` 必須掛在 L1**，不能掛在子組件上：子組件收到的 `send` 是**同步** closure，`.task { send(.didAppear) }` 會在 `send` 回傳的瞬間結束，整條輪詢鏈立刻被取消。這是「子組件只收同步 `send`」與「輪詢靠 `.task` 生命週期」兩條規則相乘的結果——照直覺掛在狀態列那個子組件上會**靜默壞掉**
- ⚠️ **`.task` 掛在 `if / else` 分支的內容上會被取消重建**：載入完成時分支翻轉，SwiftUI 認定那是不同的 view，於是取消舊 task 再起一個。需要穩定身分時包一層容器
- ❌ **不要用 Bool 旗標防止輪詢重入**：舊迴圈的收尾與新迴圈的啟動誰先抵達 MainActor 沒有保證，旗標可能被永久卡在 `true`——輪詢再也不會啟動。**fail-closed 比偶爾多跑一輪嚴重得多**
- ⚠️ **樂觀更新與輪詢會 race**：送出成功後樂觀寫入新狀態，但一個在送出前就發出、還沒回來的輪詢回應會把它蓋回舊值。上面的〈錯誤的流動〉允許樂觀更新、這一節要求輪詢靜默寫入，兩條同時成立時這個 race 必然存在。做法由專案決定（樂觀更新後暫停一輪並補一次單次查詢、或讓回應帶時間戳比對後才覆蓋），但**必須知道它在那裡**——它不會在開發時出現，只在網路慢的時候出現
- ⚠️ **已知限制**：UIKit 的 push **不會**移除下層 View，所以這一頁被推到下一頁之後 `.task` 不會取消，輪詢繼續跑。若這有成本（電量、API 額度），需要另外設計暫停機制——MVVMC 目前沒有標準做法，這是 UIKit 導航與 SwiftUI 生命週期的語意落差

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
