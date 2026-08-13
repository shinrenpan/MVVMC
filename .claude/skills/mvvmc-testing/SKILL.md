---
name: mvvmc-testing
description: |
  MVVMC 單元測試規範。涉及為 ViewModel 撰寫、審查、重構測試時觸發。核心哲學：透過 doAction(.apiResponse(...)) 直接注入結果，不需要 protocol 或 mock class。
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

## 四類測試情境

### 1. Guard 邏輯（防重複觸發）

驗證 `isFirstAppear` guard 正確阻擋重複呼叫：

```swift
@Test
func `isFirstAppear guard blocks duplicate trigger`() async {
  let vm = FeatureViewModel()
  vm.state.isFirstAppear = false       // 模擬已出現過
  await vm.doAction(.view(.isFirstAppear))
  #expect(vm.state.api.fetchItems == .prepare)  // state 沒有變動
}
```

### 2. apiResponse 注入（成功 / 失敗）

直接注入 API 結果，驗證 state 更新：

```swift
@Test
func `fetchItems success populates items`() async {
  let vm = FeatureViewModel()
  let dtos: [FeatureViewModel.ItemDTO] = [
    .init(id: 1, user_id: 1, name: "Item A"),
    .init(id: 2, user_id: 1, name: "Item B"),
  ]
  await vm.doAction(.apiResponse(.fetchItems(.success(dtos))))
  #expect(vm.state.items.count == 2)
  #expect(vm.state.items[0].name == "Item A")
  #expect(vm.state.api.fetchItems == .success)
}

@Test
func `fetchItems failure sets error status`() async {
  let vm = FeatureViewModel()
  await vm.doAction(.apiResponse(.fetchItems(.failure(.message("Network error")))))
  #expect(vm.state.items.isEmpty)
  #expect(vm.state.api.fetchItems == .error("Network error"))
}
```

> **善用 State 的 `Equatable`**：M 層規範要求 `State` 預設遵守 `Equatable`（見 `mvvmc-model`）。狀態欄位一多時，逐欄位 `#expect` 會冗長且容易漏測，可直接比對整個 state：
>
> ```swift
> var expected = FeatureViewModel.State()
> expected.items = [.init(id: 1, name: "Item A"), .init(id: 2, name: "Item B")]
> expected.api.fetchItems = .success
> #expect(vm.state == expected)   // 一行涵蓋所有欄位，多餘變動也會被抓出
> ```
>
> 逐欄位斷言仍適用於「只想驗證單一欄位、不在意其餘」的情境；要「鎖定完整狀態」時用整體比對。

### 3. Callback / Router 驗證

`onCallback` 與 `onRoute` 都只是 closure，測法完全相同——設好 closure，觸發 action，斷言收到的值：

```swift
@Test
func `didSelectUser calls correct callback`() async {
  let vm = FeatureViewModel()
  var received: FeatureViewModel.Callback?
  vm.onCallback = { received = $0 }

  let user = FeatureViewModel.User(id: 2)
  await vm.doAction(.view(.didSelectUser(user)))
  #expect(received == .didSelectUser(user))
}

@Test
func `postDidTap routes to detail`() async {
  let vm = FeatureViewModel()
  var received: FeatureViewModel.Router?
  vm.onRoute = { received = $0 }

  let post = FeatureViewModel.Post.mock
  await vm.doAction(.view(.postDidTap(post)))
  #expect(received == .toDetail(post))
}
```

- 測的是**導航意圖**（VM 有沒有發出正確的 Router case），不是導航行為（HostController 有沒有真的 push）——後者需要 UIKit 環境，屬整合／UI 測試
- 要用 `#expect(received == ...)` 斷言，`Router` / `Callback` enum 需為 `Equatable`；帶 associated value 時，裡面的 Domain Model 也要 `Equatable`（M 層預設全加，見 `mvvmc-model`）

### 4. ViewAction 連鎖觸發 API 時

有些 ViewAction 會在更新 state 後直接轉發 `.apiRequest`（例如套用篩選、切換排序）。此時 `await doAction(.view(...))` 會**一路等到請求跑完**，測試實質上變成整合測試。處理原則：

```swift
@Test
func `didFilterUser sets filterUserId`() async {
  let vm = FeatureViewModel()
  vm.state.isFirstAppear = false
  // 註明：此 action 會連鎖走完 request 路徑，故此測試較慢
  await vm.doAction(.view(.didFilterUser(3)))
  #expect(vm.state.filterUserId == 3)   // 只斷言這個 ViewAction 自己造成的 state 變更
}
```

- ✅ 斷言只放**該 ViewAction 自身造成的 state 變更**，API 結果交給 `.apiResponse` 注入測試（第 2 類）
- ✅ 在測試上註明它會走 request 路徑，讓後人知道它為何慢
- ❌ request 路徑會打**真實網路**時，這個測試不該進單元測試套件——改為只測 `.apiResponse` 注入，「ViewAction 有沒有正確轉發 APIRequest」靠 code review 覆蓋。為了測試而引入 protocol / DI 框架違反本 skill 的設計哲學

---

## Swift Testing 實用手法（按需採用）

以下不是規範，是遇到對應情境時比土法煉鋼更好的寫法。

**參數化測試**——同一段驗證跑多組輸入，失敗時報告會指出是哪一組：

```swift
@Test(arguments: [0, 1, 5])
func `fetchItems maps every DTO`(count: Int) async {
  let vm = FeatureViewModel()
  let dtos = (0..<count).map { FeatureViewModel.ItemDTO(item_id: "\($0)", item_name: "Item") }
  await vm.doAction(.apiResponse(.fetchItems(.success(dtos))))
  #expect(vm.state.items.count == count)
}
```

**`#require` 解 Optional**——比 `!` 安全：失敗即中止該測試，不會讓後續斷言連環爆：

```swift
@Test
func `fetchUser success sets user`() async throws {   // 注意 throws
  let vm = FeatureViewModel()
  await vm.doAction(.apiResponse(.fetchUser(.success(dto))))

  let user = try #require(vm.state.user)   // nil → 測試在此失敗中止
  #expect(user.name == "Alice")
}
```

**`confirmation` 驗證呼叫次數**——「有沒有被呼叫」用前面的變數捕捉即可，但「**剛好被呼叫幾次**」（防重入、防重複觸發）用它才精準：

```swift
@Test
func `duplicate trigger fires callback exactly once`() async {
  await confirmation("callback fired", expectedCount: 1) { fired in
    let vm = FeatureViewModel()
    vm.onCallback = { _ in fired() }
    await vm.doAction(.view(.didSelectItem(.mock)))
    await vm.doAction(.view(.didSelectItem(.mock)))   // 第二次應被 guard 擋掉
  }
}
```

`#expect(throws:)` 在 MVVMC 的 VM 測試裡通常用不到——`doAction` 不 throws，錯誤走 `.apiResponse(.failure(...))`。它適用的是 endpoint 層的獨立測試。

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

## 什麼不值得測試

| 情境 | 原因 |
|------|------|
| 實際 API 網路呼叫 | 非確定性、速度慢，交給整合測試 |
| SwiftUI View render | UI 測試範疇，非單元測試 |
| HostController 的導航**行為**（push / pop / present 真的發生） | 依賴 UIKit 環境；VM 端只驗證意圖（`onRoute` 收到什麼），見上表 |

---

## 三種任務模式

### 模式 A：為現有 ViewModel 補測試

1. 讀取 `*ViewModel.swift` 和 `*ViewModel+Models.swift`
2. 識別所有 `ViewAction`、`APIResponse` case
3. 依照上方三類情境，為每個 case 生成對應測試

### 模式 B：審查現有測試

```
### 測試審查報告

✅ 符合規範：
- ...

❌ 問題項目：
| 位置 | 問題 | 建議修正 |
|------|------|----------|

⚠️ 灰色地帶：
- ...
```

### 模式 C：重構現有測試

1. 先輸出審查報告（同模式 B）
2. 輸出重構後完整測試代碼
3. 附上說明，列出每項改動對應的規範
