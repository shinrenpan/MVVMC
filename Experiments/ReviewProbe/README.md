# ReviewProbe

Tests whether the skills have **executable force** — that is, whether an AI reading them actually catches violations, rather than whether the prose is internally consistent.

Everything else in this repo validates the spec as a *document*. This validates it as *instructions*. A rule nobody enforces is a rule that doesn't exist, and that failure mode is invisible to proofreading.

## Method

`BadFeature/` is a four-file MVVMC feature with **31 deliberately planted violations** (8 M, 8 VM, 8 V, 7 C). It is written to look like plausible production code — not like a teaching example — so the reviewer has to apply judgement, not pattern-match on obvious absurdity.

The files **do not compile** (one violation is a reference to a type that doesn't exist) and are excluded from the demo target: `project.yml` only sources `Sources/`.

To re-run, hand the directory to a *fresh* agent that has not seen this README, with a neutral prompt:

> 用 mvvmc-review 的規範審查這個 feature：`Experiments/ReviewProbe/BadFeature/`。規範在 `.claude/skills/`。

**The reviewer must not know the ground truth** — otherwise the result is worthless. Do not paste the table below into the prompt.

## Ground truth (31 planted violations)

**M — `OrderListViewModel+Models.swift`**
1. `State` missing `Equatable`
2. `State` holds DTOs (`orderDTOs: [OrderDTO]`)
3. `State` holds an untranslated `Error`
4. `State` references another feature's Domain Model (`PostListViewModel.User`)
5. Domain Model exposes a `Color` computed property
6. DTO conforms to `Equatable`
7. DTO uses `CodingKeys` instead of 1:1 API naming
8. M-layer file imports SwiftUI

**VM — `OrderListViewModel.swift`**
9. `onRoute` not marked `@ObservationIgnored`
10. `onRoute` type missing `@MainActor`
11. ViewModel holds a `UIViewController`
12. ViewModel presents a VC directly
13. Public `refresh()` bypassing `doAction`
14. `handleAPIRequest` mutates state directly
15. `catch` writes state instead of dispatching `.failure`
16. State stores DTOs — `toDomain()` never called by the VM

**V — `OrderListView.swift`**
17. View creates its own ViewModel (`@State private var`)
18. Whole ViewModel passed into a subview
19. Subview declared top-level instead of in a `private extension`
20. `body` split with a `@ViewBuilder` computed property
21. Calls `viewModel.refresh()`, bypassing `doAction`
22. Subview declares `enum Action` but has no `send` — dead code
23. View reads DTOs and calls `toDomain()` inside `body`
24. Child Action named with the parent's business semantics (`orderDetailDidTap`)

**C — `OrderListHostController.swift`**
25. `viewModel` not `private`
26. ViewModel not injected into the View → two separate instances
27. `onRoute` closure without `[weak self]`
28. Calls `pushViewController` directly instead of `AppRouter`
29. HostController starts a `Task` to drive the ViewModel
30. `viewDidDisappear` nils out `onRoute`
31. Hands `self` to the ViewModel

## Result (2026-08, Claude Opus 5 subagent)

**31/31 caught. 0 missed. 0 false positives.**

Three judgement calls came out right, and all three exercise rules added in this same review cycle:

- **Did not** open a finding for "endpoints have no dedicated file" — it quoted the explicit "審查時不得以此開單" clause
- Classified missing Mocks/Preview as *suggestions*, correctly reading them as optional per spec
- On `shareDidTap`: recognised sharing as the "VM may do this directly" category, **but** flagged that implementing it by presenting a VC changes the navigation stack — which puts it back under the `onRoute` boundary rule

It also found seven issues that were **not** planted, two of which the author of the spec had not noticed:

- `UIActivityViewController` without a popover anchor → crashes on iPad
- `PostListViewModel.User` does not exist anywhere in the project → won't compile
- `.failure` branch unreachable because `catch` never dispatches
- `shareDidTap` and `selectedUser` are dead — no call sites
- `Router` missing `Equatable`, which blocks the navigation-intent test the testing skill prescribes

## Second axis: can it *fix* what it found?

Finding a violation and repairing it correctly are different abilities. A separate agent was given the same `BadFeature/` and asked to review **and then fix** it, writing the result elsewhere (the sample here is never modified).

**All 31 repaired correctly.** Spot-checked across every layer: display helper moved to the top of the View file, subviews restructured into `ListSection` → `ListRow` with `send: @MainActor (Action) -> Void`, C layer back to `private let` + `init(viewModel:)` + `[weak self]` + `handleRouter` + `AppRouter`, DTOs stopped at `handleAPIResponse`, errors translated before reaching State.

Two things made this run more valuable than a pass/fail:

- **It hit the same spec hole as the generation probe, from the opposite direction.** Asked to fix the "VM presents a share sheet" violation, it found that `mvvmc-viewmodel` classified sharing as "the VM may do this directly" while `mvvmc-hostcontroller` forbids the VM from holding a `UIViewController` — and `UIActivityViewController` requires one. Two agents, two different tasks, same contradiction. That is much stronger evidence than either finding alone.
- **It refused to make a product decision.** Finding an Action case with no call site, it declined to delete it: "removing it means removing a feature — that's a product decision, not a review decision." That judgement is now written into `mvvmc-review`.

## Limits of this result

Read it as "the skills are enforceable", not "the skills are complete":

- Violation density is far above real code, and every planted violation maps to an explicit written rule. This does not test the grey areas where no rule exists — the failure mode most likely to matter in practice.
- One run, one feature, one model generation. It is evidence, not a regression suite.
- Catching a violation is not the same as giving good advice about it; the suggested fixes were spot-checked, not verified by applying them.
