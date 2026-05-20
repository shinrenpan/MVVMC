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
      let detailVC = DetailHostController(viewModel: .init(item: item))
      navigationController?.pushViewController(detailVC, animated: true)
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
      let detailVC = PostDetailHostController(viewModel: .init(post: post))
      navigationController?.pushViewController(detailVC, animated: true)

    case .toFilter:
      let filterVM = PostFilterViewModel()
      filterVM.onCallback = { [weak self] callback in
        await self?.handleFilterCallback(callback)
      }
      let filterVC = PostFilterHostController(viewModel: filterVM)
      present(filterVC, animated: true)
    }
  }

  func handleFilterCallback(_ callback: PostFilterViewModel.Callback) async {
    switch callback {
    case let .didSelectUser(user):
      await viewModel.doAction(.view(.didFilterUser(user.id)))
    case .didCancel:
      break
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
| present 前未設定 `onCallback` | 設定後再 present | present 後子 VC 可能立即觸發 callback |
| `required init?(coder:)` 未標 unavailable | 加上 `@available(*, unavailable)` | 防止 Storyboard 誤用 |
| `onCallback` closure 包 `Task` | `onCallback` 是 async，直接 `await` | async closure 不需要包 Task |
| `viewDidDisappear` 設 `onRoute = nil` | 不需要 | ViewModel 由 HostController 持有，`[weak self]` 已足夠 |
| HostController 啟動 Task 觸發 ViewModel | View 的 `.task` 負責 Lifecycle | HostController 是純 Router |
