# Spec Coverage

Maps each load-bearing rule to the demo file that proves it compiles.

`Sources/` and `Tests/` are the spec's **compile-time test**: a rule no demo file exercises has never been checked by a compiler. When you change a rule in `.claude/skills/`, update the demo and this table in the same pass — that is how the spec and the demo stay in sync.

Legend: ✅ demonstrated · ❌ not demonstrated (candidate work, not necessarily a defect)

---

## M — `mvvmc-model`

| Rule | Demonstrated in |
|---|---|
| State / Domain Models / DTOs in separate `extension` blocks | `PostList/PostListViewModel+Models.swift` |
| `State` is `Equatable, Sendable`, every field defaulted | all six `*ViewModel+Models.swift` |
| Detail-view exception: `let post` with no parameterless `init()` | `PostDetail/PostDetailViewModel+Models.swift` |
| Field-type blacklist — UI state container is legal | `PostList` / `UserDetail` (`var api: API`) |
| Domain Model is `Identifiable` when it has an `id` | `PostList.Post`, `PostFilter.User` |
| DTO property names mirror API keys 1:1, no `CodingKeys` | `PostList.PostDTO` (`user_id`) |
| `toDomain()` filters invalid rows (returns `Optional`) | `UserDetail.UserDTO` |
| DTO does **not** conform to `Equatable` | all DTOs |
| Mocks hang off Domain Models, whole file `#if DEBUG` | `PostList/PostListMocks.swift`, `PostDetail/PostDetailMocks.swift` |
| L2 nested type with parent prefix (`OrderStatus` style) | ❌ |
| Equatable exceptions (closure member / fire-and-forget / large blob) | ❌ — edge cases, may stay undemonstrated |

## VM — `mvvmc-viewmodel`

| Rule | Demonstrated in |
|---|---|
| `@Observable @MainActor final class` | all six `*ViewModel.swift` |
| `doAction(_:)` as the single entry point, `switch` dispatch only | same |
| Three-layer Action (`view` / `apiRequest` / `apiResponse`) | `PostList`, `UserDetail` |
| `onRoute` set by HostController, `@ObservationIgnored` | `PostListViewModel.swift` |
| `onCallback` async closure for cross-VC results | `PostFilterViewModel.swift` |
| Run once: `isFirstAppear` + guard | `PostList`, `UserDetail` |
| Run once: `pullToRefresh` sharing the same APIRequest | ❌ — demo has no `.refreshable` |
| Network layer is out of scope (endpoint layout is one option) | `PostList/PostListViewModel+APIs.swift` |

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
| Preview injects mock state, wrapped in `#if DEBUG` | `PostListView`, `UserDetailView` |
| `@Bindable` inside `body` for a `TextField` binding | ❌ — demo has no text input |
| Display helper (`private extension Model { var color: Color }`) | ❌ |
| Slot pattern (`@ViewBuilder` container) | ❌ |
| `ForEach` + child `@State` identity trap | ❌ — no child holds `@State` |

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
| `sheet()` with custom `detents` | ❌ |
| `back()` auto-detecting sheet → dismiss | `PostFilter`, `Settings` |
| `backTo()` / `backToRoot()` | ❌ |
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

## Concurrency — `swift-concurrency`

Not exercised: the demo's only async work is a `Task.sleep` stub in `*ViewModel+APIs.swift`. There is no `@concurrent`, `Task.detached`, `actor`, or `nonisolated` computation to compile-check. Rules in that skill are validated against external references, not this demo.
