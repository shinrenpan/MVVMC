# TODO

Pending work tracker. Not part of the spec — see `CLAUDE.md` for the architecture rules.

## Next up (after v2.2.0)

- [x] ~~**Module-default `@MainActor`**~~ — **settled 2026-08, rationale replaced 2026-09: keep annotating explicitly.**
  The original reason ("the skills travel to projects whose build settings you don't control") **was demolished in 2026-09** by a shipped project that *is* one of those projects and had enabled the setting deliberately. The replacement reason is stronger and comes from a project with a widget extension: **`SWIFT_DEFAULT_ACTOR_ISOLATION` is per-target, and sharing source files across targets is the norm once you have an extension.** A file compiled by two targets cannot have its default isolation decided outside the file — the same line would mean two things and nothing in the file says so.
  What also changed: the skill now **branches by task mode** (generate / review / refactor) instead of stating one rule, because reviewing a project that *has* enabled it with the old wording produced a batch of false findings. Rationale in `mvvmc-viewmodel`〈強制宣告〉; the demo deliberately leaves the setting off.
  **Re-open condition** (checkable on the spot): a project appears that shares no source files across targets *and* whose `nonisolated` annotation count exceeds its `@MainActor` count — `grep -c` both in that repo.
- [x] ~~**`withMainSerialExecutor` in `mvvmc-testing`**~~ — **settled 2026-08: not adopting.** Tests that inject through `.apiResponse` are already deterministic, and the one flaky-prone category (a ViewAction that chains into a real request) is excluded at source by 〈什麼值得測試〉. A permanent dependency for a hypothetical benefit. Rationale written into `mvvmc-testing`〈設計哲學〉; revisit if real flakiness ever appears.
- [x] ~~**Verify `@concurrent` declaration form**~~ — done 2026-08 on Swift 6.3.1: `@concurrent func` (member and top-level) compiles, `Task { @concurrent in }` compiles, but `nonisolated @concurrent func` fails to parse (`@concurrent` already implies nonisolated). Recorded in `swift-concurrency` SKILL.md.

- [x] ~~**Demo coverage gaps / 規範成長超過 demo**~~ — **settled 2026-08: the spec is allowed to reach further than the demo.** The six demo features cover every structural rule; the remaining ❌ are scenario rules (pagination, forms, polling, deep return), and stuffing those into the demo would trade clarity for coverage. They are verified through `Experiments/GenerationProbe/` instead — five features built from the spec alone, each typechecked under Swift 6. Stated at the top of `SPEC-COVERAGE.md`, so ❌ now reads "not in the demo" rather than "never checked".

- [ ] **Skip × V-layer Action Pattern** *(blocked: 需要有 Android target 的專案才能實測，非「還沒想」)* — `mvvmc-skip` 眉角 #6（巢狀 enum 在 Kotlin 要完整限定）目前只涵蓋 `doAction(.view(...))`。V 層的 `send(.rowDidTap)` 同樣是巢狀 enum 的 leading-dot 呼叫，理論上也會踩到，且 `send` 現在的型別是 `@MainActor (Action) -> Void`（Skip 如何轉譯 global-actor 隔離的函式型別未知）。**需要有 Android 目標的專案實測後才寫進 skill**——沒驗證過的規則不該進 skip，那份是實測筆記。

- [ ] **規範成長速度超過 demo** — `SPEC-COVERAGE.md` 現在有 **22 個 ❌ 對 15 個 🚫**（2026-09 那輪新增 20 列之後重數）。多數 ❌ 是 2026-08 生成測試補進來的**場景規範**（分頁、表單、輪詢、深層回傳、alert、樂觀更新），而 demo 六個 feature 完全沒有這些場景。需要決定走哪條路：(a) 擴充 demo 涵蓋主要場景，(b) 接受「規範涵蓋面大於 demo」並在 SPEC-COVERAGE 開頭講清楚這件事是刻意的。目前是預設 (b) 但沒有明講。

## Open — three measurements, all in `Experiments/ViewSplitProbe/`

Each decides the wording of a rule that is currently hedged. None is bug-level; all are cheap once the harness is open.

- [ ] **`Group` vs `VStack` as the `.task` mounting container** (four-state skeleton × polling). Two field reports gave **opposite** answers and neither had measured: `Group` may distribute modifiers to its children (landing `.task` back on the conditional it was meant to escape); `VStack` has its own identity but **changes the layout of both branches** — `ProgressView` wants centring, the list wants to fill. `architecture.md` §1 currently states both risks and points at a third path (`.task` on an outer container) rather than picking one.
- [ ] **`@State` misplacement in the shapes the reorder probe did not cover**: `id: \.self`, index-based `ForEach`, nested `ForEach`, animated reorder. §8's three claims did not reproduce for `Identifiable` + single-level `ForEach` + synchronous reorder, and the section is annotated as such rather than deleted — because those four shapes were never measured.
- [ ] **Does `Data` embedded in a Domain Model short-circuit on `==`?** Decides whether `mvvmc-model` Equatable exception 3's "hundreds of MB" threshold is right. If COW makes it a pointer comparison the threshold is correct and finally gets a *why* (it has none today); if not, the threshold is wrong.

## Blocked on tooling — iPhone Duo (foldable)

**不要在 Xcode 27.1 模擬器到位之前把下面任何一條寫成規範。** 這些是研究素材，不是規則。裝置 2026-10 底發售、API 在 iOS 27.1、模擬器要 Xcode 27.1（官方頁面標 "Coming later this month"），**今天一條都驗不了**。把未經量測的前提寫成規則，正是 `Experiments/README.md` 開宗明義在防的事。

來源是 Apple 官方 Tech Talk 字幕軌（111461/111462/111463/111466）與 developer.apple.com，2026-09-11 取得。

**MVVMC 現況（已盤點，2026-09-11）**：`SceneDelegate` 用 `UIWindow(windowScene:)` 而非 `UIScreen.main`、demo 零個寫死 `.frame(width:/height:)`、無 orientation 鎖定——結構上乾淨。**但全部 11 個 skill 對 size class / trait collection / adaptive layout 零著墨**，這是主要暴露面。`TARGETED_DEVICE_FAMILY: "1"`（iPhone only）。

官方事實，備查：

- **舊 SDK 建的 app 照跑**，Apple 的用詞是「熟悉的尺寸與長寬比」，不是相容模式／黑邊。**linked SDK 本身就是開關，沒有 opt-in plist key。**
- **`UIRequiresFullScreen` 仍被尊重**，但擋不住開合造成的 resize。
- **`UISplitViewController` / `NavigationSplitView` / `UITabBarController` 全部 fully adaptive**：闔上時 column 收合成單一 stack，展開時 tiled 或 overlay。
- **五支 Tech Talk 沒有任何一處建議「展開時換容器」**——一致訊息是用標準 adaptive 容器讓它原地適配。這對「C 是唯一導航層」是好消息。
- **設計層硬要求**：不要把功能綁在某個開合姿態上；使用者會頻繁開合。
- **查幾何、不要監聽事件**。layout 的輸入是三項：size class、view 寬高比、有沒有 active division region（攤平時 division region 寬度為 0）。
- **`ArrangementView` 是排版容器不是導航容器**：禁止在其中放 `NavigationSplitView`，也不要放進 `List` / `ScrollView`。跟 MVVMC 的分層不衝突。iOS 27.1 起 app 可用系統提供的 arrangement。
- **會打到 AppRouter 的細節**：sheet 的 toolbar 軸向**內外螢幕相反**——外螢幕已有 toolbar 的 sheet 顯示為垂直，內螢幕預設置中且維持水平。Router 目前統一用 `.pageSheet`，V 層若對 toolbar 佈局有假設會歪。
- split view 中**只有 detail column** 參與垂直 bar；其他 column 維持水平。

**解除條件**：Xcode 27.1 釋出且 `xcrun simctl list runtimes` 出現 iPhone Duo。屆時先做的是**量測**（把 demo 放進 Duo 模擬器，開合各截一次），不是先寫規則。

## Environment notes

- Local toolchain: Swift 6.4 (Xcode 27.0 RC, 27A266a), Target arm64-apple-macosx26.0
- Host is **macOS 26.6.2**, not macOS 27 — Xcode was upgraded for the iOS SDK, the OS was not (Homebrew / third-party). Consequence: `Experiments/ConcurrencyProbe/` builds as a native macOS binary and therefore **cannot reach any `@available(anyAppleOS 27.0, *)` API**. The iOS 27.0 simulator runtime *is* installed, so the iOS side of such an API is testable; the macOS side is not.
- Swift 6.4 is GA in the toolchain, but its new APIs (e.g. `withTaskCancellationShield`) are gated `@available(anyAppleOS 27.0, *)` and so remain unusable at the iOS 17+ deployment target. The concurrency skill states this as an availability constraint, not as "not yet released".
- **Probes re-run on Xcode 27 (2026-09-10):** `ConcurrencyProbe` unchanged; `ViewSplitProbe` unchanged **except** the reorder rows, where a `@State`-holding child went `bodies=3` → `0`. Isolated to the **linked SDK** (same machine, same iOS 26.4 simulator, `DEVELOPER_DIR` swap), so it is not an iOS 27 story — a Xcode-27 rebuild gets the new behaviour on iOS 26 as well. Written into `mvvmc-view`〈拆與不拆的決策準則〉as an SDK matrix and into `ViewSplitProbe/README.md`. The `AnyView` finding (`mvvmc-deep-review`) re-measured identical on both SDKs.
- **Still recorded against Swift 6.3.1 / Xcode 26.4.1**, not re-run: `mvvmc-testing/references/patterns.md` (three examples said to compile in the demo test target — that target now builds clean under 27, so this is probably already covered; verify rather than assume) and `mvvmc-view/references/architecture.md`'s `@Bindable` `$`-placement note. Both are compile-behaviour claims, cheaper to check than the SwiftUI measurements.
