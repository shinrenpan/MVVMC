# TODO

Pending work tracker. Not part of the spec — see `CLAUDE.md` for the architecture rules.

## Next up (after v2.2.0)

- [ ] **Module-default `@MainActor` vs `mvvmc-viewmodel`** — Swift 6.2 lets a module default to main-actor isolation (`.defaultIsolation(MainActor.self)` / `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`; Xcode 26 new projects enable it by default). Decide whether ViewModels still need an explicit per-class `@MainActor`. This would change the VM-layer skill and CLAUDE.md.
- [ ] **`withMainSerialExecutor` in `mvvmc-testing`** — adopt from AvdLee's Swift Concurrency skill (`references/testing.md`) for deterministic concurrency tests.
- [ ] **Verify `@concurrent` declaration form** — `swift-concurrency` SKILL.md confirms the closure form `Task { @concurrent in }`; the function-declaration form `nonisolated @concurrent func` (SE-0461) is flagged "verify locally". Compile-check on the local toolchain (Swift 6.3.1) and finalize.

- [ ] **Demo coverage gaps** — rules marked ❌ in `SPEC-COVERAGE.md` have never been compile-checked: `pullToRefresh`, `@Bindable` + `TextField`, display helper, Slot pattern, `ForEach` + `@State` identity trap, `sheet` detents, `backTo` / `backToRoot`, L2 nested type with parent prefix.

## Environment notes

- Local toolchain: Swift 6.3.1, Target arm64-apple-macosx26.0
- Swift 6.4 (WWDC 2026) not yet GA — APIs like `withTaskCancellationShield` marked accordingly in the concurrency skill
