# ViewModel Templates Reference

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
    enum Router: Sendable {
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
            await onCallback?(.didSelectUser(user))
        case .cancel:
            await onCallback?(.didCancel)
        }
    }
}

extension PostFilterViewModel {
    enum Callback: Sendable {
        case didSelectUser(User)
        case didCancel
    }
}
```
