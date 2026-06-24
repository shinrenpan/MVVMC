# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A personal MVVMC architecture guideline, continuously evolved through discussion, refinement, and demo validation. MVVMC is a custom iOS architecture pattern designed for personal and team use.

> **Related repo**: [MVVMC-Skip](https://github.com/shinrenpan/MVVMC-Skip) is a cross-platform variant via Skip.tools. It evolves the C layer (HostController → SwiftUI Router) to drop the UIKit dependency. The rules in this file describe the **UIKit-nav (pure iOS) variant** of MVVMC; MVVMC-Skip has its own CLAUDE.md with the Plan E (pure-SwiftUI) variant rules.

---

## Architecture: MVVMC

Four strictly separated layers. SwiftUI + UIKit hybrid. iOS 17+.

| Layer | File | Responsibility |
|---|---|---|
| M | `FeatureViewModel+Models.swift` | State / Domain Models / DTOs |
| VM | `FeatureViewModel.swift` + `FeatureViewModel+APIs.swift` | `@Observable @MainActor`, single `doAction` entry point |
| V | `FeatureView.swift` | Pure SwiftUI, zero navigation logic |
| C | `FeatureHostController.swift` | UIKit bridge, sole owner of routing |

### Creation Order

M → VM → V → C

### File Structure

```
Pages/FeatureName/
├── FeatureNameViewModel+Models.swift   ← M
├── FeatureNameViewModel.swift          ← VM
├── FeatureNameViewModel+APIs.swift     ← VM (endpoint definitions, optional)
├── FeatureNameView.swift               ← V
├── FeatureNameMocks.swift              ← Mock (#if DEBUG, optional)
└── FeatureNameHostController.swift     ← C
```

---

## Layer Rules

### M — Models

Three blocks: **State / Domain Models / DTOs**. Not all required, but each block must be in its own `extension`.

| Block | Abstraction | Consumer |
|---|---|---|
| `State` | UI state | SwiftUI View, direct binding |
| `Domain Models` | Business semantics | ViewModel logic, State |
| `DTOs` | Raw API data | Network layer, mapped immediately after decoding |

- `State` is a `struct` conforming to `Sendable`; all fields have default values
- DTO is a `Codable & Sendable` struct; preserves all API response fields faithfully
- DTO property names match API response keys directly (e.g. `user_id`, `created_at`); no `CodingKeys` needed
- DTO provides `toDomain()` to convert to Domain Model; field selection is `toDomain()`'s responsibility, not the DTO's
- State never holds DTOs; the UI layer is completely unaware of DTOs

```swift
// MARK: - State
extension FeatureViewModel {
  struct State: Sendable {
    var items: [Item] = []
  }
}

// MARK: - Domain Models
extension FeatureViewModel {
  struct Item: Identifiable, Sendable {
    let id: String
    var name: String
  }
}

// MARK: - DTOs
extension FeatureViewModel {
  struct ItemDTO: Codable, Sendable {
    var item_id: String
    var item_name: String

    func toDomain() -> Item? {
      guard !item_id.isEmpty else { return nil }
      return .init(id: item_id, name: item_name)
    }
  }
}
```

### VM — ViewModel

- `@MainActor @Observable final class`
- Single entry point: `func doAction(_ action: Action) async`, dispatches via `switch` only
- `Action` enum structure (adapt as needed):

```swift
enum Action: Sendable {
  case view(ViewAction)             // user interactions from View
  case apiRequest(APIRequest)       // trigger API calls
  case apiResponse(APIResponse)     // handle API responses, update state
}
```

- `onRoute` — set by HostController (sync); handles navigation events
- `onCallback` — set by parent HostController (async); receives cross-VC return values
- VM never navigates itself; always calls `onRoute?(.toXxx)` and lets C handle it
- Cross-VC callbacks: call `await onCallback?(.xxx)` inside `doAction`; async propagates naturally, no extra `Task` needed in HostController
- Non-UI properties (closures, etc.) marked `@ObservationIgnored`

```swift
// ViewModel
@ObservationIgnored var onRoute: (@MainActor (Router) -> Void)?
@ObservationIgnored var onCallback: (@MainActor (Callback) async -> Void)?

// inside doAction handler
case .didSelectItem(let item):
  await onCallback?(.didSelectItem(item))
```

```swift
// parent HostController — no Task needed
childViewModel.onCallback = { [weak self] callback in
  guard let self else { return }
  switch callback {
  case .didSelectItem(let item):
    AppRouter.shared.back(from: self)
    await self.viewModel.doAction(.view(.itemSelected(item)))
  }
}
```

### V — View

- Hold `viewModel` with `let` (`@Observable` tracks automatically; no `@State` or `@Bindable`)
- All user interactions: `Task { await viewModel.doAction(.view(.xxx)) }`
- Sub-views: `private extension FeatureView { struct SubView: View {...} }`
- Sub-views that need to return actions receive: `let doAction: @MainActor (Action) -> Void`
- Display helpers for models go at the top of the View file: `private extension FeatureViewModel.SomeModel { var color: Color { ... } }`
- **Zero navigation logic, zero business logic**

### C — HostController

- `@MainActor final class` subclassing `UIHostingController<FeatureView>`
- **Pure router**: all navigation via `AppRouter.shared`; never call `navigationController` / `present` / `dismiss` directly
- `viewDidLoad`: set up `viewModel.onRoute` and `onCallback`
- HostController does not manage lifecycle triggers and holds no Tasks
- Use `[weak self]` in closures; ViewModel lifetime matches HostController, no manual nil cleanup needed
- To receive child VC callbacks: set `childViewModel.onCallback` before navigating

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {
  private let viewModel: FeatureViewModel

  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    super.init(rootView: FeatureView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }
}
```

---

## Data Flow

```
User interaction
  → View: Task { await viewModel.doAction(.view(.xxx)) }
  → VM handleViewAction → doAction(.apiRequest(...))

API request:
  → VM handleAPIRequest → call API → doAction(.apiResponse(...))
  → VM handleAPIResponse → update state → View refreshes automatically

Navigation:
  → VM: onRoute?(.toXxx)
  → HostController → AppRouter.shared.to(vc, from: self)

Cross-VC callback:
  → child VM: onCallback?(.xxx)
  → parent HostController → AppRouter.shared.back(from: self) → handle result
```

---

## AppRouter

`AppRouter.shared` is the single navigation entry point. Push/pop is backed by `UINavigationController`; sheets use system `present`/`dismiss` but share the same interface — HostControllers always call `AppRouter.shared.back()`, never `dismiss` directly.

- **Stateless**: holds no stored properties; nav controller is resolved dynamically from `source.navigationController`
- **assertionFailure**: nil `source.navigationController` means a developer setup error; crashes immediately in Debug
- **Transitions**: implemented via `UINavigationControllerDelegate`; supports `.modal` (slide up) and `.fade`

```swift
// Push (default, native swipe-back)
AppRouter.shared.to(DetailHostController(...), from: self)

// Push with custom transition
AppRouter.shared.to(FilterHostController(...), from: self, style: .modal)
AppRouter.shared.to(SomeHostController(...), from: self, style: .fade)

// Sheet (large detent by default; destination decides whether to wrap in UINavigationController)
AppRouter.shared.sheet(SomeHostController(...), from: self)
AppRouter.shared.sheet(UINavigationController(rootViewController: SettingsHostController(...)), from: self)
AppRouter.shared.sheet(SomeHostController(...), from: self, detents: [.medium()])
AppRouter.shared.sheet(SomeHostController(...), from: self, detents: [.medium(), .large()])

// Back (auto-detects: sheet → dismiss, otherwise → pop)
AppRouter.shared.back(from: self)
AppRouter.shared.backTo(targetVC, from: self)
AppRouter.shared.backToRoot(from: self)

// Tab switch
AppRouter.shared.tab(1, from: self)

// Deeplink (fullScreen present from rootVC, auto-injects Close button, no from: needed)
AppRouter.shared.deeplink(SomeHostController(...))
```

`SceneDelegate` setup:

```swift
let nav = UINavigationController(rootViewController: ...)
window.rootViewController = nav
window.backgroundColor = .systemBackground  // prevents black background during transitions
```

AppRouter sets `nav.delegate` and gesture handling automatically on the first `to()` call.

---

## Deeplink / Push Notification

### Deeplink enum

All deeplink knowledge lives in `Sources/App/Deeplink.swift`: URL parsing + VC creation. Adding a new target only requires editing this one file.

```swift
enum Deeplink {
  case settings
  case postDetail(id: Int)

  init?(url: URL) {
    guard url.scheme == "mvvmc" else { return nil }
    switch url.host {
    case "settings": self = .settings
    case "posts":
      guard let id = url.pathComponents.dropFirst().first.flatMap(Int.init) else { return nil }
      self = .postDetail(id: id)
    default: return nil
    }
  }

  @MainActor func makeHostController() -> UIViewController {
    switch self {
    case .settings:           return SettingsHostController(viewModel: .init())
    case let .postDetail(id): return PostDetailHostController(id: id, ...)
    }
  }
}
```

### Three SceneDelegate entry points

```swift
// Foreground / background → URL Scheme
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url,
          let deeplink = Deeplink(url: url) else { return }
    AppRouter.shared.deeplink(deeplink.makeHostController())
}

// Cold start → URL Scheme
// Call after makeKeyAndVisible() to ensure rootVC exists
if let url = connectionOptions.urlContexts.first?.url,
   let deeplink = Deeplink(url: url) {
    AppRouter.shared.deeplink(deeplink.makeHostController())
}

// Push notification tap (all app states) → nonisolated, hop back to main via Task
nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    defer { completionHandler() }
    guard let urlString = response.notification.request.content.userInfo["deeplink"] as? String,
          let url = URL(string: urlString),
          let deeplink = Deeplink(url: url) else { return }
    Task { @MainActor in AppRouter.shared.deeplink(deeplink.makeHostController()) }
}
```

### Push payload convention

```json
{ "deeplink": "mvvmc://settings" }
{ "deeplink": "mvvmc://posts/1" }
```

Reuses `Deeplink(url:)` directly; no separate parsing logic needed.

### URL Scheme (project.yml)

```yaml
CFBundleURLTypes:
  - CFBundleURLName: com.your.bundle.id
    CFBundleURLSchemes:
      - mvvmc
```

---

## Common Patterns

### Run once (viewDidLoad equivalent)

**Problem**: SwiftUI's `.onAppear` / `.task` fires every time the view appears; there's no native `viewDidLoad` equivalent.

**Solution**: `isFirstAppear` and `pullToRefresh` are two semantically distinct ViewActions, both routing to the same APIRequest.

```swift
enum ViewAction: Sendable {
  case isFirstAppear
  case pullToRefresh
}

enum APIRequest: Sendable {
  case loadData
}
```

```swift
// View
.task {
  await viewModel.doAction(.view(.isFirstAppear))
}

.refreshable {
  await viewModel.doAction(.view(.pullToRefresh))
}
```

```swift
// ViewModel
case .isFirstAppear:
  guard state.isFirstAppear else { return }
  state.isFirstAppear = false
  await doAction(.apiRequest(.loadData))

case .pullToRefresh:
  await doAction(.apiRequest(.loadData))
```

- `isFirstAppear` communicates run-once semantics by name
- `loadData` stays clean with no lifecycle assumptions
- View never touches State directly; ViewModel remains the sole owner

---

## Mock / Preview

```swift
// FeatureNameMocks.swift — entire file wrapped in #if DEBUG
#if DEBUG
extension FeatureViewModel.SomeDomainModel {
  static let mock: Self = .init(...)
  static let mocks: [Self] = [...]
}
#endif

// Preview at bottom of View file
#if DEBUG
#Preview("description") {
  let vm = FeatureViewModel()
  vm.state.items = .mocks
  return FeatureView(viewModel: vm)
}
#endif
```
