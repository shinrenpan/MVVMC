---
name: swift-concurrency
description: |
  Swift Concurrency 使用規範。涉及 async/await、Task、Task.detached、@concurrent、nonisolated、actor、MainActor、Sendable 時觸發。
  **傳 closure 給 ObjC framework API 時也必須觸發**——任何**你控制不了呼叫佇列**的 callback——completion handler、delegate 回呼、observer block、`(to:withHandler:)` 形式的舊 API。CoreMotion / CoreBluetooth / AVFoundation / CoreLocation / NotificationCenter 是常見來源，**但不限於這些**。那類 closure 會隱式繼承 MainActor 隔離，編譯期零警告、模擬器全過，只有實機回呼的那一刻崩。寫這種 callback 時通常不會意識到自己在處理並發問題，所以要靠這條主動攔下來。
  確保正確判斷離開主 actor 的工具，維持 Structured Concurrency 優勢。
---

# Swift Concurrency Skill

你是一位資深 iOS 工程師，專精於 Swift Concurrency 與執行緒安全。

> 基準 **Swift 6.4**（Xcode 27.0 RC 內附，27A266a）。並發模型自 **6.2「Approachable Concurrency」** 起有重大轉向，本 skill 以此為基準——先讀下方〈Swift 6.2+ 心智模型〉再看判斷樹。
>
> ⚠️ **「toolchain 有了」不等於「你能用」——擋你的是 deployment target。** 6.4 的新 API 多半帶 `@available(anyAppleOS 27.0, *)`，在 iOS 17+ 專案裡直接呼叫編不過（實例見〈Task 取消〉的 `withTaskCancellationShield`）。
>
> 版本聲明最後複查：**2026-09**（本機 Swift 6.4 / Xcode 27.0 RC / macOS 26.6.2 / iOS SDK 27.0）。此段落有保鮮期，而**複查要分開查兩個變數**：
>
> 1. `swift --version` → 決定**語法與編譯器行為**（`@concurrent` 怎麼拼、哪些警告存在）
> 2. 專案 deployment target vs 該 API 的 `@available` → 決定**能不能呼叫**
>
> 早前這裡只寫了第 1 條（「若已進到 6.4 就把 `withTaskCancellationShield` 改為可用」）。2026-09 真的進到 6.4 時照著做，會把一個 iOS 17 專案編不過的 API 標成可用——**觸發器只有一個變數，規則卻有兩個**。

DispatchQueue 遷移對照請見：`references/migration.md`

---

## Swift 6.2+ 心智模型（先讀這段）

6.2「Approachable Concurrency」翻轉了預設，很多舊觀念要更新：

- **模組預設 `@MainActor`**：`Package.swift` 設 `.defaultIsolation(MainActor.self)`（Xcode：`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`、`SWIFT_APPROACHABLE_CONCURRENCY = YES`），整個模組預設主 actor 隔離，不必到處手動標 `@MainActor`。**Xcode 26／27 新專案預設就開這兩項。**
  > ⚠️ **但 MVVMC 的 ViewModel 仍然明標**——這是編譯器行為與規範要求不一致的一處。裁定在 `mvvmc-viewmodel`〈強制宣告〉（本檔〈專案脈絡〉末尾有引用），**只讀這一行會得到相反的結論**。
- **`nonisolated async func` 預設跑在呼叫端 actor**（`nonisolated(nonsending)`，SE-0461）——**不再自動跳到背景**。所以「標了 `nonisolated` 的 async 就會脫離主 actor」這個舊觀念已不成立。
  > ⚠️ **這條依賴設定**，不是 6.2 toolchain 就自動生效：要開 `SWIFT_APPROACHABLE_CONCURRENCY: YES`（SPM 為 `.enableUpcomingFeature("NonisolatedNonsendingByDefault")`）。實測（`Experiments/ConcurrencyProbe/`，Swift 6.4 複驗）：同一段 `nonisolated async func` 從 `@MainActor` 呼叫，**沒開**這個 flag 時離開主緒、**開了**才留在呼叫端。判斷任何一段 `nonisolated async` 的行為前，先確認這個開關——這正是下方〈Fast Path〉存在的理由。
  >
  > **重開條件（當場驗得出來，不綁版本號）**：`Experiments/ConcurrencyProbe/` 在**開／關該 flag 兩種設定下不再產生不同結果**時，本條作廢。綁版本號是錯的觸發器——這條失效的方式不是 toolchain 上升，是那個 flag 從 opt-in 畢業成預設。**probe 跑不出差異的那天，它自己就會說。**
- **要並行 / 離開 actor 得明講**：用 `Task { @concurrent in ... }` 讓 Task 從主 actor 外起跑（見〈離開主 actor〉）。
- **6.3 Region-based isolation 正式可用**：編譯器能證明更多情況的資料安全，`Sendable` 假陽性大減。

## 專案脈絡

本專案所有 ViewModel **明標** `@MainActor`。（模組層級 `.defaultIsolation(MainActor.self)` **不是等價替代**——即使開了那個設定仍然明標，裁定與理由見 `mvvmc-viewmodel`〈強制宣告〉。）`doAction` 內的 `Task { }` **繼承當前 actor（即 MainActor），不會脫離**。要真正離開主 actor：async 工作用 `Task { @concurrent in }`，非結構化才用 `Task.detached`；純同步運算用 `nonisolated func`。

## 先確認專案設定（Fast Path）

給並發建議前，先讀 `Package.swift` / `.pbxproj` 確認四件事，否則同一段 code 的正確解會不同：

1. **Language mode**：`swiftLanguageModes` / Swift Language Version
2. **Strict concurrency**：`SWIFT_STRICT_CONCURRENCY`
3. **Default isolation**：`.defaultIsolation(MainActor.self)` / `SWIFT_DEFAULT_ACTOR_ISOLATION`（決定「未標註的型別預設在不在主 actor」）
4. **Approachable concurrency / upcoming features**：`SWIFT_APPROACHABLE_CONCURRENCY`、`.enableUpcomingFeature(...)`

> MVVMC demo 的設定可當參考（`project.yml`）：Swift 6 language mode + `SWIFT_STRICT_CONCURRENCY: complete` + `SWIFT_APPROACHABLE_CONCURRENCY: YES`，零警告通過。**刻意沒開** `SWIFT_DEFAULT_ACTOR_ISOLATION`，所以本 skill 的建議預設「每個型別自己標註隔離」，不假設模組預設。

> **開了之後 ViewModel 還要不要逐一標 `@MainActor`——這條規則歸 `mvvmc-viewmodel`〈強制宣告〉，本 skill 不重述、也不表態。** 那裡有已定案的答案（仍然明標）、理由、以及審查已開啟該設定的專案時該怎麼做。
>
> 早前這裡曾寫成「未定案的議題」，與 `mvvmc-viewmodel` 的「定案」直接衝突，開了那個設定的專案於是可以合理地挑一份遵守。**兩份 skill 對同一問題各自表態就是這個下場**——見 `CLAUDE.md`〈Maintaining the Spec〉。

## Guardrails

- ❌ 別把 `@MainActor` 當萬用解——要能說出「這段確實是 UI-bound」的理由
- ✅ 優先結構化並發（`async let` / TaskGroup），少用非結構化 `Task {}` / `Task.detached`
- ⚠️ `@unchecked Sendable`、`nonisolated(unsafe)`、`@preconcurrency` 是逃生口，**分兩種，註解要求不同**：
  - **暫時性**（等某個 API 標好 `Sendable`、等遷移完成）→ 必附「**安全不變式 + 移除計畫**」
  - **永久性**（語言層面沒有替代方案）→ 必附「**安全不變式 + 具體缺了哪個語言機制**」。
    > ⚠️ 「沒有替代方案」**不得只是宣稱**——那只能由作者自己認證，任何人沒找夠久都寫得出這句話。註解必須**指名一個具體的機制缺口**（哪個語言特性沒有、哪個 proposal 沒過）。
    > **而且「永久性」是本 skill 維護的封閉清單，新增一個要改這份文件**——那道外部編輯就是破解自我認證的機制。
    >
    > **目前清單（1 項）**：`AppRouter` 的 `appTransitionStyleKey`——associated object 的 key 需要一個**穩定的記憶體位址**，而 Swift 沒有「編譯期常數位址」這個概念；`let` 不保證位址穩定、`static let` 在 Swift 6 下仍是全域可變狀態。見 `mvvmc-navigation` 模板
  > 不分這兩種的後果：規範自己的可貼模板寫得出不變式、**寫不出移除計畫**（沒有東西可以移除到），於是它對規範自己的規則只做到一半，而審查端會為此開單
- ⚠️ `MainActor.assumeIsolated`——**強度與適用範圍統一見〈傳給 ObjC API 的 closure〉的連帶規則**（那裡是「不要用」，不是「少用」）。本條不另立標準

---

## 核心判斷：離開主 actor 的三種工具

```
要把工作移出主 actor 嗎？
├── 純 CPU 運算、不碰 actor state
│   └── nonisolated 同步 func         ← 呼叫端決定在哪跑，零 Task 開銷
├── 起一個 Task、且它的同步前綴不需要主 actor
│   └── Task { @concurrent in ... }   ← 6.2+ 標準做法，結構化、可取消
└── 需要「非結構化 + 脫離 priority / task-local」才用
    └── Task.detached                 ← 最後手段，罕見
```

- ❌ 純運算包 `Task { @concurrent in }` 或 `Task.detached`——用 `nonisolated` 同步 func 就好
- ⚠️ 一般 `Task {}`（未標 `@concurrent`）在 6.2+ 會**跟著呼叫端 actor 跑**（主 actor 起 → 主 actor 跑），不會自己脫離

---

## 離開主 actor：`Task { @concurrent in }` 與同步前綴規則（6.2+）

要讓一個 Task 真正跑在主 actor 外（阻塞 I/O、重運算），用 **`Task { @concurrent in }`**——把 `@concurrent` 當 closure 的 isolation 前綴。它是**結構化**的，享有取消與 priority 繼承，優先於 `Task.detached`。

**同步前綴規則**：看 `Task` 第一個 `await` 之前的**同步前綴**——

- 前綴要動主 actor state / UI → 用預設 `Task {}`（保持繼承主 actor）
- 前綴與 UI 無關、第一件事就是跳走 → 用 `Task { @concurrent in }`（從主 actor 外起跑，回頭再 `await MainActor.run { }` 更新 state）

```swift
// ✅ 前綴要動主 actor state → 保持繼承
Task {
    state.isLoading = true      // 需要 @MainActor
    await doAction(.apiRequest(.load))
}

// ✅ 前綴與 UI 無關、直接跳去重運算 → @concurrent 起跑
Task { @concurrent in
    let images = data.compactMap { UIImage(data: $0) }   // 重解碼，不佔主 actor
    await MainActor.run { state.thumbnails = images }     // 回主 actor 更新
}

// ❌ 空的同步前綴、第一件事就 await 跳走 → 不該用預設 Task
Task {
    await heavyOffMainActorWork()   // 白繞主 actor 一圈
}
```

- `@concurrent` 也可標在 async **函式宣告**上（SE-0461）——型別成員與頂層函式都可以：

```swift
@MainActor
final class Loader {
    @concurrent func decode(_ data: Data) async -> Image? { ... }   // ✅
}

// ❌ 不要與 nonisolated 併寫：`nonisolated @concurrent func` 連 parse 都過不了
//    （@concurrent 本身已隱含 nonisolated）
```

> 實測 Swift 6.4（2026-09）：`@concurrent func` ✅、`Task { @concurrent in }` ✅、`nonisolated @concurrent func` ❌ `expected declaration`。

日常在 `doAction` 內仍以 closure 形式最直觀；需要讓一個 async 方法「總是離開呼叫端 actor」時才用宣告形式
- 純同步、不 async 的運算 → 用下方 `nonisolated func`，不需要 `@concurrent`

---

## nonisolated（純同步運算）

不需要存取 actor state 的**純同步**運算，用 `nonisolated func` 取代 `Task.detached`，由呼叫端決定在哪跑：

```swift
@Observable
@MainActor
final class FeatureViewModel {

    // ✅ 純運算標注 nonisolated，不占用 MainActor
    nonisolated func toDomains(_ dtos: [DTO]) -> [Domain] {
        dtos.compactMap { $0.toDomain() }
    }

    nonisolated func sorted(_ items: [Item], by sort: SortType) -> [Item] {
        items.sorted { ... }
    }

    // 呼叫端在 @MainActor context，直接同步使用，不需要任何 Task
    private func handleResponse(_ dtos: [DTO]) async {
        state.items = sorted(toDomains(dtos), by: state.currentSort)
    }
}
```

---

## Task.detached

**最後手段**（在 6.2+ 更罕見，多數離開主 actor 的需求改用 `@concurrent`）。只在同時滿足時才用：
1. 需要**非結構化**（脫離父 Task 的取消樹 / task-local 值）
2. 明確不想繼承父 Task 的 priority

```swift
// @MainActor property 必須先在 actor context 取出，再傳入 detached task
let items = self.items
// .background 只是示範用的「某個不繼承父 Task 的 priority」；實際 priority 依情境選，不是規定值
Task.detached(priority: .background) { [weak self] in
    guard let self else { return }
    for item in items {
        if Task.isCancelled { break }
        let updated = await self.downloadImage(for: item)
        await self.updateItem(updated)
    }
}
```

**禁止情境：**

```swift
// ❌ 純運算不需要 detached（也不需要 @concurrent）
let result = await Task.detached(priority: .userInitiated) {
    items.sorted { ... }     // 排序
    dtos.compactMap { ... }  // mapping
    UIImage(data: data)      // 解碼
}.value

// ❌ .task {} 內禁止再包 Task.detached（雙重脫離）
.task(id: item.id) {
    self.image = await Task.detached { UIImage(data: data) }.value
}
```

---

## Task 取消（cancellation）

Swift 的取消是**協作式**的：取消只是設旗標，程式要主動檢查才會停。

**兩種 Task 的關鍵差異：**

- **`.task {}`（SwiftUI modifier）**：綁 View 生命週期，**離開畫面自動取消**——「run once」pattern 就靠它。
- **`Task {}`（非結構化，如 doAction 內）**：**不會自動取消**，要自己存 handle 手動 `cancel()`。

**檢查取消：**
- `guard !Task.isCancelled else { return }` — 自己處理、不丟錯
- `try Task.checkCancellation()` — 丟 `CancellationError`、fail fast
- `Task.sleep` 被取消會自動丟錯

**典型場景：搜尋即打即查（debounce + 取消前一次）**——兩種寫法：

```swift
// ✅ 首選（View 驅動）：.task(id:) 綁 state，id 一變自動取消前一個
.task(id: viewModel.state.searchQuery) {
    try? await Task.sleep(for: .milliseconds(300))   // 使用者又打字 → 這裡被取消
    await viewModel.doAction(.apiRequest(.search))
}

// ✅ doAction 驅動（無法綁 view modifier 時）：手動存 handle、cancel 前一次
@ObservationIgnored private var searchTask: Task<Void, Never>?

case .searchTextChanged(let text):
    searchTask?.cancel()                                 // 取消上一次
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))   // debounce
        if Task.isCancelled { return }
        await doAction(.apiRequest(.search(text)))
    }
```

- **priority 只是提示**：結構化 Task 繼承父 priority，`Task.detached` 不繼承；系統會為防優先反轉自動提權——別把 priority 當保證。

- **6.3+**：`Task { try await ... }` 若**未處理**丟出的錯誤，編譯器會**警告**——要嘛在 Task 內處理，要嘛存下 Task 之後檢查。
- **`withTaskCancellationShield { }`——已出貨，但 iOS 17+ 專案還用不到。** 關鍵清理不想被取消打斷時它是正解，Swift 6.4 / iOS SDK 27 已隨附，但簽名上標著 `@available(anyAppleOS 27.0, *)`：

  ```swift
  // iPhoneOS27.0.sdk 實際簽名
  @available(anyAppleOS 27.0, *)
  public func withTaskCancellationShield<Value, Failure>(...) async throws(Failure) -> Value
  ```

  MVVMC 基準 iOS 17+，直接呼叫得到 `error: 'withTaskCancellationShield(operation:)' is only available in iOS 27.0 or newer`。包 `if #available(iOS 27.0, *)` 編得過，但清理路徑一旦分岔就得**同時維護 shield 版與手動版兩條**，比只留手動版更糟。

  **所以在 deployment target 進到 iOS 27 之前，維持手動寫法**：在清理前檢查完取消，清理本身不再檢查。這條的理由是 availability，**不是「還沒 release」**——toolchain 早就有了。

---

## 同時執行多個任務

```
需要同時跑多個任務嗎？
├── 數量固定 → async let
├── 數量動態（loop）→ TaskGroup
└── 不需要等結果 → 多個 Task {}（注意錯誤處理）
```

```swift
// async let：同時發出，await 才等結果
async let user = fetchUser()
async let posts = fetchPosts()
let (u, p) = await (user, posts)

// TaskGroup：動態數量，離開 } 自動等待
await withTaskGroup(of: UIImage?.self) { group in
    for item in items { group.addTask { await self.downloadImage(item) } }
    return await group.reduce(into: []) { $0.append($1) }
}
```

---

## Sendable

`Sendable` = 可安全跨並發邊界（actor / Task）傳遞的型別。Swift 6 靠它在**編譯期**擋資料競爭。

- **值型別自動符合**：所有成員都 `Sendable` 的 `struct` / `enum` 自動 `Sendable`（本專案 State / Domain / DTO 皆是）。
- **`@MainActor` 型別隱含 `Sendable`**：actor 隔離本身保證安全。
- **class 要 `final` + 全不可變**才安全；否則得 `@unchecked Sendable` 自己負責。
- **6.3 `weak let`**：有 `weak var` 成員而被迫 `@unchecked` 的 class，改成 `weak let`（不可變）即可正常 `Sendable`。
- **6.3 `~Sendable`**：某型別刻意不該 `Sendable`，用 `~Sendable` 明講（且不擋子類別 Sendable）。
- **6.3 Region-based isolation** 正式可用：以前要硬加 `@Sendable` / `@unchecked` 的地方，很多已不需要。

---

## ⚠️ 傳給 ObjC API 的 closure 會隱式繼承隔離

**症狀**：實機執行到某個 framework callback 時 `EXC_BREAKPOINT`，堆疊長這樣——

```
_dispatch_assert_queue_fail
dispatch_assert_queue
_swift_task_checkIsolatedSwift          ← Swift 執行期的隔離檢查
swift_task_isCurrentExecutorWithFlags
closure #1 in YourType.yourMethod       ← 你的 closure，崩在入口
-[NSBlockOperation main]                ← 跑在 framework 自己的佇列上
```

**原因**：從 ObjC 匯入的 API，handler 參數若**既不是 `@Sendable` 也沒有隔離標注**，
傳進去的 closure 會**繼承呼叫端的隔離**。在 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
之下（Xcode 26／27 新專案預設），從一個 `@MainActor` 方法裡寫的 closure 就被推斷成
`@MainActor`。編譯器於是在 closure 入口插入動態隔離檢查——而 framework 是在它自己
的佇列上呼叫它的，檢查當場失敗。

**為什麼特別難抓**：

- 編譯期**零警告**
- 模擬器與單元測試**全過**（那些路徑不會走到 framework 的背景佇列）
- 只有實機、只有 framework 真的回呼的那一刻才崩

**修法**：明確標 `@Sendable`，切斷隔離繼承。

```swift
// ❌ 被推斷成 @MainActor，framework 在自己的佇列呼叫時崩潰
manager.startDeviceMotionUpdates(to: queue) { motion, error in … }

// ✅ 明確 @Sendable → nonisolated，不插入檢查
manager.startDeviceMotionUpdates(to: queue) { @Sendable motion, error in … }
```

**連帶規則**：

- **`@MainActor` closure 型別不要流進背景路徑。** 回呼型別宣告成
  `(@Sendable (T) -> Void)?`，跳回主 actor 是**消費端**的責任
  （`Task { @MainActor in … }`），不是生產端的。
---

### `MainActor.assumeIsolated`——這一條不是崩潰預測，是風險取捨

**⚠️ 即使你的配置保證回呼在主緒（`queue: .main`、`queue: nil`），這一條仍然適用。**

上一節整節的框架是「你看不見的陷阱」——編譯期零警告、模擬器全過、只有實機才崩。**這一條不是那種**，所以它刻意獨立出來：如果混在上一節的連帶規則裡，讀者會用「會不會崩」去篩它，然後在自己配置安全時把它過濾掉。（那正是實測發生過的事——一個專案遵守了整節的其他部分，唯獨在這條上一字不差地踩中，兩年沒發現，因為它的配置讓症狀不呈現。）

- ❌ `MainActor.assumeIsolated { … }`
- ✅ `Task { @MainActor in … }`

**why**：`assumeIsolated` 是 **precondition**——假設錯就崩，而且崩在對方的佇列上。它換到的只是省一次 hop。**把一個可恢復的情況換成不可恢復的崩潰，不管你現在多確定，都划不來**——而「現在多確定」是會隨別人改一行 `queue:` 而失效的。

**適用範圍**：NotificationCenter observer、`beginBackgroundTask` 的 expiration handler、以及任何**佇列由對方決定**的 callback（CoreMotion / CoreBluetooth / AVFoundation 這類舊 ObjC API 都算）。expiration handler 特別值得點名——**系統回收背景時間時在哪條佇列呼叫它，文件沒有保證。**

---

## Actor 隔離策略

```
這份狀態會被多個地方同時讀寫嗎？
├── 不會
│   ├── 唯讀、無狀態 → nonisolated **同步** func（async 的行為取決於 flag，見上方 ⚠️）
│   └── 只有一個 actor 存取 → 跟著那個 actor 走（通常是 @MainActor）
└── 會（跨 actor 讀寫）→ actor
```

```swift
// ✅ @MainActor：只有 UI 層存取
@MainActor
final class ToastManager {
    static let shared = ToastManager()
    var currentToast: Toast?
}

// ✅ actor：跨 actor 的共享可變狀態
actor TokenManager {
    private var accessToken: String?
    func token() -> String? { accessToken }
    func update(_ token: String) { accessToken = token }
}

// ❌ 錯誤：用 @MainActor 保護跨 actor 的資源 → 每次存取都強制切回 MainActor
@MainActor
final class DataCache {
    var cache: [String: Data] = [:]
}
```

### ⚠️ Actor 可重入（reentrancy）

actor 方法遇到 `await` 會**讓出**，其他呼叫可能**插隊**進來——「檢查後再動作」的不變式可能在 `await` 前後被破壞。

**地基規則：在第一個 `await` 之前完成所有 actor 狀態變更；別假設 `await` 之後 state 沒變。**

```swift
actor BankAccount {
    var balance: Double = 0

    // ❌ await 後才用 balance：期間可能被別的呼叫改掉
    func deposit(_ amount: Double) async {
        balance += amount
        await log("deposited \(amount)")   // ⚠️ actor 在此讓出
        print(balance)                     // 可能已不是剛才那個值
    }

    // ✅ 先算完、先讀完，再 await
    func depositFixed(_ amount: Double) async {
        balance += amount
        let snapshot = balance             // await 前先取值
        await log("deposited \(amount)")
        print(snapshot)
    }
}
```

**進階：非 `await` 不可時（如刷新去重）——快取 in-flight Task**

```swift
actor TokenManager {
    private var token: String?
    private var refreshTask: Task<String, Error>?

    func validToken() async throws -> String {
        if let token { return token }
        // ❌ 直接 await refresh()：兩個呼叫會各刷一次（await 期間互相插隊）
        // ✅ 快取 in-flight Task，重入的呼叫共用同一次刷新
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await refresh() }
        refreshTask = task
        defer { refreshTask = nil }
        let new = try await task.value
        token = new
        return new
    }
}
```
