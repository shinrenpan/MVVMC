//
//  OrderCreateViewModelTests.swift
//

import Testing
@testable import AppModule

@MainActor
struct OrderCreateViewModelTests {

    // MARK: - 表單驗證（State computed property）

    @Test
    func `empty draft cannot submit`() async {
        let vm = OrderCreateViewModel()
        #expect(vm.state.canSubmit == false)
    }

    @Test(arguments: ["", "0", "-1", "abc", " "])
    func `invalid quantity blocks submit`(quantityText: String) async {
        let vm = OrderCreateViewModel()
        vm.state.draft = .init(
            customerName: "王小明",
            productName: "無線耳機",
            quantityText: quantityText,
            note: ""
        )
        #expect(vm.state.canSubmit == false)
    }

    @Test
    func `note is optional`() async {
        let vm = OrderCreateViewModel()
        vm.state.draft = .init(customerName: "王小明", productName: "無線耳機", quantityText: "2", note: "")
        #expect(vm.state.canSubmit)
    }

    @Test
    func `whitespace only customer name blocks submit`() async {
        let vm = OrderCreateViewModel()
        vm.state.draft = .init(customerName: "   ", productName: "無線耳機", quantityText: "2", note: "")
        #expect(vm.state.canSubmit == false)
    }

    // MARK: - 防重複送出

    @Test
    func `submit while loading is ignored`() async {
        let vm = OrderCreateViewModel()
        vm.state.draft = OrderCreateViewModel.Draft.mock
        vm.state.api.createOrder = .loading   // 模擬送出中

        await vm.doAction(.view(.submitDidTap))

        #expect(vm.state.canSubmit == false)
        #expect(vm.state.api.createOrder == .loading)
    }

    @Test
    func `submit with invalid draft does not start request`() async {
        let vm = OrderCreateViewModel()
        await vm.doAction(.view(.submitDidTap))
        #expect(vm.state.api.createOrder == .prepare)
    }

    // MARK: - apiResponse 注入

    @Test
    func `create success fires callback exactly once`() async {
        await confirmation("didCreateOrder fired", expectedCount: 1) { fired in
            let vm = OrderCreateViewModel()
            vm.onCallback = { callback in
                #expect(callback == .didCreateOrder)
                fired()
            }
            await vm.doAction(.apiResponse(.createOrder(.success(.init(order_id: "A-0009", order_status: "pending")))))
            #expect(vm.state.api.createOrder == .success)
        }
    }

    @Test
    func `create failure keeps draft and shows message`() async {
        let vm = OrderCreateViewModel()
        vm.state.draft = OrderCreateViewModel.Draft.mock

        await vm.doAction(.apiResponse(.createOrder(.failure(.message("建立訂單失敗")))))

        #expect(vm.state.draft == OrderCreateViewModel.Draft.mock)
        #expect(vm.state.errorMessage == "建立訂單失敗")
        #expect(vm.state.canSubmit)   // 失敗後可以重送
    }

    @Test
    func `create failure does not fire callback`() async {
        let vm = OrderCreateViewModel()
        var received: OrderCreateViewModel.Callback?
        vm.onCallback = { received = $0 }

        await vm.doAction(.apiResponse(.createOrder(.failure(.message("建立訂單失敗")))))

        #expect(received == nil)
    }
}
