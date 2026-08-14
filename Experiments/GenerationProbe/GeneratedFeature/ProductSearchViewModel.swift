//
//  ProductSearchViewModel.swift
//  VM — @Observable + @MainActor + final class，doAction 單一進入點
//

import Foundation

@Observable
@MainActor
final class ProductSearchViewModel {
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

extension ProductSearchViewModel {
    enum ViewAction: Sendable {
        case isFirstAppear
        case pullToRefresh
        case categoryDidTap(Category.ID)
        case categoryRetryDidTap
        case productDidTap(Product)
        case productRetryDidTap
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .isFirstAppear:
            guard state.isFirstAppear else { return }
            state.isFirstAppear = false
            await loadAll()

        case .pullToRefresh:
            await loadAll()

        case let .categoryDidTap(id):
            // 再點一次同一個分類 = 取消篩選
            state.selectedCategoryID = state.selectedCategoryID == id ? nil : id

        case .categoryRetryDidTap:
            await doAction(.apiRequest(.fetchCategories))

        case let .productDidTap(product):
            onRoute?(.toDetail(product))

        case .productRetryDidTap:
            await doAction(.apiRequest(.fetchProducts))
        }
    }

    /// 兩支 API 同時發出、各自 dispatch 回自己的 .apiResponse。
    /// 數量固定 → async let（見 swift-concurrency〈同時執行多個任務〉）
    private func loadAll() async {
        async let categories: Void = doAction(.apiRequest(.fetchCategories))
        async let products: Void = doAction(.apiRequest(.fetchProducts))

        _ = await (categories, products)
    }
}

// MARK: - Router

extension ProductSearchViewModel {
    enum Router: Sendable {
        case toDetail(Product)
    }
}

// MARK: - APIRequest

extension ProductSearchViewModel {
    enum APIRequest: Sendable {
        case fetchCategories
        case fetchProducts
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .fetchCategories:
            state.api.fetchCategories = .loading

            do {
                let dtos = try await ProductSearchAPI.fetchCategories()
                await doAction(.apiResponse(.fetchCategoriesDidFinish(.success(dtos))))
            }
            catch {
                await doAction(
                    .apiResponse(.fetchCategoriesDidFinish(.failure(.message(error.localizedDescription))))
                )
            }

        case .fetchProducts:
            state.api.fetchProducts = .loading

            do {
                let dtos = try await ProductSearchAPI.fetchProducts()
                await doAction(.apiResponse(.fetchProductsDidFinish(.success(dtos))))
            }
            catch {
                await doAction(
                    .apiResponse(.fetchProductsDidFinish(.failure(.message(error.localizedDescription))))
                )
            }
        }
    }
}

// MARK: - APIResponse

extension ProductSearchViewModel {
    enum APIResponse: Sendable {
        case fetchCategoriesDidFinish(Result<[CategoryDTO], APIError>)
        case fetchProductsDidFinish(Result<[ProductDTO], APIError>)
    }

    private func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case let .fetchCategoriesDidFinish(.success(dtos)):
            state.categories = toCategories(dtos)
            // 選中的分類若已從新資料消失，篩選條件必須跟著失效，否則列表會永遠空白
            if let selected = state.selectedCategoryID,
               !state.categories.contains(where: { $0.id == selected }) {
                state.selectedCategoryID = nil
            }
            state.api.fetchCategories = .success

        case let .fetchCategoriesDidFinish(.failure(.message(message))):
            state.api.fetchCategories = .error(message)

        case let .fetchProductsDidFinish(.success(dtos)):
            state.products = toProducts(dtos)
            state.api.fetchProducts = .success

        case let .fetchProductsDidFinish(.failure(.message(message))):
            state.api.fetchProducts = .error(message)
        }
    }
}

// MARK: - Mapping（純運算，不需要 MainActor）

private extension ProductSearchViewModel {
    nonisolated func toCategories(_ dtos: [CategoryDTO]) -> [Category] {
        dtos.compactMap { $0.toDomain() }
    }

    nonisolated func toProducts(_ dtos: [ProductDTO]) -> [Product] {
        dtos.compactMap { $0.toDomain() }
    }
}
