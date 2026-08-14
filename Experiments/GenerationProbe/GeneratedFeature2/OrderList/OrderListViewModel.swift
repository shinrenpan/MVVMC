//
//  OrderListViewModel.swift
//  VM
//

import Foundation

@Observable
@MainActor
final class OrderListViewModel {
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

extension OrderListViewModel {
    enum ViewAction: Sendable {
        case isFirstAppear
        case pullToRefresh
        case retryFirstPageDidTap
        case listFooterDidAppear
        case retryNextPageDidTap
        case addButtonDidTap
        /// 新增訂單頁回報建立成功（由父 HostController 的 onCallback 轉進來）
        case orderDidCreate
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .isFirstAppear:
            guard state.isFirstAppear else { return }
            state.isFirstAppear = false
            await doAction(.apiRequest(.fetchFirstPage))

        case .pullToRefresh, .retryFirstPageDidTap, .orderDidCreate:
            await doAction(.apiRequest(.fetchFirstPage))

        case .listFooterDidAppear:
            // 流程判斷留在 VM：View 只回報「底部出現了」，不自行判讀 state 決定要不要打 API
            guard state.api.fetchFirstPage == .success else { return }
            guard state.paging.hasMore else { return }
            // 只在閒置時自動載入：.loading 防重入，.error 要等使用者按重試（否則會無限重打）
            guard state.api.fetchNextPage == .prepare || state.api.fetchNextPage == .success else { return }
            await doAction(.apiRequest(.fetchNextPage))

        case .retryNextPageDidTap:
            guard state.api.fetchNextPage != .loading else { return }
            await doAction(.apiRequest(.fetchNextPage))

        case .addButtonDidTap:
            onRoute?(.toCreateOrder)
        }
    }
}

// MARK: - Router

extension OrderListViewModel {
    enum Router: Sendable {
        case toCreateOrder
    }
}

// MARK: - APIRequest

extension OrderListViewModel {
    enum APIRequest: Sendable {
        case fetchFirstPage
        case fetchNextPage
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .fetchFirstPage:
            state.api.fetchFirstPage = .loading
            do {
                let dto = try await OrderListAPI.fetchOrders(page: 1)
                await doAction(.apiResponse(.fetchFirstPage(.success(dto))))
            } catch {
                await doAction(.apiResponse(.fetchFirstPage(.failure(.message(error.localizedDescription)))))
            }

        case .fetchNextPage:
            guard state.paging.hasMore else { return }
            let page = state.paging.nextPage
            state.api.fetchNextPage = .loading
            do {
                let dto = try await OrderListAPI.fetchOrders(page: page)
                await doAction(.apiResponse(.fetchNextPage(.success(dto))))
            } catch {
                await doAction(.apiResponse(.fetchNextPage(.failure(.message(error.localizedDescription)))))
            }
        }
    }
}

// MARK: - APIResponse

extension OrderListViewModel {
    enum APIResponse: Sendable {
        case fetchFirstPage(Result<OrderPageDTO, APIError>)
        case fetchNextPage(Result<OrderPageDTO, APIError>)
    }

    private func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case let .fetchFirstPage(.success(dto)):
            state.orders = toOrders(dto.orders)
            state.paging = .init(nextPage: dto.page + 1, hasMore: dto.hasMore)
            state.api.fetchFirstPage = .success
            // 重新載入第一頁等於重置分頁，前一次的下一頁錯誤／成功都不再成立
            state.api.fetchNextPage = .prepare

        case let .fetchFirstPage(.failure(.message(message))):
            // 刻意不清空 orders：首次載入時它本來就是空的（→ 整頁空白 + 錯誤畫面），
            // 而下拉刷新失敗時清空會把使用者眼前的內容洗掉。
            state.api.fetchFirstPage = .error(message)

        case let .fetchNextPage(.success(dto)):
            state.orders += toOrders(dto.orders)
            state.paging = .init(nextPage: dto.page + 1, hasMore: dto.hasMore)
            state.api.fetchNextPage = .success

        case let .fetchNextPage(.failure(.message(message))):
            // 既有內容原封不動，錯誤只落在列表底部
            state.api.fetchNextPage = .error(message)
        }
    }

    /// 純運算，不碰 actor state
    nonisolated private func toOrders(_ dtos: [OrderDTO]) -> [Order] {
        dtos.compactMap { $0.toDomain() }
    }
}
