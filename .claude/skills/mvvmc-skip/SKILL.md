---
name: mvvmc-skip
description: |
  MVVMC 專案透過 Skip.tools 轉 Android 的跨平台規範。涉及將既有 MVVMC iOS App 移植到 Android、撰寫需同時在 iOS/Android 運作的 M/VM/V/C 程式碼、處理 Skip 轉譯或 Kotlin 編譯錯誤、除錯 Compose 不重繪問題時觸發。確保 iOS 架構零改動，僅以 `#if !SKIP` 與 Skip 友善語法達成跨平台。
  僅適用於有 Android 目標的專案；純 iOS 的 MVVMC 專案請用 `mvvmc-*` 系列，不要用本 skill。
disable-model-invocation: true
---

> **手動觸發**：本 skill 設為 `disable-model-invocation: true`，只有使用者輸入 `/mvvmc-skip` 才會載入。
> 理由：多數 MVVMC 專案是純 iOS，不該為了少數跨平台專案讓這份規範常駐。決定要跨平台時再點名即可 ——
> 載入後整個 session 都有效。

> 🧊 **狀態：凍結的筆記，不是規範的一部分（2026-09-11 起；驗證狀態 2026-09-17 更正）。**
>
> **已被 Android 建置實測過，但驗證有邊界、而且會過期。** 證據是 `MVVMC-Skip`：fork 自 MVVMC `v1.1.0`（`db9013d`），Skip Lite，skip 1.9.3 + skip-ui 1.0.0，Migration Log M0–M21 全數 commit，最後一筆 2026-06-26。Settings 於 Pixel 9 模擬器渲染（M13）、PostList 完整資料渲染（M16）、Router 端到端（M20–M21）、`skip app launch --ios` 與 baseline 一致。本檔眉角表的編號 #2–#10 就是沿用該 repo 的 Migration Log。
>
> **2026-09-11 原本寫的是「本檔從未被任何 Android 建置驗證過」，那是錯的**，2026-09-17 更正。成因值得留著：那句是在本 repo 裡往內看寫出來的——「這個 repo 沒有 Skip target」為真，於是推論成「沒有任何專案驗證過」，而沒有往旁邊看 fork。`SPEC-COVERAGE.md` 那句 `🚫 — the demo has no Skip target` 到今天仍然成立，它講的是 demo，不是全世界。
>
> **驗證涵蓋不到的面向**（在 `MVVMC-Skip` 全數 0 命中，不要當成「試過沒問題」）：持久層（SwiftData / SkipSQL）、AdMob、Swift Charts、PhotosUI／影像、`Localizable.xcstrings` 多語系。推播通知是整個 `SceneDelegate` 被 `#if !SKIP` 排除，**Android 側連進入點都沒有**。
>
> **所以凍結仍然成立，只是理由換了**：不是「沒驗過」，而是**驗證會過期，而沒有任何機制會發現**。baseline 是 `v1.1.0`，本 repo 的 `Sources/` 此後又走了 9 個 commit。
>
> 由此而來的三條紀律（與驗證與否無關，全部保留）：
>
> - **不得從本檔推導或修改任何 `mvvmc-*` 的 iOS 規則。** 本檔整份都是對那些規則的豁免，方向是單向的
> - **規範每一輪的一致性檢查不涵蓋本檔。** 其他 skill 改了不需要回頭同步這裡——硬同步只會製造看起來很像證據的東西
> - ⚠️ **對 Skip 專案跑 `mvvmc-review` 之前，先確認它的〈開單前的排除清單〉裡還有 Skip 那一列。** `Experiments/README.md` 記過後果：**五個假發現，照著修會靜默弄壞 Android 的畫面渲染。** 該列 2026-09-17 已補上；在那之前 `mvvmc-review` 的 `Skip` / `Android` 是 0 命中。**豁免範圍不只 `#else` 分支**——三層內部有無條件的語法偏離（巢狀 enum 完整限定、`Result` 提為具型別 let、巢狀 case 解構拆成兩層 switch），那些不在任何 `#if` 裡。另外，單一 layer skill 的範圍註記只有 `mvvmc-hostcontroller` 有，`mvvmc-navigation` 那行只是 `Info.plist` 指路、不是豁免，`view` / `viewmodel` / `model` 三份沒有——**直接讀單一 skill 的 agent 不受保護，排除清單是唯一實際擋得住的地方**
>
> **解除凍結的條件**：在**當前**的 MVVMC baseline 上重跑一次 Skip 建置成功（`v1.1.0` 那次不算數了）。屆時第一件事是**逐條對照本檔重跑**，把「觀測值」換成「在 X 專案、Skip 版本 Y 下實測」，而不是直接信任它。

> ⚠️ **本檔的「症狀」全部是觀測值，不是規則。** 診斷手冊跟規範不同——規範可以被**違反**（拿碼比對就知道），診斷手冊只會**過期**，而且沒有任何機制會發現。
>
> **觀測環境**：Skip / Xcode / Swift 版本與觀測日期請在每次驗證後更新於此。**若某條症狀再也重現不了，回報而不要直接刪**——「不再重現」有兩種原因（上游修好了／你的情境變了），刪掉是不可逆的。修法通常仍成立，因為它們針對的是 Kotlin 的語言限制，不是 Skip 的 bug。

# MVVMC × Skip Skill

你是一位資深 iOS 工程師，同時熟悉 Kotlin / Jetpack Compose 的執行模型。

iOS 側的 M/VM/V/C 規範請參考 `mvvmc-model`、`mvvmc-viewmodel`、`mvvmc-view`、`mvvmc-hostcontroller`、`mvvmc-navigation` 這幾個 skill —— **本 skill 只描述 Skip 的增量規則，不重複 iOS 架構規範**。

- 新專案從零架設：`references/project-setup.md`
- Android Router 與 HostController `#else` 完整範本：`references/android-router.md`

---

## 核心前提

**iOS 架構零改動——精確的意思是三分，不是字面上的零行。** 實測 `MVVMC-Skip` 對 baseline `db9013d` 的差異：

| 面向 | 改動 |
|---|---|
| 分層邊界、`doAction` 單一進入點的形狀、`Router` enum、HostController 與 AppRouter 的職責劃分 | **0** |
| M / VM / V 三層**內部**的 Swift 語法 | 有改動，全部落在下方眉角表編號內（M 4 行、VM 66 行、V 105 行） |
| 鷹架層（`App/AppDelegate.swift`、`App/SceneDelegate.swift`） | +12 行 access modifier |

跨平台是「加上 `#if !SKIP` 分支與 Skip 友善語法」達成的，不是「重構成兩邊都能用的樣子」。**三層內部有改動不等於架構有改動**——但也不要反過來宣稱三層一行都沒動，那是假的，而且會讓審查者把看到的偏離當成違規。

| 允許改動 | 禁止改動 |
|---|---|
| ✅ Swift 6 concurrency 修正（如 `nonisolated(unsafe)`） | ❌ M/VM/V/C 分層邊界 |
| ✅ Skip 轉譯友善的語法調整（見下方眉角表） | ❌ `doAction` 單一進入點的形狀 |
| ✅ 用 `#if !SKIP` 把 iOS-only 檔案藏起來 | ❌ HostController + AppRouter 的職責劃分 |
| ✅ 為 Android 補 `#else` 分支 | ❌ 為了遷就 Skip 而改變 iOS 行為 |

驗收標準：**iOS 行為與遷移前完全相同**。

---

## 三道關卡

錯誤會照這個順序出現，而且**必須照順序通過**。判斷自己卡在第幾關，才知道該查哪一組規則。

| 關卡 | 問題 | 錯誤出現在哪 | 對應眉角 |
|---|---|---|---|
| **1. 轉譯** | Swift 語法能不能變成 Kotlin 語法 | `xcodebuild` 的 `Skip <Module>` build task | #3 #4 #5 + 型別宣告類 |
| **2. Kotlin 編譯** | 轉出來的 Kotlin 能不能通過 Android 工具鏈 | `gradle :app:assembleDebug` 的 `compileDebugKotlin` | #6 #7 #8 |
| **3. 執行期** | 編譯過了、跑起來了，行為對不對 | App 沒掛但畫面不動 / 出現 `JobCancellationException` | #9 #10 + 強引用規則 |

💡 **第 1 關是 fail-fast 的**：Skip 一次只報一個錯就停，照檔案路徑字母序推進。所以不會看到滿江紅，而是修一個、重建、下一個。改完一輪要重跑才知道下一個在哪，這是正常節奏，不是卡住。

⚠️ **通過第 1 關不代表能編譯，通過第 2 關不代表行為正確。** 三關各自獨立，最容易低估的是第 3 關 —— 它不會給你編譯錯誤。

---

## 眉角對照表

編號沿用 MVVMC-Skip 的 Migration Log，方便回查來源。

### 第 1 關：轉譯

#### #2 — 整檔 `#if !SKIP`

UIKit-only 的檔案整份包起來，讓 Skip 看不到。

**適用**：`*HostController.swift`（iOS 分支）、`AppDelegate.swift`、`SceneDelegate.swift`、`AppRouter.swift`、`Deeplink.swift`

**典型錯誤**（不包會看到）：
```
In Kotlin, delegating calls to 'self' or 'super' constructors can not use
local variables other than the parameters passed to this constructor
```
這是 HostController 的 `super.init(rootView:)` 引用了區域變數 `viewModel` —— Kotlin 不允許。不要改寫 HostController 去迎合，直接整檔包起來。

#### #3 — `case ... where` 拆成 case 內的 `if`

```
error: Kotlin does not support where conditions in case and catch matches.
Consider using an if statement within the case or catch body
```

```swift
// ❌ 轉譯失敗
switch viewModel.state.api.fetchPosts {
case .loading where viewModel.state.posts.isEmpty:
  ProgressView()
}

// ✅
switch viewModel.state.api.fetchPosts {
case .loading:
  if viewModel.state.posts.isEmpty {
    ProgressView()
  } else {
    list
  }
}
```

#### #4 — 巢狀 leading-dot enum 提取成有型別標註的 `let`

```
error: Skip is unable to determine the owning type for member 'success'
```

Skip 的型別推論比 Swift 弱，看不穿多層 leading-dot。

```swift
// ❌
await doAction(.apiResponse(.fetchPosts(.success(dtos))))

// ✅
let result: Result<[PostDTO], APIError> = .success(dtos)
await doAction(.apiResponse(.fetchPosts(result)))
```

失敗分支同理：
```swift
let result: Result<[PostDTO], APIError> = .failure(.message(error.localizedDescription))
await doAction(.apiResponse(.fetchPosts(result)))
```

💡 這是 MVVMC 的 `apiResponse` 形狀必然會踩到的 —— 每個有 API 的 VM 都要改。

#### #5 — 巢狀 case 解構拆成外層 match + 內層 `switch`

```swift
// ❌
case let .fetchPostsDidFinish(.success(dtos)):
  state.posts = dtos.compactMap { $0.toDomain() }
case let .fetchPostsDidFinish(.failure(error)):
  state.api.fetchPosts = .error(error.message)

// ✅
case let .fetchPostsDidFinish(result):
  switch result {
  case let .success(dtos):
    state.posts = dtos.compactMap { $0.toDomain() }
  case let .failure(error):
    state.api.fetchPosts = .error(error.message)
  }
```

#### 型別宣告類（無編號）

| 症狀 | 修法 |
|---|---|
| `Identifiable` 的 `var id: Self { self }` 轉譯失敗 | 寫具體型別：`var id: AppRoute { self }` |
| enum case 參數叫 `id`，與 `Identifiable` 合成的 `id` 衝突 | 改名：`case postDetail(postId: Int)` |
| 全域 `var`（如 associated object key）被 Swift 6 拒絕 | `nonisolated(unsafe) private var xxxKey: UInt8 = 0` |

---

### 第 2 關：Kotlin 編譯

#### #6 — 巢狀 enum 在呼叫端要寫完整限定

```
e: Unresolved reference 'ViewAction'
```

Skip 把 `.view(.close)` 轉成 Kotlin 的 `ViewAction.close`，但 `ViewAction` 是巢狀型別，裸名稱在 Kotlin 解析不到。

```swift
// ❌
await viewModel.doAction(.view(.isFirstAppear))

// ✅
await viewModel.doAction(.view(PostListViewModel.ViewAction.isFirstAppear))
```

⚠️ **每一個 `doAction(.view(...))` 呼叫點都要改**，這是移植 View 時最大宗的機械性工作。`.router(...)` / `.apiRequest(...)` 同理。

#### #7 — leading-dot `.init(...)` 改寫成明確型別

Skip 推不出型別時會**靜默**退化成 Kotlin 的 `Any(...)`，然後才在編譯期炸掉 —— 錯誤訊息不會指回這行。

```swift
// ❌ 轉成 Kotlin 的 Any(id = it)
(1...5).map { .init(id: $0) }

// ✅
(1...5).map { User(id: $0) }
```

#### #8 — SkipUI 缺的 API 用 `#if !SKIP` / `#else` 就地補

```
e: Unresolved reference 'ContentUnavailableView'
```

iOS 保留原本的豐富 API，Android 用 SkipUI 支援的基本元件湊出同樣的視覺意圖。

```swift
#if !SKIP
ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
#else
VStack(spacing: 8) {
  Image(systemName: "exclamationmark.triangle")
    .font(.largeTitle)
  Text(message)
}
.foregroundStyle(.secondary)
#endif
```

純修飾器缺失時，只包修飾器即可（Android 直接不套用）：
```swift
#if !SKIP
.contentShape(Rectangle())   // SkipUI 尚未實作
#endif
.onTapGesture { send(.rowDidTap) }
```

💡 與 #2 的差別：#2 是整檔隱形，#8 是**就地補一小段**，跨平台的主體保留。

---

### 第 3 關：執行期

這一關沒有編譯錯誤，只有「行為不對」。最難查，先看這三條。

#### #9 — Android 的 C 層：`HostController` 的 `#else` 分支必須用 `@State` 持有 VM

**症狀**：畫面渲染出來了，但 state 改了畫面不動。連按鈕直接同步改 state 都沒反應。

**原因**：SkipModel 的 `Observed<Value>` 有個 `trackState()` 閘門，只有當持有者本身被 Compose 追蹤時才會安裝 `MutableState` 背板。在那之前所有讀寫都繞過 Compose。而 Compose 只認得 `@State` / `@StateObject` / `.environment(_:)` 這幾種持有方式。

MVVMC 的 View 用 `let viewModel:` 由外部傳入（iOS 規範如此，**不要改**），所以必須由 C 層用 `@State` 持有。

```swift
#else
@MainActor
struct PostListHostController: View {
  @State private var viewModel = PostListViewModel()   // ← 關鍵

  var body: some View {
    PostListView(viewModel: viewModel)
      .onAppear { bindRouter() }
  }
}
#endif
```

VM 需要參數時，用 `init` 種進 `@State`：
```swift
@State private var viewModel: UserDetailViewModel

init(userId: Int) {
  _viewModel = State(initialValue: UserDetailViewModel(userId: userId))
}
```

💡 這正是 Android 版的 C 層 —— 與 iOS 的 `UIHostingController` 對稱：都持有 VM、都訂閱 `onRoute`、都把導航交給 `AppRouter.shared`。完整範本見 `references/android-router.md`。

#### #10 — `.task` 一律拆成 iOS `.task` / Android `.onAppear + Task`

**症狀**：畫面顯示錯誤訊息，內容是
```
skip.lib.ErrorException: kotlinx.coroutines.JobCancellationException: Job was cancelled
```
API 才發出去就被取消，`do/catch` 把取消當成一般錯誤，於是 dispatch 了 `.failure`。

> ⚠️ **這個改法的代價，輪詢頁必須知道**：`.onAppear { Task { … } }` 是**非結構化**的——沒有人持有那個 Task，**沒有任何取消路徑**。於是 `mvvmc-viewmodel/references/patterns.md`〈週期性更新〉整套設計的基礎（「`.task` 綁 View 生命週期，離開畫面時結構化地取消整條鏈」）在 Android 側**不成立**，`while !Task.isCancelled` 永遠為 false。
>
> 症狀：使用者離開頁面，輪詢繼續打 API 直到 App 被系統殺掉。**iOS 那側的已知限制是「特定情況不取消」，Android 這側嚴重一級——是「沒有取消機制」。** 有輪詢的頁面移植到 Android 時，取消必須自己接（VM 持有 `Task` + `onDisappear` 明確 cancel + `deinit` 兜底）。

**原因**：Compose 在 NavigationStack 推進過程中可能把 View 移出再放回 composition，綁在 `.task` 上的 coroutine 就被腰斬。

```swift
#if !SKIP
.task { await viewModel.doAction(.view(PostListViewModel.ViewAction.isFirstAppear)) }
#else
.onAppear {
  Task { await viewModel.doAction(.view(PostListViewModel.ViewAction.isFirstAppear)) }
}
#endif
```

iOS 保留結構化並行（離開畫面自動取消）；Android 用非結構化 Task 撐過轉場。

⚠️ **一律套用，不要挑著做。** 哪個 View 會觸發這個重繪循環取決於 NavigationStack 的內部細節，不是 View 作者能預判的。曾經以為只有 `.navigationBarTitleDisplayMode(.inline)` 會觸發，後來證明不可靠。

#### 強引用規則 — `#else` 分支不要用 `[weak]`

**症狀**：closure 有執行（print 得出來），但裡面的 `viewModel?.doAction(...)` 靜默沒作用。

**原因**：Kotlin 用 GC 不是 ARC。`[weak viewModel]` 會變成 `WeakReference`，在巢狀 closure 的捕獲鏈中提早被清掉 —— 即使物件還被 `@State` 持有著。而 Kotlin 本來就沒有循環參照問題，`[weak]` 在這裡有害無益。

```swift
// iOS 分支：保留 [weak self]，這是必要的
viewModel.onRoute = { [weak self] router in
  self?.handleRouter(router)
}

// #else 分支：一律強引用
viewModel.onRoute = { router in
  switch router { ... }
}
```

---

## 移植一個功能的步驟

假設某個 feature 目前被 `#if !SKIP` 擋在 Android 之外，要讓它跨平台：

1. **拆掉 View 的 `#if !SKIP`**，讓 Skip 看得到。
2. **過第 1 關**：重建，照 fail-fast 順序修轉譯錯誤（#3 #4 #5）。一次一個，改完重建。
3. **過第 2 關**：
   - 把所有 `doAction(.view(...))` 加上完整限定（#6）
   - SkipUI 缺的 API 就地補 `#else`（#8）
   - 有 `.init(...)` 推不出型別的改寫成明確型別（#7）
4. **`.task` 拆成兩個分支**（#10）。
5. **寫 C 層的 `#else` 分支**：`@State` 持有 VM（#9）+ `.onAppear { bindRouter() }`，把 `onRoute` 的每個 case 翻譯成 `AppRouter.shared` 的呼叫。範本見 `references/android-router.md`。
6. **接上 root view**：在 `navigationDestination` 或 `.sheet` 加上這個功能的目的地。
7. **兩邊都驗證**：
   ```
   skip app launch --ios --plain
   skip app launch --android --plain
   ```
   iOS 必須與移植前**完全相同** —— 這是驗收標準，不是順帶檢查。

💡 VM / Model 層通常不用動，除了 #4 #5（有 API 的 VM）和 iOS-only API 的就地包裝（如 `UIApplication.shared.open`、`UNUserNotificationCenter`）。

---

## iOS-only API 在 VM 內的處理

VM 用到 iOS 專屬 API 時，**不要把整個 VM 包掉**，也不要刪掉對應的 Action case —— 那會讓兩邊的架構長得不一樣。正確做法是：enum case 保留，只把 case 的**內容**包起來。

```swift
#if !SKIP
import UIKit
import UserNotifications
#endif

// doAction 內
case let .triggerDeeplink(url):
  #if !SKIP
  UIApplication.shared.open(url)
  #else
  _ = url   // Android 尚未支援，避免未使用警告
  #endif
```

這樣 View 的呼叫點在兩邊都能編譯，Action 列表也保持一致 —— 只是 Android 的副作用是 no-op。

---

## 常見診斷路徑

| 現象 | 大概在第幾關 | 先查 |
|---|---|---|
| `xcodebuild` 在 `Skip <Module>` task 失敗 | 1 | #3 #4 #5、型別宣告類 |
| `Unresolved reference 'XxxAction'` | 2 | #6 |
| `Unresolved reference '<SwiftUI 元件>'` | 2 | #8（SkipUI 未實作） |
| Kotlin 抱怨參數不存在、型別是 `Any` | 2 | #7 |
| 畫面空白、state 改了不重繪 | 3 | #9 |
| `JobCancellationException` | 3 | #10 |
| closure 有跑但 VM 呼叫沒效果 | 3 | 強引用規則 |
| Android 沒有對應模組 / gradle 找不到 | — | `references/project-setup.md` |

---

## 任務模式

### 模式 A：移植既有 feature 到 Android

依「移植一個功能的步驟」逐項執行，每過一關回報一次。**不要跳過 iOS 驗證** —— 每次改完 View/VM 都要確認 iOS 行為未變。

### 模式 B：審查跨平台程式碼

```
### 審查報告

✅ 符合規範：
- ...

❌ 違規項目：
| 位置 | 問題 | 關卡 | 對應眉角 | 建議修正 |
|------|------|------|----------|----------|

⚠️ 潛在執行期風險：
- [第 3 關的問題不會編譯失敗，需特別標示]
```

重點檢查：`.task` 是否已拆分、`doAction(.view(...))` 是否已限定、`#else` 分支是否誤用 `[weak]`、C 層 `#else` 是否用 `@State` 持有 VM。

### 模式 C：新專案導入 Skip

依 `references/project-setup.md` 的順序執行。⚠️ **插件綁定放到最後** —— `skipstone` 是 eager 的，一旦綁定，每次 iOS build 都會觸發轉譯，在架構還沒準備好時會擋住整個 build。
