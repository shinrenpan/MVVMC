//
//  InventoryListViewModelTests.swift
//
//  設計哲學：不需要 protocol、不需要 mock class。
//  一律從 doAction(.apiResponse(...)) 注入結果。
//
//  ⚠️ 只測「不會連鎖打到真實網路」的 ViewAction：
//     - .isFirstAppear（旗標已關 → 被 guard 擋下）
//     - .listBottomDidReach（三種 guard 全部擋下的情形）
//     - .itemDidTap / .didAdjustItem（不碰 API）
//     會真的走到 handleAPIRequest 的路徑（pullToRefresh、成功的 listBottomDidReach）
//     不放進單元測試，改由 .apiResponse 注入覆蓋，「ViewAction 有沒有正確轉發」靠 code review。
//

import Foundation
import Testing
@testable import MVVMC // ← 對應 app module 名稱

@MainActor
struct InventoryListViewModelTests {

    // MARK: - Fixtures

    private func makePageDTO(
        ids: [String],
        page: Int = 1,
        hasMore: Bool = true
    ) -> InventoryListViewModel.InventoryPageDTO {
        .init(
            items: ids.map {
                .init(item_id: $0, item_name: "品項 \($0)", stock_quantity: 10, updated_at: "2026-08-13T10:00:00Z")
            },
            page: page,
            page_size: InventoryListViewModel.State.pageSize,
            has_more: hasMore
        )
    }

    // MARK: - Guard

    @Test
    func `isFirstAppear guard blocks duplicate trigger`() async {
        let vm = InventoryListViewModel()
        vm.state.isFirstAppear = false

        await vm.doAction(.view(.isFirstAppear))

        #expect(vm.state.api.fetchItems == .prepare)
        #expect(vm.state.items.isEmpty)
    }

    // MARK: - 首次載入

    @Test
    func `fetchItems success replaces items and stores paging cursor`() async {
        let vm = InventoryListViewModel()

        await vm.doAction(.apiResponse(.fetchItems(.success(makePageDTO(ids: ["A", "B"])))))

        var expected = InventoryListViewModel.State()
        expected.items = [
            .init(id: "A", name: "品項 A", quantity: 10),
            .init(id: "B", name: "品項 B", quantity: 10),
        ]
        expected.page = 1
        expected.hasMore = true
        expected.api.fetchItems = .success

        // 鎖定完整狀態：多餘的欄位變動也會被抓出來
        #expect(vm.state == expected)
    }

    @Test
    func `fetchItems failure sets error status and leaves list empty`() async {
        let vm = InventoryListViewModel()

        await vm.doAction(.apiResponse(.fetchItems(.failure(.message("無法載入庫存清單")))))

        #expect(vm.state.items.isEmpty)
        #expect(vm.state.api.fetchItems == .error("無法載入庫存清單"))
        // 首次失敗不該污染「載入更多」那一格
        #expect(vm.state.api.fetchMoreItems == .prepare)
    }

    @Test
    func `fetchItems success resets previous load more error`() async {
        let vm = InventoryListViewModel()
        vm.state.api.fetchMoreItems = .error("連線逾時")

        await vm.doAction(.apiResponse(.fetchItems(.success(makePageDTO(ids: ["A"])))))

        #expect(vm.state.api.fetchMoreItems == .prepare)
    }

    @Test(arguments: [0, 1, 30])
    func `fetchItems maps every DTO`(count: Int) async {
        let vm = InventoryListViewModel()
        let ids = (0..<count).map { "SKU-\($0)" }

        await vm.doAction(.apiResponse(.fetchItems(.success(makePageDTO(ids: ids)))))

        #expect(vm.state.items.count == count)
    }

    @Test
    func `fetchItems drops DTO without item id`() async {
        let vm = InventoryListViewModel()

        await vm.doAction(.apiResponse(.fetchItems(.success(makePageDTO(ids: ["A", "", "B"])))))

        #expect(vm.state.items.map(\.id) == ["A", "B"])
    }

    // MARK: - 載入更多

    @Test
    func `fetchMoreItems success appends to existing items`() async {
        let vm = InventoryListViewModel()
        await vm.doAction(.apiResponse(.fetchItems(.success(makePageDTO(ids: ["A", "B"], page: 1)))))

        await vm.doAction(.apiResponse(.fetchMoreItems(.success(makePageDTO(ids: ["C"], page: 2, hasMore: false)))))

        #expect(vm.state.items.map(\.id) == ["A", "B", "C"])
        #expect(vm.state.page == 2)
        #expect(vm.state.hasMore == false)
        #expect(vm.state.api.fetchMoreItems == .success)
    }

    /// 這是分頁最核心的一條：第 N 頁失敗 ≠ 首次載入失敗
    @Test
    func `fetchMoreItems failure keeps existing items and first page status`() async {
        let vm = InventoryListViewModel()
        await vm.doAction(.apiResponse(.fetchItems(.success(makePageDTO(ids: ["A", "B"])))))

        await vm.doAction(.apiResponse(.fetchMoreItems(.failure(.message("連線逾時")))))

        #expect(vm.state.items.map(\.id) == ["A", "B"])   // 既有內容還在
        #expect(vm.state.api.fetchItems == .success)      // 首次載入的成功狀態沒被蓋掉
        #expect(vm.state.api.fetchMoreItems == .error("連線逾時"))
    }

    @Test
    func `listBottomDidReach does nothing when there is no next page`() async {
        let vm = InventoryListViewModel()
        vm.state.items = InventoryListViewModel.Item.mocks
        vm.state.hasMore = false

        await vm.doAction(.view(.listBottomDidReach))

        #expect(vm.state.api.fetchMoreItems == .prepare)
    }

    @Test
    func `listBottomDidReach does not auto retry after a failed page`() async {
        let vm = InventoryListViewModel()
        vm.state.items = InventoryListViewModel.Item.mocks
        vm.state.hasMore = true
        vm.state.api.fetchMoreItems = .error("連線逾時")

        await vm.doAction(.view(.listBottomDidReach))

        // 仍停在 error：footer 留在畫面上時不加這條會變成無限重試迴圈
        #expect(vm.state.api.fetchMoreItems == .error("連線逾時"))
    }

    @Test
    func `listBottomDidReach is ignored while first page is loading`() async {
        let vm = InventoryListViewModel()
        vm.state.items = InventoryListViewModel.Item.mocks
        vm.state.api.fetchItems = .loading

        await vm.doAction(.view(.listBottomDidReach))

        #expect(vm.state.api.fetchMoreItems == .prepare)
    }

    // MARK: - 輪詢

    @Test
    func `syncTotal success updates live total only`() async {
        let vm = InventoryListViewModel()
        await vm.doAction(.apiResponse(.fetchItems(.success(makePageDTO(ids: ["A", "B"])))))

        let before = vm.state
        await vm.doAction(.apiResponse(.syncTotal(.success(.init(total_quantity: 999, synced_at: 1_770_000_000)))))

        var expected = before
        expected.liveTotal = .init(totalQuantity: 999, syncedAt: Date(timeIntervalSince1970: 1_770_000_000))
        expected.api.syncTotal = .success

        // 整包比對證明：輪詢只動 liveTotal / api.syncTotal，items 一個字都沒變
        #expect(vm.state == expected)
    }

    @Test
    func `syncTotal failure keeps last known total`() async {
        let vm = InventoryListViewModel()
        vm.state.liveTotal = InventoryListViewModel.LiveTotal.mock

        await vm.doAction(.apiResponse(.syncTotal(.failure(.message("同步失敗")))))

        #expect(vm.state.liveTotal == InventoryListViewModel.LiveTotal.mock)
        #expect(vm.state.api.syncTotal == .error("同步失敗"))
    }

    // MARK: - 導航意圖

    @Test
    func `itemDidTap routes to adjust page`() async {
        let vm = InventoryListViewModel()
        var received: InventoryListViewModel.Router?
        vm.onRoute = { received = $0 }

        let item = InventoryListViewModel.Item.mock
        await vm.doAction(.view(.itemDidTap(item)))

        #expect(received == .toAdjust(item))
    }

    // MARK: - 子頁回傳

    @Test
    func `didAdjustItem updates only the adjusted row`() async throws {
        let vm = InventoryListViewModel()
        vm.state.items = InventoryListViewModel.Item.mocks

        await vm.doAction(.view(.didAdjustItem(id: "SKU-002", quantity: 3)))

        let adjusted = try #require(vm.state.items.first { $0.id == "SKU-002" })
        #expect(adjusted.quantity == 3)
        #expect(vm.state.items.first?.quantity == InventoryListViewModel.Item.mocks[0].quantity)
    }

    @Test
    func `didAdjustItem ignores unknown id`() async {
        let vm = InventoryListViewModel()
        vm.state.items = InventoryListViewModel.Item.mocks
        let before = vm.state

        await vm.doAction(.view(.didAdjustItem(id: "SKU-999", quantity: 3)))

        #expect(vm.state == before)
    }
}
