# ViewModel Templates Reference

> ℹ️ **本檔是節錄的示意，不是 demo 的副本。** 這裡的程式碼刻意比 `Sources/` 短——省略 `+Models` / `+APIs` 的拆檔、只留下與本節規則相關的 case。**不要**把它「同步」成與 demo 逐字一致，那會讓範本變成第二份要維護的實作。
>
> 唯一逐字複製 demo 的是 `mvvmc-navigation/references/navigation-templates.md`（那份由 `Sources/App/` 產生，並附帶落後檢查）。兩者契約不同，別套錯。

## 基本版（無業務邏輯，純展示）

```swift
@Observable
@MainActor
final class FeatureViewModel {
    var state: State = .init()
}
```

---

## 帶 Action 分層版

> 這是簡化示範，只有 `view` + `apiRequest` 兩個 case，`handleAPIRequest` 內留空殼。實務上多數有 API 的頁面應走完 request → response 三層（View → `apiRequest` → `apiResponse` → 更新 state），完整寫法見下方「完整分層版」。

```swift
@Observable
@MainActor
final class FeatureViewModel {
    enum Action: Sendable {
        case view(ViewAction)
        case apiRequest(APIRequest)
    }

    var state: State = .init()

    func doAction(_ action: Action) async {
        switch action {
        case let .view(action): await handleViewAction(action)
        case let .apiRequest(request): await handleAPIRequest(request)
        }
    }
}

extension FeatureViewModel {
    enum ViewAction: Sendable {
        case isFirstAppear
        case pullToRefresh
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .isFirstAppear:
            guard state.isFirstAppear else { return }
            state.isFirstAppear = false
            await doAction(.apiRequest(.fetchItems))
        case .pullToRefresh:
            await doAction(.apiRequest(.fetchItems))
        }
    }
}

extension FeatureViewModel {
    enum APIRequest: Sendable {
        case fetchItems
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .fetchItems:
            // 呼叫 API...
        }
    }
}
```

---

## 完整分層版（ViewAction + APIRequest + APIResponse + onRoute）

```swift
@Observable
@MainActor
final class PostListViewModel {
    enum Action: Sendable {
        case view(ViewAction)
        case apiRequest(APIRequest)
        case apiResponse(APIResponse)
    }

    var state: State = .init()

    @ObservationIgnored
    var onRoute: (@MainActor (Router) -> Void)?

    func doAction(_ action: Action) async {
        switch action {
        case let .view(action): await handleViewAction(action)
        case let .apiRequest(request): await handleAPIRequest(request)
        case let .apiResponse(response): await handleAPIResponse(response)
        }
    }
}

// MARK: - ViewAction

extension PostListViewModel {
    enum ViewAction: Sendable {
        case isFirstAppear
        case pullToRefresh
        case postDidTap(Post)
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .isFirstAppear:
            guard state.isFirstAppear else { return }
            state.isFirstAppear = false
            await doAction(.apiRequest(.fetchPosts))
        case .pullToRefresh:
            await doAction(.apiRequest(.fetchPosts))
        case let .postDidTap(post):
            onRoute?(.toDetail(post))
        }
    }
}

// MARK: - Router

extension PostListViewModel {
    enum Router: Equatable, Sendable {
        case toDetail(Post)
    }
}

// MARK: - APIRequest

extension PostListViewModel {
    enum APIRequest: Sendable {
        case fetchPosts
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .fetchPosts:
            let result = await PostAPI.fetchPosts()
            await doAction(.apiResponse(.fetchPostsDidFinish(result)))
        }
    }
}

// MARK: - APIResponse

extension PostListViewModel {
    enum APIResponse: Sendable {
        case fetchPostsDidFinish([Post])
    }

    private func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case let .fetchPostsDidFinish(posts):
            state.posts = posts
        }
    }
}
```

---

## onCallback 版（Modal 回傳）

```swift
@Observable
@MainActor
final class PostFilterViewModel {
    enum Action: Sendable {
        case view(ViewAction)
    }

    var state: State = .init()

    @ObservationIgnored
    var onCallback: (@MainActor (Callback) async -> Void)?

    func doAction(_ action: Action) async {
        switch action {
        case let .view(action): await handleViewAction(action)
        }
    }
}

extension PostFilterViewModel {
    enum ViewAction: Sendable {
        case didSelectUser(User)
        case cancel
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case let .didSelectUser(user):
            // payload 傳 primitive：父層不需要認識本 feature 的 User 型別
            await onCallback?(.didSelectUser(id: user.id))
        case .cancel:
            await onCallback?(.didCancel)
        }
    }
}

extension PostFilterViewModel {
    enum Callback: Equatable, Sendable {
        case didSelectUser(id: Int)
        case didCancel
    }
}
```

### 父 HostController 端設定（不用包 Task）

子 VM 用 `await onCallback?(...)` 把結果往上拋，父 HostController 只要設定 `childViewModel.onCallback` 即可接收。因為 `onCallback` 本身是 `async` 閉包，父端可以直接在裡面 `await self.viewModel.doAction(...)`，**不需要另外包一層 `Task`**——這正是 async callback 設計省下的東西：async 沿著 `doAction` 自然往上傳播，呼叫端不必手動管理 Task 生命週期。

```swift
// 父 HostController — 不需要 Task
filterViewModel.onCallback = { [weak self] callback in
    guard let self else { return }
    switch callback {
    case let .didSelectUser(id):
        AppRouter.shared.back(from: self)
        await self.viewModel.doAction(.view(.didFilterUser(id)))
    case .didCancel:
        AppRouter.shared.back(from: self)
    }
}
```
