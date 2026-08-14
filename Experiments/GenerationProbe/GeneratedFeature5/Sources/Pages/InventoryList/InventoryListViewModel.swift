//
//  InventoryListViewModel.swift
//  VM
//

import Foundation

@Observable
@MainActor
final class InventoryListViewModel {
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

extension InventoryListViewModel {
    enum ViewAction: Sendable {
        case isFirstAppear
        case pullToRefresh
        /// 同步狀態列所在的 L1 出現 → 啟動輪詢迴圈
        case syncDidAppear
        /// View 只回報「列表底部出現了」，要不要真的載入由 VM guard 決定
        case listBottomDidReach
        case loadMoreRetryDidTap
        case itemDidTap(Item)
        /// 子頁 callback 回傳的結果也歸 ViewAction
        case didAdjustItem(id: String, quantity: Int)
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .isFirstAppear:
            guard state.isFirstAppear else { return }
            state.isFirstAppear = false
            await doAction(.apiRequest(.fetchItems))

        case .pullToRefresh:
            await doAction(.apiRequest(.fetchItems))

        case .syncDidAppear:
            await runSyncLoop()

        case .listBottomDidReach:
            guard canLoadMore else { return }
            await doAction(.apiRequest(.fetchMoreItems))

        case .loadMoreRetryDidTap:
            // 重試是使用者主動觸發，所以不套用 canLoadMore 裡「上一次失敗就不打」那條
            guard state.hasMore, state.api.fetchMoreItems != .loading else { return }
            await doAction(.apiRequest(.fetchMoreItems))

        case let .itemDidTap(item):
            // Router 是 feature 內部的 VM → C 通道，可以帶 Domain Model；
            // 跨 feature 的 primitive 化在 C 層的 handleRouter 完成
            onRoute?(.toAdjust(item))

        case let .didAdjustItem(id, quantity):
            guard let index = state.items.firstIndex(where: { $0.id == id }) else { return }
            // 樂觀更新：不等重新載入。
            // 與輪詢不會 race——輪詢只寫 state.liveTotal，這裡只寫 state.items，兩者不相交。
            state.items[index].quantity = quantity
        }
    }

    /// 載入下一頁的閘門。全部寫在 VM，View 不做這些判斷。
    private var canLoadMore: Bool {
        guard state.hasMore else { return false }
        guard state.api.fetchItems != .loading else { return false }
        guard state.api.fetchMoreItems != .loading else { return false }
        // 下一頁失敗後不自動重打：footer 還在畫面上，不加這條會變成無限重試迴圈。
        // 改由使用者按「重試」觸發。
        if case .error = state.api.fetchMoreItems { return false }
        return true
    }

    /// 輪詢迴圈：迴圈在 VM，生命週期由 View 的 `.task` 綁定，離開畫面時結構化取消。
    /// 刻意不用 Bool 旗標防重入——舊迴圈收尾與新迴圈啟動誰先抵達 MainActor 沒有保證，
    /// 旗標可能被永久卡在 true，fail-closed 比偶爾多跑一輪嚴重得多。
    private func runSyncLoop() async {
        guard !state.isSyncSuspended else { return }

        while !Task.isCancelled {
            await doAction(.apiRequest(.syncTotal))
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return // 被取消 → 結束整條鏈
            }
        }
    }
}

// MARK: - Router

extension InventoryListViewModel {
    enum Router: Equatable, Sendable {
        case toAdjust(Item)
    }
}

// MARK: - APIRequest

extension InventoryListViewModel {
    enum APIRequest: Sendable {
        /// 首次載入 / 下拉刷新 → replace
        case fetchItems
        /// 載入下一頁 → append。與 fetchItems 打同一支 endpoint，但是兩件不同的事
        case fetchMoreItems
        case syncTotal
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .fetchItems:
            state.api.fetchItems = .loading
            do {
                let dto = try await InventoryListAPI.fetchItems(page: 1, pageSize: State.pageSize)
                await doAction(.apiResponse(.fetchItems(.success(dto))))
            } catch {
                await doAction(.apiResponse(.fetchItems(.failure(.message(error.localizedDescription)))))
            }

        case .fetchMoreItems:
            state.api.fetchMoreItems = .loading
            let nextPage = state.page + 1
            do {
                let dto = try await InventoryListAPI.fetchItems(page: nextPage, pageSize: State.pageSize)
                await doAction(.apiResponse(.fetchMoreItems(.success(dto))))
            } catch {
                await doAction(.apiResponse(.fetchMoreItems(.failure(.message(error.localizedDescription)))))
            }

        case .syncTotal:
            // 只有首次才寫 .loading，之後的輪詢靜默更新——否則狀態列每 10 秒閃一次
            if state.api.syncTotal == .prepare {
                state.api.syncTotal = .loading
            }
            do {
                let dto = try await InventoryListAPI.fetchTotal()
                await doAction(.apiResponse(.syncTotal(.success(dto))))
            } catch {
                await doAction(.apiResponse(.syncTotal(.failure(.message(error.localizedDescription)))))
            }
        }
    }
}

// MARK: - APIResponse

extension InventoryListViewModel {
    enum APIResponse: Sendable {
        case fetchItems(Result<InventoryPageDTO, APIError>)
        case fetchMoreItems(Result<InventoryPageDTO, APIError>)
        case syncTotal(Result<InventoryTotalDTO, APIError>)
    }

    private func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case let .fetchItems(.success(dto)):
            state.items = dto.items.compactMap { $0.toDomain() }
            state.page = dto.page
            state.hasMore = dto.has_more
            state.api.fetchItems = .success
            // 重新載入等於重置分頁，上一輪「載入更多」的失敗狀態不該留著擋 canLoadMore
            state.api.fetchMoreItems = .prepare

        case let .fetchItems(.failure(.message(message))):
            // 首次載入失敗：items 本來就是空的，整頁交給 error 狀態呈現
            state.api.fetchItems = .error(message)

        case let .fetchMoreItems(.success(dto)):
            state.items += dto.items.compactMap { $0.toDomain() }
            state.page = dto.page
            state.hasMore = dto.has_more
            state.api.fetchMoreItems = .success

        case let .fetchMoreItems(.failure(.message(message))):
            // 第 N 頁失敗：既有內容一個字都不動，只有這一格變 error
            state.api.fetchMoreItems = .error(message)

        case let .syncTotal(.success(dto)):
            // 輪詢只寫 liveTotal，不碰 items
            state.liveTotal = dto.toDomain()
            state.api.syncTotal = .success

        case let .syncTotal(.failure(.message(message))):
            state.api.syncTotal = .error(message)
        }
    }
}
