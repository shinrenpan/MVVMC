# Spec Coverage

Maps each load-bearing rule to the demo file that proves it compiles.

`Sources/` and `Tests/` are the spec's **compile-time test**: a rule no demo file exercises has never been checked by a compiler. When you change a rule in `.claude/skills/`, update the demo and this table in the same pass — that is how the spec and the demo stay in sync.

Legend: ✅ demonstrated · ❌ not demonstrated · 🚫 deliberately not demonstrated

**❌ vs 🚫**: ❌ means the demo *could* show it and doesn't — those are candidate work, listed in `TODO.md`. 🚫 means demonstrating it would require bending the demo out of shape (inventing a feature, adding a navigation level, or breaking an existing demonstration). A 🚫 rule is validated by reasoning and by other projects, not by this demo — and that is a deliberate trade, because a demo that shows everything stops showing anything clearly.

## Why the spec reaches further than the demo

As of 2026-09 this table carries **22 ❌ against 15 🚫**. **That gap is deliberate, not drift.**

The demo's six features cover every *structural* rule — the shape of each layer, navigation, cross-VC callbacks, tests. What they don't cover are *scenario* rules: pagination, forms, polling, deep returns. Adding those would turn a clear architectural demo into a feature grab-bag, which is the same trade the 🚫 markers already explain — a demo that shows everything stops showing anything clearly.

Those scenario rules are **not unverified — they're verified somewhere else**. `Experiments/GenerationProbe/` holds five features built from the spec alone, by agents forbidden to read `Sources/`, each typechecked under Swift 6 with strict concurrency. Pagination, forms, polling, wizards and deep returns were each implemented that way at least once, and the gaps those runs exposed are what produced the current wording of those rules.

So read ❌ as **"not in the demo"**, not as "never checked". The demo is the compile-time test for *structure*; the generation probes are the test for *scenarios*.

**A third source joined in 2026-09**: rules that came back from three shipped apps, plus measurements from `Experiments/`. Several of those are 🚫 by nature — a rule about module-level isolation, or about what a probe measured, has nowhere to live in a single-target demo with no polling screen. **And one of them is why the demo still earns its place**: trying to satisfy "the Router must not inject a Close button" in the demo is what revealed the rule was unimplementable on its own. See the Navigation section.

---

## Structure — `mvvmc-structure`

| Rule | Demonstrated in |
|---|---|
| One directory per feature under `Pages/` | `Sources/Pages/` (six features) |
| Domain Model is **not** shared across features | `PostList.Post` (has `userId`) vs `PostDetail.Post` (does not) |
| Cross-feature transfer via primitives | `PostDetailHostController(id:title:body:)` |
| `Shared/` holds business-agnostic types only | `Sources/Shared/APIStatus.swift` (`APIStatus`, `APIError`) |
| Shared UI component promoted out of `Pages/` | ❌ — no cross-feature component exists in the demo |
| Feature split criteria | 🚫 — a judgement rule, not code; six small features never trigger it |
| Wizard collapsed into one feature (`step` enum) | 🚫 — same reason; the demo has no multi-step flow |

## M — `mvvmc-model`

| Rule | Demonstrated in |
|---|---|
| State / Domain Models / DTOs in separate `extension` blocks | `PostList/PostListViewModel+Models.swift` |
| `State` is `Equatable, Sendable`, every field defaulted | all six `*ViewModel+Models.swift` |
| Detail-view exception: `let post` with no parameterless `init()` | `PostDetail/PostDetailViewModel+Models.swift` |
| Detail exception's cost spreads to VM and tests (`var state` + `init(post:)`) | `PostDetail/PostDetailViewModel.swift` — **the demo already had the right shape before the rule named it** |
| `let` only when the data truly never reloads; otherwise `var` | `PostDetail` qualifies (no `doAction`, no refresh path) — the **`var`** default is ❌ undemonstrated |
| `APIStatus`-class containers: shape is unregulated, **location** follows `mvvmc-structure` once a second feature uses them | `Shared/APIStatus.swift` |
| High-frequency field isolation — the cost multiplier | 🚫 — measured in `Experiments/ViewSplitProbe/`, not demonstrable in a demo with no polling screen |
| Field-type blacklist — UI state container is legal | `PostList` / `UserDetail` (`var api: API`) |
| Field-type blacklist — no raw `Error` in State | `PostList` / `UserDetail` (`.error(String)`, not `.error(Error)`) |
| `State` computed property for derived values | 🚫 — no demo screen has a value worth deriving; adding one would be decoration |
| Domain Model is `Identifiable` when it has an `id` | `PostList.Post`, `PostFilter.User` |
| DTO property names mirror API keys 1:1, no `CodingKeys` | `PostList.PostDTO` (`user_id`) |
| `toDomain()` filters invalid rows (returns `Optional`) | `UserDetail.UserDTO` |
| DTO does **not** conform to `Equatable` | all DTOs |
| Mocks hang off Domain Models, whole file `#if DEBUG` | `PostList/PostListMocks.swift`, `PostDetail/PostDetailMocks.swift` |
| L2 nested type with parent prefix (`OrderStatus` style) | ❌ |
| Equatable exceptions (closure member / fire-and-forget / large blob) | 🚫 — edge cases; demonstrating them means inventing a State that shouldn't exist |

## VM — `mvvmc-viewmodel`

| Rule | Demonstrated in |
|---|---|
| Module-default isolation: three task modes branch on the build setting | 🚫 — the demo deliberately leaves `SWIFT_DEFAULT_ACTOR_ISOLATION` off, so only the "not enabled" column is exercised |
| Cross-target shared files must annotate isolation explicitly | 🚫 — the demo is a single target |
| Deep return splits into terminal / non-terminal | ❌ — the demo's callback chain is one level, which is neither |
| Re-submit guard resets via `defer` | ❌ — no form screen. Measured separately in `Experiments/CancellationProbe/` |
| Bool re-entry flag: forbidden for polling, required for submit, wrong for pagination | ❌ — the demo has none of the three |
| `@Observable @MainActor final class` | all six `*ViewModel.swift` |
| `doAction(_:)` as the single entry point, `switch` dispatch only | same |
| Three-layer Action (`view` / `apiRequest` / `apiResponse`) | `PostList`, `UserDetail` |
| `onRoute` set by HostController, `@ObservationIgnored` | `PostListViewModel.swift` |
| `onCallback` async closure for cross-VC results | `PostFilterViewModel.swift` |
| Run once: `isFirstAppear` + guard | `PostList`, `UserDetail` |
| Run once: `pullToRefresh` sharing the same APIRequest | `PostList` (`.refreshable` → same `fetchPosts`) |
| Network layer is out of scope (endpoint layout is one option) | `PostList/PostListViewModel+APIs.swift` |
| Error translated before it reaches State | `PostListViewModel.handleAPIResponse` |
| Multiple concurrent requests, one status field each | ❌ — every demo VM has exactly one request |
| Non-navigation side effect run directly in the VM (open URL / share) | ❌ — demo has no such action |
| Pagination (first-load vs load-more tracked separately) | ❌ — the fake API returns a fixed 5 rows |
| Form screen (validation, submitting lock, preserve input on failure) | ❌ — demo has no form |
| Deep return: relay upward, only the endpoint pops | ❌ — demo's callback chain is one level deep |
| Polling loop started by `.task`, living in the VM | ❌ — no demo screen polls |
| Optimistic update (VM constructs a Domain Model) | ❌ |

## V — `mvvmc-view`

| Rule | Demonstrated in |
|---|---|
| Rule 7 — the test is "does this layer have code other than forwarding", not "is there semantics to add" | `PostList/PostListView.swift` (`ListSection` has layout duties, its 1:1 forwards are legal) |
| §7's skipping premise: the child must be a **value** type — a child holding `@State` re-runs on reorder | 🚫 — measured in `ViewSplitProbe`; the demo has no reorderable list |
| §7's skipping premise survives the mandated `let send: @MainActor (Action) -> Void` on the child (both a method reference and a closure literal, Debug and `-O`) | 🚫 — measured in `ViewSplitProbe` 2026-09-11; the demo cannot show a *non*-invalidation |
| §8's three claims (misplacement / `.id()` fixes it / `.id()` resets state) | 🚫 — **none reproduced under measurement**; annotated in `architecture.md`, not demonstrated |
| Four-state skeleton × polling interaction (`.task` mounting point) | ❌ — no demo screen polls |
| L1 holds `let viewModel`, never creates its own | all `*View.swift` |
| L2/L3 with `enum Action` + `let send: @MainActor (Action) -> Void` | `PostList/PostListView.swift` |
| Child Action named from the child's own viewpoint; parent does real Mapping | `PostListView.ListRow` → `ListSection` |
| Pure display component needs no `enum Action` | `UserDetail/UserDetailView.swift` (`InfoSection`) |
| L2 naming: drop the View prefix, `Section` suffix | `ListSection`, `InfoSection` |
| Same-prefix components share one `private extension` | `PostListView` (`ListSection` + `ListRow`) |
| Action handler extracted as `@MainActor private func`, kept beside `body` | `PostListView.handleListAction` |
| Every interaction goes through `Task { await doAction(.view(...)) }` | `PostListView`, `PostFilterView` |
| Preview injects mock state, wrapped in `#if DEBUG` | `PostListView`, `UserDetailView` (both spell out `Post.mocks` in full — the `.mocks` shorthand does not compile) |
| Four-state block (loading / error / empty / content) | `PostListView` — covers loading / error / content; **empty state not shown** |
| `@Bindable` inside `body` for a `TextField` binding | ❌ — demo has no text input |
| Display helper (`private extension Model { var color: Color }`) | ❌ |
| Slot pattern (`@ViewBuilder` container) | ❌ |
| Alert / confirmation dialog driven by a state flag | ❌ — demo has no destructive action to confirm |
| `ForEach` + child `@State` identity trap | 🚫 — showing the trap means shipping the anti-pattern the spec tells you to avoid |

## C — `mvvmc-hostcontroller`

| Rule | Demonstrated in |
|---|---|
| Third init shape: cross-feature **and** needs a callback → child C takes primitives + closure | ❌ — the demo's only callback (`PostFilter`) is same-feature, so it uses the standard shape |
| iOS-branch scope note (`#else` branches are `mvvmc-skip`'s, not this skill's) | 🚫 — the demo has no Skip target |
| `@MainActor final class : UIHostingController<FeatureView>` | all six `*HostController.swift` |
| Standard init: ViewModel injected from outside | `PostListHostController.swift` |
| Variant: primitives in, ViewModel assembled inside C | `PostDetailHostController.swift` |
| `viewDidLoad` wires `viewModel.onRoute` with `[weak self]` | `PostListHostController.swift` |
| Routing centralised in `handleRouter(_:)` in a `private extension` | same |
| Child `onCallback` set before navigating, no `Task` wrapper | `PostListHostController.swift` → `PostFilter` |
| Callback payload is a primitive, not a Domain Model | `PostFilterViewModel.Callback.didSelectUser(id:)` |
| `required init?(coder:)` marked `@available(*, unavailable)` | all |

## Navigation — `mvvmc-navigation`

| Rule | Demonstrated in |
|---|---|
| The four dimensions are a **coverage checklist**, not a required API surface | `Sources/App/AppRouter.swift` is *one* filling of it — explicitly demoted from "the spec" to "a reference" |
| Source dimension's third value `.topMost(from:)` (persistent sheet holds the presentation slot) | ❌ — the demo has no persistent sheet |
| `backTo(_:)` takes no `from:` | `Sources/App/AppRouter.swift` — implemented, **zero call sites**, so the signature compiles but is unexercised |
| Router must not inject a Close button; the destination provides its own exit | `Sources/App/AppRouter.swift` + `Settings/SettingsView.swift` (`.toolbar` → `doAction(.view(.close))` → `onRoute?(.close)` → `back(from:)`) |
| Deeplink returns **a set of VCs + an intent**, not one VC | `Sources/App/Deeplink.swift` (`Destination.navigate(tab:stack:)` / `.present`) |

> **This pair is the demo earning its keep.** The Close-button rule alone was not implementable: `PostDetailHostController` is used on two paths — pushed from the list (no close button wanted) and deeplinked (one needed) — so "the destination provides its own exit" would have forced the page to know how it was presented. Trying to satisfy the rule in the demo is what showed the rule was missing its other half. Once deeplink *navigates* (select tab, push onto the existing stack) instead of presenting, the system back button exists and the problem disappears.
| Stateless `AppRouter`, nav resolved from `source.navigationController` | `Sources/App/AppRouter.swift` |
| `to()` with `.push` / `.modal` / `.fade` | `PostList` → `PostFilter` (modal), `UserDetail` (fade) |
| `sheet()` | `Settings` |
| `sheet()` with custom `detents` | `Profile` → `Settings` (`[.medium(), .large()]`) |
| `back()` auto-detecting sheet → dismiss | `PostFilter`, `Settings` |
| `backTo()` / `backToRoot()` | 🚫 — the demo's deepest stack is two levels, where these are indistinguishable from `back()` |
| `tab()` | `Profile` |
| `deeplink()` returning `Deeplink.Destination` — `.navigate(tab:stack:)` selects the tab and pushes onto the existing stack; `.present(_:)` for a true modal. **No injected Close button** | `Sources/App/Deeplink.swift` + `AppRouter.deeplink(_:)` |
| Three SceneDelegate entry points (foreground / cold start / push) | `Sources/App/SceneDelegate.swift` |
| Swipe-back gating to `.push` pages only | `AppRouter.gestureRecognizerShouldBegin` |
| `window.backgroundColor` set | `SceneDelegate.swift` |

## Testing — `mvvmc-testing`

| Rule | Demonstrated in |
|---|---|
| Architectural invariant tests (localisation coverage, cross-feature references) | ❌ — the demo has no localisation and one module |
| Whole-state comparison misses hand-written `==` members **and computed properties** | ❌ — no demo State has either |
| Every new technique carries a greppable "applies when" signal | 🚫 — a maintenance convention, not code |
| Inject results via `doAction(.apiResponse(...))`, no protocol / mock class | all three test files |
| Raw identifier test names (Swift 6.2+) | all |
| `@MainActor` on the suite struct | all |
| Guard logic (`isFirstAppear`) | `PostListViewModelTests`, `UserDetailViewModelTests` |
| Success / failure injection | same |
| Callback assertion | `PostFilterViewModelTests` |
| Router (navigation intent) assertion | `PostListViewModelTests` |
| Whole-state comparison via `Equatable` | `PostListViewModelTests` |
| ViewAction that chains into an API request (annotated, slow) | `PostListViewModelTests.didFilterUser` |
| Parameterised tests / `#require` / `confirmation` | 🚫 — optional techniques; the demo's tests don't need them |

## Concurrency — `swift-concurrency`

| Rule | Demonstrated in |
|---|---|
| Whole demo compiles under **Swift 6 language mode**, `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_APPROACHABLE_CONCURRENCY: YES` | `project.yml` — zero errors, zero warnings |
| `@MainActor` ViewModels + `Sendable` Action enums survive complete checking | all `*ViewModel.swift` |
| `nonisolated(unsafe)` escape hatch with a written justification | `AppRouter.swift` (associated-object key) |
| `@concurrent` / `Task.detached` / `actor` / `nonisolated` computation | 🚫 — no demo screen has work heavy enough to leave the main actor; inventing one would be decoration. Validated by `Experiments/` and external references instead |
| Module-default `MainActor` isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION`) | ❌ — deliberately not enabled; see `TODO.md`, it would change the VM-layer rule |

> Last verified **2026-09** on Swift 6.4 / Xcode 27.0 RC, iOS 27.0 simulator: build clean, `14 tests in 3 suites passed`. The first row is the one that decays on a toolchain bump, so it carries a date — a "zero warnings" claim is only ever true of a specific compiler.
>
> Until 2026-08 the demo built with `SWIFT_STRICT_CONCURRENCY: targeted` and no explicit `SWIFT_VERSION` — meaning this repo claimed Swift 6.2+ while never actually having its Swift 6 compatibility checked by a compiler. It now builds clean in full Swift 6 mode, and that took zero source changes.
