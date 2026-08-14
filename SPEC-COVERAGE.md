# Spec Coverage

Maps each load-bearing rule to the demo file that proves it compiles.

`Sources/` and `Tests/` are the spec's **compile-time test**: a rule no demo file exercises has never been checked by a compiler. When you change a rule in `.claude/skills/`, update the demo and this table in the same pass — that is how the spec and the demo stay in sync.

Legend: ✅ demonstrated · ❌ not demonstrated · 🚫 deliberately not demonstrated

**❌ vs 🚫**: ❌ means the demo *could* show it and doesn't — those are candidate work, listed in `TODO.md`. 🚫 means demonstrating it would require bending the demo out of shape (inventing a feature, adding a navigation level, or breaking an existing demonstration). A 🚫 rule is validated by reasoning and by other projects, not by this demo — and that is a deliberate trade, because a demo that shows everything stops showing anything clearly.

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

## M — `mvvmc-model`

| Rule | Demonstrated in |
|---|---|
| State / Domain Models / DTOs in separate `extension` blocks | `PostList/PostListViewModel+Models.swift` |
| `State` is `Equatable, Sendable`, every field defaulted | all six `*ViewModel+Models.swift` |
| Detail-view exception: `let post` with no parameterless `init()` | `PostDetail/PostDetailViewModel+Models.swift` |
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

## V — `mvvmc-view`

| Rule | Demonstrated in |
|---|---|
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
| `ForEach` + child `@State` identity trap | 🚫 — showing the trap means shipping the anti-pattern the spec tells you to avoid |

## C — `mvvmc-hostcontroller`

| Rule | Demonstrated in |
|---|---|
| `@MainActor final class : UIHostingController<FeatureView>` | all six `*HostController.swift` |
| Standard init: ViewModel injected from outside | `PostListHostController.swift` |
| Variant: primitives in, ViewModel assembled inside C | `PostDetailHostController.swift` |
| `viewDidLoad` wires `viewModel.onRoute` with `[weak self]` | `PostListHostController.swift` |
| Routing centralised in `handleRouter(_:)` in a `private extension` | same |
| Child `onCallback` set before navigating, no `Task` wrapper | `PostListHostController.swift` → `PostFilter` |
| `required init?(coder:)` marked `@available(*, unavailable)` | all |

## Navigation — `mvvmc-navigation`

| Rule | Demonstrated in |
|---|---|
| Stateless `AppRouter`, nav resolved from `source.navigationController` | `Sources/App/AppRouter.swift` |
| `to()` with `.push` / `.modal` / `.fade` | `PostList` → `PostFilter` (modal), `UserDetail` (fade) |
| `sheet()` | `Settings` |
| `sheet()` with custom `detents` | `Profile` → `Settings` (`[.medium(), .large()]`) |
| `back()` auto-detecting sheet → dismiss | `PostFilter`, `Settings` |
| `backTo()` / `backToRoot()` | 🚫 — the demo's deepest stack is two levels, where these are indistinguishable from `back()` |
| `tab()` | `Profile` |
| `deeplink()` with injected Close button | `Sources/App/Deeplink.swift` |
| Three SceneDelegate entry points (foreground / cold start / push) | `Sources/App/SceneDelegate.swift` |
| Swipe-back gating to `.push` pages only | `AppRouter.gestureRecognizerShouldBegin` |
| `window.backgroundColor` set | `SceneDelegate.swift` |

## Testing — `mvvmc-testing`

| Rule | Demonstrated in |
|---|---|
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

> Until 2026-08 the demo built with `SWIFT_STRICT_CONCURRENCY: targeted` and no explicit `SWIFT_VERSION` — meaning this repo claimed Swift 6.2+ while never actually having its Swift 6 compatibility checked by a compiler. It now builds clean in full Swift 6 mode, and that took zero source changes.
