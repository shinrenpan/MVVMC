//
//  OrderListViewModelTests.swift
//

import Testing
@testable import AppModule

@MainActor
struct OrderListViewModelTests {

    // MARK: - Helpers

    private func makePageDTO(
        page: Int,
        totalPages: Int,
        count: Int
    ) -> OrderListViewModel.OrderPageDTO {
        .init(
            page: page,
            per_page: 20,
            total: totalPages * 20,
            total_pages: totalPages,
            orders: (0..<count).map {
                .init(
                    order_id: "P\(page)-\($0)",
                    customer_name: "客戶 \($0)",
                    product_name: "商品 \($0)",
                    quantity: 1,
                    order_status: "pending",
                    created_at: "2026-08-14T10:00:00Z"
                )
            }
        )
    }

    // MARK: - Guard

    @Test
    func `isFirstAppear guard blocks duplicate trigger`() async {
        let vm = OrderListViewModel()
        vm.state.isFirstAppear = false
        await vm.doAction(.view(.isFirstAppear))
        #expect(vm.state.api.fetchFirstPage == .prepare)
    }

    @Test
    func `listFooterDidAppear does nothing before first page succeeds`() async {
        let vm = OrderListViewModel()
        await vm.doAction(.view(.listFooterDidAppear))
        #expect(vm.state.api.fetchNextPage == .prepare)
    }

    @Test
    func `listFooterDidAppear does nothing when no more pages`() async {
        let vm = OrderListViewModel()
        vm.state.api.fetchFirstPage = .success
        vm.state.paging = .init(nextPage: 3, hasMore: false)
        await vm.doAction(.view(.listFooterDidAppear))
        #expect(vm.state.api.fetchNextPage == .prepare)
    }

    @Test
    func `listFooterDidAppear does not auto retry after next page failed`() async {
        let vm = OrderListViewModel()
        vm.state.api.fetchFirstPage = .success
        vm.state.api.fetchNextPage = .error("連線逾時")
        vm.state.paging = .init(nextPage: 2, hasMore: true)
        await vm.doAction(.view(.listFooterDidAppear))
        #expect(vm.state.api.fetchNextPage == .error("連線逾時"))
    }

    // MARK: - apiResponse 注入

    @Test
    func `first page success replaces orders and advances cursor`() async {
        let vm = OrderListViewModel()
        await vm.doAction(.apiResponse(.fetchFirstPage(.success(makePageDTO(page: 1, totalPages: 3, count: 20)))))

        #expect(vm.state.orders.count == 20)
        #expect(vm.state.paging == .init(nextPage: 2, hasMore: true))
        #expect(vm.state.api.fetchFirstPage == .success)
    }

    @Test
    func `first page failure keeps orders untouched`() async {
        let vm = OrderListViewModel()
        vm.state.orders = OrderListViewModel.Order.mocks

        await vm.doAction(.apiResponse(.fetchFirstPage(.failure(.message("Network error")))))

        #expect(vm.state.orders == OrderListViewModel.Order.mocks)
        #expect(vm.state.api.fetchFirstPage == .error("Network error"))
    }

    @Test
    func `next page success appends to existing orders`() async {
        let vm = OrderListViewModel()
        await vm.doAction(.apiResponse(.fetchFirstPage(.success(makePageDTO(page: 1, totalPages: 2, count: 20)))))
        await vm.doAction(.apiResponse(.fetchNextPage(.success(makePageDTO(page: 2, totalPages: 2, count: 5)))))

        #expect(vm.state.orders.count == 25)
        #expect(vm.state.paging.hasMore == false)
        #expect(vm.state.api.fetchNextPage == .success)
    }

    @Test
    func `next page failure keeps loaded orders`() async {
        let vm = OrderListViewModel()
        await vm.doAction(.apiResponse(.fetchFirstPage(.success(makePageDTO(page: 1, totalPages: 3, count: 20)))))
        await vm.doAction(.apiResponse(.fetchNextPage(.failure(.message("連線逾時")))))

        #expect(vm.state.orders.count == 20)
        #expect(vm.state.api.fetchFirstPage == .success)
        #expect(vm.state.api.fetchNextPage == .error("連線逾時"))
    }

    @Test
    func `reloading first page resets next page status`() async {
        let vm = OrderListViewModel()
        vm.state.api.fetchNextPage = .error("連線逾時")

        await vm.doAction(.apiResponse(.fetchFirstPage(.success(makePageDTO(page: 1, totalPages: 1, count: 3)))))

        #expect(vm.state.api.fetchNextPage == .prepare)
        #expect(vm.state.paging == .init(nextPage: 2, hasMore: false))
    }

    @Test(arguments: [0, 1, 20])
    func `first page success maps every DTO`(count: Int) async {
        let vm = OrderListViewModel()
        await vm.doAction(.apiResponse(.fetchFirstPage(.success(makePageDTO(page: 1, totalPages: 1, count: count)))))
        #expect(vm.state.orders.count == count)
    }

    // MARK: - Router

    @Test
    func `addButtonDidTap routes to create order`() async {
        let vm = OrderListViewModel()
        var received: OrderListViewModel.Router?
        vm.onRoute = { received = $0 }

        await vm.doAction(.view(.addButtonDidTap))

        #expect(received == .toCreateOrder)
    }
}
