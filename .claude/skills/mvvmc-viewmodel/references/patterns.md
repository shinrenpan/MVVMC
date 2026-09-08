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
  > ⚠️ **但這一頁若同時有輪詢，先讀〈週期性更新〉的 race 警告再動手**——一個在送出前就發出、還沒回來的輪詢回應會把樂觀寫入蓋回舊值。那個警告指向這裡，這裡也必須指向它：**危險住在兩節的交集，而「每一節可獨立閱讀」的讀法剛好走在沒有指標的方向。**
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
- ⚠️ **先分辨這是哪一種深層回傳**，兩枝的規則完全不同：

  | | 終結式 | 非終結式 |
  |---|---|---|
  | 形狀 | wizard、選擇器——走到底、拿結果、**一次退回起點** | 列表裡逐項操作——結果往上冒，**使用者留在深處繼續用** |
  | 判斷問句 | 拿到結果之後，使用者還會留在這一層繼續操作嗎？**不會** → 終結式 | **會** → 非終結式 |
  | 誰執行退回 | **發起頁**（見下） | **沒有退回動作**，這個問題不成立 |
  | 核心規則 | 中繼層不 pop，發起頁一次退到位 | **轉發要累積不要即時**（見下） |

- ✅ **終結式**：中繼層不做 pop，只轉發；**由發起頁（回傳鏈的起點，不是導航的最深處）做一次** `AppRouter.shared.backTo(self)` 一次退到位
  > 之所以是發起頁：最深處那一頁**取得不到**起點的 VC 參考——AppRouter stateless 不持有 VC、init 與 Callback 都只傳 primitive、中繼層只轉發。**發起頁自己就是目標，不需要任何參考。** 不要為此發明「把 VC 塞進 Callback」的解法，那會違反 `mvvmc-structure` 的 primitive 規則
- ✅ **非終結式**：❌ 不要每次變動就往上轉發——**上層此刻依定義不可見**（它在 sheet 底下或 push 之下），即時轉發做的是沒有人在看的工。中繼層累積「這一趟有沒有變過」的旗標，在**自己關閉時**往上發一次
  > 旗標放 `@ObservationIgnored`，不放 `State`——只有 VM 自己讀的東西進 State 會讓所有讀 `state` 的 View 全部失效重算（判準是「View 讀不讀」）。
  > 轉發的成本由**上層的 reload** 決定，而規範不該假設 reload 便宜：同一個形狀在「重撈 12 筆本地資料」與「重跑五千筆地理查詢」上，一邊不痛一邊痛
- ✅ **Callback 命名要能看出走哪一枝**：終結式用 `didFinish` 系（帶「該回去了」的語意），非終結式用 `didChange` 系（純告知）。兩者混用的後果是可見的——終結式 case 用在非終結流程會讓使用者莫名彈回起點，反過來則走到底卻停在最後一頁
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
- ✅ **間隔必須可注入**（VM 的 init 加一個 `pollInterval: Duration = .seconds(5)` 預設參數）。硬編進迴圈會讓這個入口**真的變成不可測**——測試得真的等 5 秒。這是 primitive 預設參數，不是 protocol 也不是 mock class，與 `mvvmc-viewmodel` 已允許的 DI 形狀一致
- ✅ **`.task` 必須掛在 L1**，不能掛在子組件上：子組件收到的 `send` 是**同步** closure，`.task { send(.didAppear) }` 會在 `send` 回傳的瞬間結束，整條輪詢鏈立刻被取消。這是「子組件只收同步 `send`」與「輪詢靠 `.task` 生命週期」兩條規則相乘的結果——照直覺掛在狀態列那個子組件上會**靜默壞掉**
- ⚠️ **`.task` 掛在 `if / else` 分支的內容上會被取消重建**：載入完成時分支翻轉，SwiftUI 認定那是不同的 view，於是取消舊 task 再起一個。需要穩定身分時包一層容器
- ❌ **不要用 Bool 旗標防止輪詢重入**：舊迴圈的收尾與新迴圈的啟動誰先抵達 MainActor 沒有保證，旗標可能被永久卡在 `true`——輪詢再也不會啟動。**fail-closed 比偶爾多跑一輪嚴重得多**
  > **這條禁令只對輪詢成立，不要外推到其他防重入場景。** 三個場景各有結論，逐格照抄，不要從其中一格推另一格：
  >
  > | 場景 | 用不用 Bool 旗標 | 為什麼 |
  > |---|---|---|
  > | **輪詢重入** | ❌ 不用，改 cancel-and-rebuild | fail-closed = 畫面永遠不更新且無聲無息，使用者不會知道要重進 |
  > | **表單送出** | ✅ 用，但重置必須走 `defer`（見〈表單頁〉） | 多送出一筆訂單比按鈕卡住嚴重；而按鈕卡住使用者看得見、重進頁面即可脫困 |
  > | **分頁載入更多** | ❌ 不用，由 `hasNextPage` + 請求狀態共同決定 | fail-closed 的畫面**與「沒有更多了」完全相同**，使用者會確信系統是對的 |
  >
  > 判準（**僅供延伸到未列情境時參考，不要單獨引用**）：問的是「fail-closed 之後，使用者會不會去做那個能重置狀態的動作（通常是離開再重進）」。但注意它不完備——輪詢若驅動一個可見的「最後更新於 N 秒前」時間戳，使用者有動機重進，判準會給出錯誤答案，那一格仍然不該用旗標
- ⚠️ **樂觀更新與輪詢會 race**：送出成功後樂觀寫入新狀態，但一個在送出前就發出、還沒回來的輪詢回應會把它蓋回舊值。上面的〈錯誤的流動〉允許樂觀更新、這一節要求輪詢靜默寫入，兩條同時成立時這個 race 必然存在。做法由專案決定（樂觀更新後暫停一輪並補一次單次查詢、或讓回應帶時間戳比對後才覆蓋），但**必須知道它在那裡**——它不會在開發時出現，只在網路慢的時候出現
- ⚠️ **已知限制**：UIKit 的 push **不會**移除下層 View，所以這一頁被推到下一頁之後 `.task` 不會取消，輪詢繼續跑。若這有成本（電量、API 額度），需要另外設計暫停機制——MVVMC 目前沒有標準做法，這是 UIKit 導航與 SwiftUI 生命週期的語意落差
  > **Android 分支更嚴重**：`mvvmc-skip` #10 把 `.task` 換成 `.onAppear { Task { … } }`（非結構化），**連取消機制都沒有**——不是「特定情況不取消」，是「沒有取消路徑」。移植輪詢頁時取消要自己接

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
  > ⚠️ **旗標的重置必須用 `defer`，不能寫在 `await` 之後**：
  > ```swift
  > guard !state.isSubmitting else { return }
  > state.isSubmitting = true
  > defer { state.isSubmitting = false }
  > ```
  > View 的互動一律是 `Task { await viewModel.doAction(...) }`，那個 Task 綁在 View 上。使用者在送出中途返回上一頁 → Task 取消。
>
> **實測（2026-09-08，Swift 6，`swiftc -swift-version 6`）**：
>
> | 送出路徑的寫法 | `defer` 執行？ | 寫在 `await` 之後那一行執行？ |
> |---|---|---|
> | `try await`（取消被拋出） | ✅ | ❌ **不執行** |
> | `try?` / 非 throwing await（取消被吞掉） | ✅ | ✅ 執行 |
>
> 所以「重置不會執行」**只在取消真的被拋出時成立**——但那正是正確寫法（請求應該要能被取消）。**`defer` 在兩種寫法下都安全，所以它是唯一不需要先判斷自己屬於哪一格的做法。**
>
> 漏掉的後果：UIKit 的 push 不銷毀下層 VC，ViewModel 實例還活著，送出鈕從此永遠禁用。**這就是〈週期性更新〉那條禁令描述的 fail-closed，只是成因換成 Task 取消**
- ✅ **送出失敗必須保留使用者的輸入**：失敗只寫狀態欄位，不要清空輸入緩衝
- ✅ **送給 API 的 request DTO 放 DTOs 區塊**，由 `handleAPIRequest` 從輸入緩衝組出來
  > 不要在 State 的型別上寫 `toDTO()`——那會讓輸入緩衝反過來知道 API 合約，等於把 DTO 的髒污染回 State 層

---
