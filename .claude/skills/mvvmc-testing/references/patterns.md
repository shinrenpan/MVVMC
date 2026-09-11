# 測試範例集

`SKILL.md` 定義的是**測什麼、為什麼這樣測**。這份文件是**怎麼寫**——四類情境的完整範例，以及幾個按需採用的 Swift Testing 手法。

照著抄之前先確認 `SKILL.md` 的〈什麼值得測試〉——範例只是形狀，判斷要不要測是另一回事。

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
>
> ⚠️ **「涵蓋所有欄位」的前提是 `State` 的 `Equatable` 是編譯器合成的。** `mvvmc-model`〈Equatable 規則〉允許三種例外**手寫 `==` 跳過某個成員**（最常見是閉包）。一旦跳過，整體比對就**靜默不再檢查那個欄位**——而這裡的措辭還在保證它被涵蓋。
> 所以：**State 手寫過 `==` 時，被跳過的欄位必須另外逐欄位斷言**，否則那個欄位在整個測試套件裡沒有任何覆蓋（例如 `onRetry` 在錯誤路徑被設成 `nil`，重試鈕從此無效，整體比對照樣通過）。
>
> ⚠️ **第二個來源，而且影響的頁面更多**：`mvvmc-model` 明說「**computed property 不參與 `Equatable` 合成（只比 stored 欄位）**」。而〈表單頁〉**強制要求** `isValid`（或 `blockingReason`）是 State 的 computed property——**所以一個表單頁的整體比對，天生就不涵蓋驗證結果。**
> 手寫 `==` 是例外，computed property 是規範**強制**的形狀，兩者是同一個病的兩個來源。**表單驗證一律必須有自己的逐項斷言，不能靠整體比對。**

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

> 三段範例**活在 demo 的測試 target 裡**（`Tests/SwiftTestingTechniqueTests.swift`），每次 `xcodebuild test` 都會重新編譯並執行。
>
> 先前這裡寫的是「在 demo 的測試 target 內編譯驗證過（Swift 6.3.1 / Xcode 26.4.1，2026-08）」——**那是戳記不是檢查**：程式碼當時貼進去編過就移除了，工具鏈換代之後沒有任何東西會發現它失效，而 `TODO.md` 確實記著它們在 Xcode 27 下未重跑。**戳記會過期而不出聲，測試不會。** 下面的程式碼與那個檔案同形；若有出入，以那個檔案為準。

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
