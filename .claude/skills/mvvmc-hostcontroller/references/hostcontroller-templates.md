# HostController Templates

詳細模板與進階情境參考。

---

## Template 1：最簡版（無 Router）

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {

  private let viewModel: FeatureViewModel

  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    super.init(rootView: FeatureView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
```

---

## Template 2：帶 Router

```swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {

  private let viewModel: FeatureViewModel

  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    super.init(rootView: FeatureView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }
}

private extension FeatureHostController {
  func handleRouter(_ router: FeatureViewModel.Router) {
    switch router {
    case let .toDetail(item):
      AppRouter.shared.to(DetailHostController(id: item.id), from: self)
    }
  }
}
```

---

## Template 3：帶 Router + Callback（Modal）

```swift
@MainActor
final class PostListHostController: UIHostingController<PostListView> {

  private let viewModel: PostListViewModel

  init(viewModel: PostListViewModel) {
    self.viewModel = viewModel
    super.init(rootView: PostListView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }
}

private extension PostListHostController {
  func handleRouter(_ router: PostListViewModel.Router) {
    switch router {
    case let .toDetail(post):
      AppRouter.shared.to(PostDetailHostController(id: post.id, title: post.title, body: post.body), from: self)

    case .toFilter:
      let filterVM = PostFilterViewModel()
      filterVM.onCallback = { [weak self] callback in
        guard let self else { return }
        switch callback {
        case let .didSelectUser(id):
          AppRouter.shared.back(from: self)
          await self.viewModel.doAction(.view(.didFilterUser(id)))
        case .didCancel:
          AppRouter.shared.back(from: self)
        }
      }
      AppRouter.shared.to(PostFilterHostController(viewModel: filterVM), from: self, style: .modal)
    }
  }
}
```

---

## 常見錯誤對照表

| ❌ 錯誤寫法 | ✅ 正確寫法 | 原因 |
|------------|------------|------|
| 缺少 `@MainActor` | `@MainActor final class ...` | SwiftUI + UIKit 橋接必須在主執行緒 |
| `viewModel` 非 `private let` | `private let viewModel` | HostController 持有，外部無需存取 |
| closure 未用 `[weak self]` | `{ [weak self] router in` | 避免循環引用 |
| ViewModel 直接做 `push` | 透過 `onRoute?(.toXxx)` 轉發 | ViewModel 不應持有 UIKit 依賴 |
| `navigationController?.pushViewController` | `AppRouter.shared.to(..., from: self)` | 所有導航統一走 AppRouter |
| `present(vc, animated:)` / `dismiss` | `AppRouter.shared.to(..., style: .modal)` / `AppRouter.shared.back(from: self)` | 所有導航統一走 AppRouter |
| callback 內未 `guard let self` | `guard let self else { return }` | 避免 optional chaining |
| callback 內用 `dismiss` 返回 | `AppRouter.shared.back(from: self)` | 統一 pop，不使用 dismiss |
| `onCallback` closure 包 `Task` | `onCallback` 是 async，直接 `await` | async closure 不需要包 Task |
| `viewDidDisappear` 設 `onRoute = nil` | 不需要 | ViewModel 由 HostController 持有，`[weak self]` 已足夠 |
| HostController 啟動 Task 觸發 ViewModel | View 的 `.task` 負責 Lifecycle | HostController 是純 Router |
