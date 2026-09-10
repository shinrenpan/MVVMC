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

## Environment notes

- Local toolchain: Swift 6.4 (Xcode 27.0 RC, 27A266a), Target arm64-apple-macosx26.0
- Host is **macOS 26.6.2**, not macOS 27 — Xcode was upgraded for the iOS SDK, the OS was not (Homebrew / third-party). Consequence: `Experiments/ConcurrencyProbe/` builds as a native macOS binary and therefore **cannot reach any `@available(anyAppleOS 27.0, *)` API**. The iOS 27.0 simulator runtime *is* installed, so the iOS side of such an API is testable; the macOS side is not.
- Swift 6.4 is GA in the toolchain, but its new APIs (e.g. `withTaskCancellationShield`) are gated `@available(anyAppleOS 27.0, *)` and so remain unusable at the iOS 17+ deployment target. The concurrency skill states this as an availability constraint, not as "not yet released".
- **Probes re-run on Xcode 27 (2026-09-10):** `ConcurrencyProbe` unchanged; `ViewSplitProbe` unchanged **except** the reorder rows, where a `@State`-holding child went `bodies=3` → `0`. Isolated to the **linked SDK** (same machine, same iOS 26.4 simulator, `DEVELOPER_DIR` swap), so it is not an iOS 27 story — a Xcode-27 rebuild gets the new behaviour on iOS 26 as well. Written into `mvvmc-view`〈拆與不拆的決策準則〉as an SDK matrix and into `ViewSplitProbe/README.md`. The `AnyView` finding (`mvvmc-deep-review`) re-measured identical on both SDKs.
- **Still recorded against Swift 6.3.1 / Xcode 26.4.1**, not re-run: `mvvmc-testing/references/patterns.md` (three examples said to compile in the demo test target — that target now builds clean under 27, so this is probably already covered; verify rather than assume) and `mvvmc-view/references/architecture.md`'s `@Bindable` `$`-placement note. Both are compile-behaviour claims, cheaper to check than the SwiftUI measurements.
