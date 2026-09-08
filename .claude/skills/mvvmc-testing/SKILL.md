---
name: mvvmc-testing
description: |
  MVVMC 單元測試規範。涉及為 ViewModel 撰寫、審查、重構測試，或使用 Swift Testing（@Test、#expect、#require、confirmation）測試 MVVMC 程式碼時觸發。核心哲學：透過 doAction(.apiResponse(...)) 直接注入結果，不需要 protocol 或 mock class。
---

# MVVMC Testing Skill

你是一位資深 iOS 工程師，專注於 MVVMC 架構下的單元測試策略。

---

## 設計哲學

**不需要 protocol，不需要 mock class。**

MVVMC 的 `doAction(.apiResponse(...))` 本身就是天然的測試注入點：

```swift
// 不走 API，直接注入結果
await vm.doAction(.apiResponse(.fetchUser(.success(dto))))
await vm.doAction(.apiResponse(.fetchUser(.failure(.message("Not found")))))
```

這樣做的好處：
- 零額外抽象：不需要為了測試引入 protocol / dependency injection 框架
- 測試意圖清晰：直接驗證「給定這個 API 回應，state 變成什麼」
- Feature 變動快時，只有 Action enum 改動，測試跟著改即可

> **也不引入 `withMainSerialExecutor`**（`swift-concurrency-extras`）——這是定案，不是還沒評估。那個工具是用來讓 async 測試的排程變確定、解 flaky test 的，但：
>
> - 從 `.apiResponse` 注入結果的測試**本來就是確定性的**：沒有真實網路、沒有計時、沒有競態
> - 唯一的 flaky 來源是「ViewAction 連鎖觸發 API」那類測試，而規範已經在源頭處理掉了（見〈什麼值得測試〉：會碰真網路的不該進單元測試套件）
>
> **問題在源頭被解決，就不必在下游加工具。** 依賴的成本是永久的、收益是假設性的——真的遇到 flaky 再談。

### `state.api` 狀態容器

下方範例大量出現 `state.api.<name>`。這是 **demo 採用的做法**：每個 API 動作在 `State` 裡有一個對應的狀態欄位，記錄該次請求目前處於哪個階段。demo 用的狀態值：

- `.prepare`：初始／尚未觸發
- `.success`：請求成功
- `.error(...)`：請求失敗，附帶錯誤訊息
- （若該流程有讀取指示器，也可有 `.loading`）

> **形狀不強制**：要不要包成 `api` 容器、狀態 enum 有哪些 case、怎麼命名，屬個人／團隊習慣（見 `mvvmc-model`〈State 欄位型別〉）。本 skill 只借它示範測試手法——**重點是「斷言請求狀態的轉移」這個做法**，不是這個特定形狀。專案若用別的表達方式（`isLoading: Bool` + `errorMessage: String?` 等），把下方斷言換成對應欄位即可。

---

## 測試結構

### 基本格式

```swift
import Testing
@testable import AppModule

@MainActor
struct FeatureViewModelTests {

  @Test
  func `isFirstAppear guard blocks duplicate trigger`() async {
    let vm = FeatureViewModel()
    vm.state.isFirstAppear = false
    await vm.doAction(.view(.isFirstAppear))
    #expect(vm.state.api.fetchItems == .prepare)
  }
}
```

- `import Testing`（Swift Testing framework，iOS 17+）
- `@testable import` 對應 app module 名稱
- `@MainActor` 標注在 struct 層級，覆蓋所有 test func
- 每個 `@Test` func 都是 `async`

### 測試命名（Swift 6.2 raw identifier）

使用反引號包裹完整描述句，不需要 `@Test("...")`：

> **why（這是硬規則，不是品味）**：舊寫法 `@Test("fetchUser success sets user state") func testFetchUserSuccess()` 有**兩個各自維護的名字**——描述字串與函式名。改了行為之後改哪一個都算「改過了」，於是它們必然分岔。反引號把兩個名字塌縮成一個，**漂移在型別層級變成不可能**。
> 這跟 `mvvmc-model`〈State 的 computed property〉「不要另存一個會不同步的 stored 欄位」是**完全同構的論證**：一份真相 vs 兩份會分岔的真相。
> 沒有這段 why 的時候，這條規則在「改一批既有測試」這種成本大於零的場合會直接輸掉——**陳述結論而不解釋為何的規則，成本一大就會被忽略。**

```swift
// ✅ Swift 6.2 raw identifier
@Test
func `fetchUser success sets user state`() async { ... }

// ❌ 舊寫法，避免使用
@Test("fetchUser success sets user state")
func testFetchUserSuccess() async { ... }
```

Raw identifier 格式：`描述主語` + `條件/輸入` + `預期結果`

---

> **新增一個測試手法時，順手寫一行「適用訊號」**——一個當場 grep 得出來的程式碼形狀。
>
> 例：`confirmation`（驗證「剛好被呼叫幾次」）→ **適用訊號：VM 內有 `guard … else { return }` 形式的防重入／防重複觸發。**
>
> why：規範更新最主要的產出是「**一個更好的做法**」，而審查只查違規、**不查未採用**——一份只列違規的報告對「有更好的手法」完全是盲的，把它塞進去又會稀釋違規的訊號。適用訊號把成本移到作者身上付一次（寫下手法的當下他最清楚什麼形狀需要它），之後任何人剛好在那個檔案裡工作時，**一次搜尋就知道自己適不適用**。
> 這跟〈已決事項必須附當場可驗的重開條件〉是同一個形狀套在不同東西上——都是把「記得回頭看」換成「一行就驗得出來」。

## 架構不變式測試（不測行為，測「專案的某個性質仍然成立」）

`mvvmc-testing` 其餘部分講的都是 ViewModel 行為測試。但有一類東西**不是行為**，而且是規範反覆在意的那種問題：

> **判準：這個東西壞掉的時候，編譯器沉默、執行期沉默、review 也看不出來嗎？** 是 → 它需要一條不變式測試，因為單元測試是唯一抓得到它的機制。

實例（都來自上架專案的實戰）：

| 不變式 | 壞掉時的症狀 |
|---|---|
| String Catalog 的每個 key 都有 zh-Hant 譯文 | 繁中裝置**靜默顯示英文**，沒有任何 error |
| 每個原始碼字面值都進了 catalog | 新字串永遠不會被翻譯，而沒有人會發現 |
| 沒有跨 feature 引用其他 feature 的 Domain Model | 耦合逐步累積，**而 `mvvmc-review` Pass 3 想用 `findReferences` 查這件事，實測會回空** |

> ⚠️ **掃原始碼的不變式測試必須先剝掉註解**，否則被註解掉的程式碼會被算成活的引用／活的字串。這是實戰付過代價的細節，值得為它單獨寫一條測試鎖住。
>
> 這跟 `mvvmc-review` Pass 3 那句「grep 會被註解、字串、同名符號誤導」是同一個教訓——**差別是不變式測試可以把那個教訓寫成程式碼並在 CI 上每次跑，而 Pass 3 只能寫成警語。**

**檔名不受 `*ViewModelTests.swift` 慣例約束**（它們不對應任何一個 feature）。相對地，`mvvmc-review` Pass 1 的檔案樣式必須另外把它們讀進來，否則審查在檔名層級就看不見它們。

---

## 什麼值得測試

| 情境 | 測試方式 |
|------|----------|
| Guard 邏輯（isFirstAppear、防重入） | 設定 state 後觸發 action，驗證 state 未變 |
| API 成功路徑 | 注入 `.success(dto)`，驗證 state 欄位正確 |
| API 失敗路徑 | 注入 `.failure(.message(...))`，驗證 error status |
| Callback 觸發 | 設定 `onCallback` closure，驗證回傳值 |
| 導航意圖（`onRoute`） | 設定 `onRoute` closure，驗證收到的 Router case |
| State 欄位計算 | 直接操作 state，驗證 computed property |

> 每一類的完整範例見 `references/patterns.md`，另附三個按需採用的手法（參數化測試、`#require` 解 Optional、`confirmation` 驗證呼叫次數）。

## 什麼不值得測試

| 情境 | 原因 |
|------|------|
| 實際 API 網路呼叫 | 非確定性、速度慢，交給整合測試 |
| SwiftUI View render | UI 測試範疇，非單元測試 |
| HostController 的導航**行為**（push / pop / present 真的發生） | 依賴 UIKit 環境；VM 端只驗證意圖（`onRoute` 收到什麼），見上表 |

---

## 三種任務模式

| 模式 | 做什麼 |
|---|---|
| **A：生成** | 依上方規範產生代碼。使用者未要求就只給代碼；要說明時講這幾件事：先讀 `*ViewModel.swift` 與 `+Models.swift` 識別所有 ViewAction / APIResponse case，再依〈什麼值得測試〉逐項覆蓋 |
| **B：審查** | 輸出報告：✅ 符合規範 / ❌ 違規（表格：位置、問題、規範依據、建議修正）/ ⚠️ 灰色地帶（說明判斷理由） |
| **C：重構** | 先出審查報告（同 B）→ 重構後完整代碼 → 「重構說明」列出每項改動對應的規範條目 |
