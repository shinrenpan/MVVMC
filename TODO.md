# TODO

Pending work tracker. Not part of the spec — see `CLAUDE.md` for the architecture rules.

## Next up (after v2.2.0)

- [x] ~~**Module-default `@MainActor`**~~ — **settled 2026-08: keep annotating explicitly.** The skills are meant to travel to other projects whose build settings you don't control, and `nonisolated async` already has its behaviour decided by a flag — a second setting-dependent semantic is one too many. Rationale written into `mvvmc-viewmodel`〈強制宣告〉; the demo deliberately leaves `SWIFT_DEFAULT_ACTOR_ISOLATION` off.
- [x] ~~**`withMainSerialExecutor` in `mvvmc-testing`**~~ — **settled 2026-08: not adopting.** Tests that inject through `.apiResponse` are already deterministic, and the one flaky-prone category (a ViewAction that chains into a real request) is excluded at source by 〈什麼值得測試〉. A permanent dependency for a hypothetical benefit. Rationale written into `mvvmc-testing`〈設計哲學〉; revisit if real flakiness ever appears.
- [x] ~~**Verify `@concurrent` declaration form**~~ — done 2026-08 on Swift 6.3.1: `@concurrent func` (member and top-level) compiles, `Task { @concurrent in }` compiles, but `nonisolated @concurrent func` fails to parse (`@concurrent` already implies nonisolated). Recorded in `swift-concurrency` SKILL.md.

- [ ] **Demo coverage gaps** — rules still marked ❌ in `SPEC-COVERAGE.md`: `@Bindable` + `TextField`, display helper, Slot pattern, shared UI component across features, multiple concurrent requests, non-navigation side effect run in the VM, L2 nested type with parent prefix. Each needs a demo feature it doesn't currently have — now also including pagination and a form screen (both surfaced by the second generation probe). (`pullToRefresh` and `sheet` detents closed 2026-08. Items marked 🚫 are deliberate non-goals, not pending work.)

- [ ] **Skip × V-layer Action Pattern** — `mvvmc-skip` 眉角 #6（巢狀 enum 在 Kotlin 要完整限定）目前只涵蓋 `doAction(.view(...))`。V 層的 `send(.rowDidTap)` 同樣是巢狀 enum 的 leading-dot 呼叫，理論上也會踩到，且 `send` 現在的型別是 `@MainActor (Action) -> Void`（Skip 如何轉譯 global-actor 隔離的函式型別未知）。**需要有 Android 目標的專案實測後才寫進 skill**——沒驗證過的規則不該進 skip，那份是實測筆記。

- [ ] **規範成長速度超過 demo** — `SPEC-COVERAGE.md` 現在有 16 個 ❌ 對 10 個 🚫。多數 ❌ 是 2026-08 生成測試補進來的**場景規範**（分頁、表單、輪詢、深層回傳、alert、樂觀更新），而 demo 六個 feature 完全沒有這些場景。需要決定走哪條路：(a) 擴充 demo 涵蓋主要場景，(b) 接受「規範涵蓋面大於 demo」並在 SPEC-COVERAGE 開頭講清楚這件事是刻意的。目前是預設 (b) 但沒有明講。

## Environment notes

- Local toolchain: Swift 6.3.1, Target arm64-apple-macosx26.0
- Swift 6.4 (WWDC 2026) not yet GA — APIs like `withTaskCancellationShield` marked accordingly in the concurrency skill
