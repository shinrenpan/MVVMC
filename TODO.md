# TODO

Pending work tracker. Not part of the spec — see `CLAUDE.md` for the architecture rules.

## Next up (after v2.2.0)

- [ ] **Module-default `@MainActor` vs `mvvmc-viewmodel`** — Swift 6.2 lets a module default to main-actor isolation (`.defaultIsolation(MainActor.self)` / `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`; Xcode 26 new projects enable it by default). Decide whether ViewModels still need an explicit per-class `@MainActor`. This would change the VM-layer skill and CLAUDE.md.
- [ ] **`withMainSerialExecutor` in `mvvmc-testing`** — adopt from AvdLee's Swift Concurrency skill (`references/testing.md`) for deterministic concurrency tests.
- [ ] **Verify `@concurrent` declaration form** — `swift-concurrency` SKILL.md confirms the closure form `Task { @concurrent in }`; the function-declaration form `nonisolated @concurrent func` (SE-0461) is flagged "verify locally". Compile-check on the local toolchain (Swift 6.3.1) and finalize.

- [ ] **Demo coverage gaps** — rules marked ❌ in `SPEC-COVERAGE.md` have never been compile-checked: `pullToRefresh`, `@Bindable` + `TextField`, display helper, Slot pattern, `ForEach` + `@State` identity trap, `sheet` detents, `backTo` / `backToRoot`, L2 nested type with parent prefix.

- [ ] **Skip × V-layer Action Pattern** — `mvvmc-skip` 眉角 #6（巢狀 enum 在 Kotlin 要完整限定）目前只涵蓋 `doAction(.view(...))`。V 層的 `send(.rowDidTap)` 同樣是巢狀 enum 的 leading-dot 呼叫，理論上也會踩到，且 `send` 現在的型別是 `@MainActor (Action) -> Void`（Skip 如何轉譯 global-actor 隔離的函式型別未知）。**需要有 Android 目標的專案實測後才寫進 skill**——沒驗證過的規則不該進 skip，那份是實測筆記。

## Environment notes

- Local toolchain: Swift 6.3.1, Target arm64-apple-macosx26.0
- Swift 6.4 (WWDC 2026) not yet GA — APIs like `withTaskCancellationShield` marked accordingly in the concurrency skill
