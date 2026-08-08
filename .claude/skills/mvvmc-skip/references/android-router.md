# Android Router 與 C 層範本

Android 沒有 `UINavigationController`，導航改由 SwiftUI 的 `NavigationStack(path:)` + `.sheet(item:)` 驅動。

**核心對稱關係**：C 層在兩個平台各有一份實作，但職責完全相同 —— 持有 VM、訂閱 `onRoute`、把導航意圖交給 `AppRouter.shared`。V / VM / M 三層完全共用。

| | iOS (`#if !SKIP`) | Android (`#else`) |
|---|---|---|
| C 層形態 | `final class: UIHostingController<View>` | `struct: View` |
| 持有 VM | `private let viewModel`（init 注入） | `@State private var viewModel` ⚠️ 必須 |
| 訂閱時機 | `viewDidLoad()` | `.onAppear { bindRouter() }` |
| closure 捕獲 | `[weak self]` | 強引用 ⚠️ 不要用 `[weak]` |
| 導航實作 | `UINavigationController` push/present | `NavigationStack` path 陣列 / sheet slot |

---

## AppRouter 的 `#else` 分支

放在 `Sources/<Module>/App/AppRouter.swift` 的 `#else` 區塊裡（與 iOS 版同檔，不另開檔案 —— 這些型別只有 Android 用得到，跟它們服務的 `AppRouter` 放一起）。

```swift
#else

import Observation
import SwiftUI

// MARK: - 導航型別

enum AppTab: Hashable, Sendable {
  case posts
  case profile
}

enum AppRoute: Hashable, Sendable {
  // ⚠️ 用 postId / userId，不要用 id —— 會與 Identifiable 合成的 id 衝突
  case postDetail(postId: Int, title: String, body: String)
  case userDetail(userId: Int)
}

extension AppRoute: Identifiable {
  // ⚠️ 寫具體型別，不要寫 Self
  var id: AppRoute { self }
}

/// 以 sheet 呈現的目的地。與 AppRoute 分開，因為 `.sheet(item:)` 與
/// `NavigationStack(path:)` 吃的是不同的 state slot。
enum SheetRoute: Hashable, Sendable, Identifiable {
  case settings
  case postFilter

  var id: SheetRoute { self }
}

// MARK: - AppRouter

@MainActor
@Observable
final class AppRouter {
  static let shared = AppRouter()
  private init() {}

  var tab: AppTab = .posts

  // 每個 tab 一個 path 陣列，綁到各自的 NavigationStack
  var postsPath: [AppRoute] = []
  var profilePath: [AppRoute] = []

  // 共用的 sheet slot
  var sheetRoute: SheetRoute?

  // 跨 feature 傳遞 VM 用（見下方「跨 feature callback」）
  var postFilterViewModel: PostFilterViewModel?

  // MARK: Path

  func push(_ route: AppRoute) {
    switch tab {
    case .posts:   postsPath.append(route)
    case .profile: profilePath.append(route)
    }
  }

  func popToCurrentRoot() {
    switch tab {
    case .posts:   postsPath.removeAll()
    case .profile: profilePath.removeAll()
    }
  }

  func switchTab(_ tab: AppTab) {
    self.tab = tab
  }

  // MARK: Sheet

  func presentSheet(_ route: SheetRoute) { sheetRoute = route }
  func dismissSheet() { sheetRoute = nil }
}

#endif
```

### iOS ↔ Android 呼叫對照

翻譯 `onRoute` 的 case 時對著這張表寫：

| iOS | Android |
|---|---|
| `AppRouter.shared.to(vc, from: self)` | `AppRouter.shared.push(.someRoute(...))` |
| `AppRouter.shared.to(vc, from: self, style: .modal)` | `AppRouter.shared.presentSheet(.someSheet)` |
| `AppRouter.shared.back(from: self)` | `AppRouter.shared.dismissSheet()`（sheet 情境） |
| `AppRouter.shared.backToRoot(from: self)` | `AppRouter.shared.popToCurrentRoot()` |
| `AppRouter.shared.tab(1, from: self)` | `AppRouter.shared.switchTab(.profile)` |

---

## Root View

放在 `Sources/<Module>/Android/AppEntry.swift`（整檔 `#if SKIP`）。對應 iOS 的 `UITabBarController` 結構。

```swift
public struct <Module>RootView: View {
  @Bindable private var appRouter = AppRouter.shared

  public init() {}

  public var body: some View {
    TabView(selection: $appRouter.tab) {
      NavigationStack(path: $appRouter.postsPath) {
        PostListHostController()
          .navigationDestination(for: AppRoute.self) { destinationView(for: $0) }
      }
      .tabItem { Label("Posts", systemImage: "list.bullet") }
      .tag(AppTab.posts)

      NavigationStack(path: $appRouter.profilePath) {
        ProfileHostController()
          .navigationDestination(for: AppRoute.self) { destinationView(for: $0) }
      }
      .tabItem { Label("Profile", systemImage: "person") }
      .tag(AppTab.profile)
    }
    .sheet(item: $appRouter.sheetRoute) { sheetView(for: $0) }
  }

  @ViewBuilder
  private func destinationView(for route: AppRoute) -> some View {
    switch route {
    case let .postDetail(postId, title, body):
      PostDetailHostController(id: postId, title: title, body: body)
    case let .userDetail(userId):
      UserDetailHostController(userId: userId)
    }
  }

  @ViewBuilder
  private func sheetView(for route: SheetRoute) -> some View {
    switch route {
    case .settings:
      NavigationStack { SettingsHostController() }   // 需要 nav bar 時包一層
    case .postFilter:
      PostFilterHostController()
    }
  }
}
```

💡 `navigationDestination` 要在**每個** NavigationStack 各掛一次 —— 它不會跨 stack 繼承。

---

## HostController `#else` 的三種形態

### 形態 A：無參數 + 需要導航

最常見。VM 自己建，訂閱 `onRoute`。

```swift
#else
import SwiftUI

@MainActor
struct SettingsHostController: View {
  @State private var viewModel = SettingsViewModel()

  var body: some View {
    SettingsView(viewModel: viewModel)
      .onAppear { bindRouter() }
  }

  private func bindRouter() {
    viewModel.onRoute = { router in      // ⚠️ 不要 [weak]
      switch router {
      case .close:
        AppRouter.shared.dismissSheet()
      }
    }
  }
}
#endif
```

### 形態 B：需要建構參數

VM 要參數時不能用 property 初始值，改在 `init` 裡種進 `@State`。

```swift
#else
import SwiftUI

@MainActor
struct UserDetailHostController: View {
  @State private var viewModel: UserDetailViewModel

  init(userId: Int) {
    self._viewModel = State(initialValue: UserDetailViewModel(userId: userId))
  }

  var body: some View {
    UserDetailView(viewModel: viewModel)
  }
}
#endif
```

💡 這個 feature 沒有 `onRoute`，所以不需要 `bindRouter()`。有的話照形態 A 補上。

💡 建構參數建議與 iOS 版 HostController 的 `init` 對齊（例如都用 `init(id:title:body:)`），這樣 root view 的呼叫慣例在兩邊讀起來一致。

### 形態 C：從 AppRouter 接手已設定好的 VM

用於「父 feature 建立子 VM、設好 `onCallback`、再呈現」的情境。iOS 是直接把 VM 傳進子 HostController 的 init；Android 因為 sheet 由 `AppRouter` 統一呈現，改成先寄放在 router 上。

```swift
#else
import SwiftUI

@MainActor
struct PostFilterHostController: View {
  @State private var viewModel: PostFilterViewModel

  init() {
    self._viewModel = State(
      initialValue: AppRouter.shared.postFilterViewModel ?? PostFilterViewModel()
    )
  }

  var body: some View {
    PostFilterView(viewModel: viewModel)
  }
}
#endif
```

---

## 跨 feature callback

iOS 的做法是：父 HostController 建立子 VM → 設 `onCallback` → 傳進子 HostController → `AppRouter.shared.to(...)`。

Android 少了「傳進 init」這一步（sheet 統一由 root view 建立），所以改成寄放在 `AppRouter`：

```swift
// PostListHostController 的 #else 分支
case .toFilter:
  let filterVM = PostFilterViewModel()
  filterVM.onCallback = { callback in          // ⚠️ 強引用
    switch callback {
    case let .didSelectUser(user):
      AppRouter.shared.dismissSheet()
      await viewModel.doAction(.view(PostListViewModel.ViewAction.didFilterUser(user.id)))
    case .showAll:
      AppRouter.shared.dismissSheet()
      await viewModel.doAction(.view(PostListViewModel.ViewAction.clearFilter))
    case .didCancel:
      AppRouter.shared.dismissSheet()
    }
  }
  AppRouter.shared.postFilterViewModel = filterVM   // ← 寄放
  AppRouter.shared.presentSheet(.postFilter)
```

⚠️ 這段 closure 裡的 `viewModel` **一定要強引用**。iOS 版寫 `[weak viewModel]` 是為了斷開 `HostController → onRoute → closure → self` 的循環；Kotlin 用 GC，沒有這個循環問題，但 `WeakReference` 會在巢狀 closure 的捕獲鏈中提早失效 —— 結果是 callback 有跑、`doAction` 卻靜默無效。這個 bug 不會有任何錯誤訊息。

💡 `doAction` 的參數同樣要套用眉角 #6 的完整限定。

---

## 檢查清單

移植一個 feature 的 C 層時逐項確認：

- [ ] `#else` 分支用 `@State` 持有 VM（否則 Compose 不會重繪）
- [ ] 有 `onRoute` 的話，`.onAppear { bindRouter() }` 有掛上
- [ ] 所有 closure 都是強引用，沒有殘留 `[weak]`
- [ ] `onRoute` 的每個 case 都翻譯過了，沒有漏掉的分支
- [ ] `doAction(.view(...))` 都加了完整型別限定
- [ ] root view 的 `destinationView` / `sheetView` 有加上這個 feature
- [ ] `AppRoute` 的 case 參數沒有叫 `id`
