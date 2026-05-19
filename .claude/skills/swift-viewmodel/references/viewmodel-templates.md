# ViewModel Templates Reference

## 基本版

```swift
@Observable
@MainActor
final class FeatureViewModel: ViewModel {
    enum Action: Sendable {}

    var state: State = .init()

    func doAction(_ action: Action) async {}
}
```

---

## 帶單層 Action 版

```swift
@Observable
@MainActor
final class FeatureViewModel: ViewModel {
    enum Action: Sendable {
        case apiRequest(APIRequest)
    }

    var state: State = .init()

    func doAction(_ action: Action) async {
        switch action {
        case let .apiRequest(request):
            await handleAPIRequest(request)
        }
    }
}

private extension FeatureViewModel {
    enum APIRequest: Sendable {
        case getInfo
    }

    func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .getInfo:
            await handleGetInfo()
        }
    }

    func handleGetInfo() async { ... }
}
```

---

## 帶 onAction / onCallback 版

```swift
@Observable
@MainActor
final class FeatureViewModel: ViewModel {
    enum Action: Sendable { ... }

    var state: State = .init()

    @ObservationIgnored
    var onAction: (@MainActor (Action) -> Void)?

    @ObservationIgnored
    var onCallback: (@MainActor (Action) -> Void)?

    func doAction(_ action: Action) async { ... }
}
```

---

## 完整分層版（ViewAction → Router → APIRequest → APIResponse）

```swift
@Observable
@MainActor
final class ProductListViewModel: ViewModel {
    enum Action: Sendable {
        case view(ViewAction)
        case router(Router)
        case apiRequest(APIRequest)
        case apiResponse(APIResponse)
    }

    var state: State = .init()

    @ObservationIgnored
    var onAction: (@MainActor (Action) -> Void)?

    func doAction(_ action: Action) async {
        switch action {
        case let .view(action):
            await handleViewAction(action)
        case let .router(route):
            onAction?(.router(route))
        case let .apiRequest(request):
            await handleAPIRequest(request)
        case let .apiResponse(response):
            await handleAPIResponse(response)
        }
    }
}

// MARK: - ViewAction

private extension ProductListViewModel {
    enum ViewAction: Sendable {
        case onAppear
        case refreshDidTap
        case itemDidTap(Product)
    }

    func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .onAppear, .refreshDidTap:
            await doAction(.apiRequest(.fetchProducts))
        case let .itemDidTap(product):
            await doAction(.router(.toDetail(product)))
        }
    }
}

// MARK: - Router

extension ProductListViewModel {
    enum Router: Sendable {
        case toDetail(Product)
    }
}

// MARK: - APIRequest

private extension ProductListViewModel {
    enum APIRequest: Sendable {
        case fetchProducts
    }

    func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .fetchProducts:
            await handleFetchProducts()
        }
    }

    func handleFetchProducts() async {
        state.isLoading = true
        defer { state.isLoading = false }
        // 呼叫 API，取得 response 後 dispatch APIResponse
        await doAction(.apiResponse(.fetchProductsDidFinish(...)))
    }
}

// MARK: - APIResponse

private extension ProductListViewModel {
    enum APIResponse: Sendable {
        case fetchProductsDidFinish([Product])
    }

    func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case let .fetchProductsDidFinish(products):
            state.products = products
        }
    }
}
```
