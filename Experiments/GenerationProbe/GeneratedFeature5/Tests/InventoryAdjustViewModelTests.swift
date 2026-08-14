//
//  InventoryAdjustViewModelTests.swift
//
//  ⚠️ 送出的成功路徑不透過 .view(.submitDidTap) 測——那會連鎖走進 handleAPIRequest 打真實網路。
//     這裡只用 .view(.submitDidTap) 測「被 guard 擋下」的情形（不會發出請求），
//     成功／失敗一律從 .apiResponse 注入。
//

import Foundation
import Testing
@testable import MVVMC // ← 對應 app module 名稱

@MainActor
struct InventoryAdjustViewModelTests {

    private func makeVM() -> InventoryAdjustViewModel {
        .init(itemID: "SKU-001", itemName: "藍芽耳機", currentQuantity: 42)
    }

    private func makeResultDTO(quantity: Int) -> InventoryAdjustViewModel.AdjustResultDTO {
        .init(item_id: "SKU-001", stock_quantity: quantity, adjusted_at: "2026-08-13T10:00:00Z")
    }

    // MARK: - 驗證（computed property）

    @Test
    func `isValid is false on a blank form`() async {
        let vm = makeVM()

        #expect(vm.state.isValid == false)
        #expect(vm.state.quantityDelta == nil)
    }

    @Test
    func `isValid is false when quantity is zero`() async {
        let vm = makeVM()
        vm.state.quantityText = "0"
        vm.state.reason = .stocktake

        #expect(vm.state.quantityDelta == nil)
        #expect(vm.state.isValid == false)
    }

    @Test(arguments: ["", " ", "abc", "1.5", "0", "+0", "-0"])
    func `isValid is false for unusable quantity input`(input: String) async {
        let vm = makeVM()
        vm.state.quantityText = input
        vm.state.reason = .restock

        #expect(vm.state.isValid == false)
    }

    @Test
    func `isValid is false when reason is not selected`() async {
        let vm = makeVM()
        vm.state.quantityText = "5"

        #expect(vm.state.isValid == false)
    }

    @Test
    func `isValid is true when quantity and reason are filled and note stays optional`() async {
        let vm = makeVM()
        vm.state.quantityText = "5"
        vm.state.reason = .restock

        #expect(vm.state.isValid)
        #expect(vm.state.note.isEmpty)
    }

    @Test(arguments: [-5, -1, 1, 12])
    func `negative and positive quantities are both accepted`(delta: Int) async {
        let vm = makeVM()
        vm.state.quantityText = "\(delta)"
        vm.state.reason = .damaged

        #expect(vm.state.quantityDelta == delta)
        #expect(vm.state.isValid)
        #expect(vm.state.previewQuantity == 42 + delta)
    }

    // MARK: - 防重送 guard（在 VM，不是靠 UI disable）

    @Test
    func `submitDidTap is ignored while a submission is in flight`() async {
        let vm = makeVM()
        vm.state.quantityText = "5"
        vm.state.reason = .restock
        vm.state.api.submit = .loading
        let before = vm.state

        await vm.doAction(.view(.submitDidTap))

        #expect(vm.state == before)
    }

    @Test
    func `submitDidTap is ignored when the form is invalid`() async {
        let vm = makeVM()
        vm.state.quantityText = "0"
        let before = vm.state

        await vm.doAction(.view(.submitDidTap))

        #expect(vm.state == before)
        #expect(vm.state.api.submit == .prepare)
    }

    @Test
    func `duplicate submit while loading never fires the callback`() async {
        await confirmation("callback 不該被呼叫", expectedCount: 0) { fired in
            let vm = makeVM()
            vm.state.quantityText = "5"
            vm.state.reason = .restock
            vm.state.api.submit = .loading
            vm.onCallback = { _ in fired() }

            await vm.doAction(.view(.submitDidTap))
            await vm.doAction(.view(.submitDidTap))
        }
    }

    // MARK: - 送出結果

    @Test
    func `submit failure keeps every field the user typed`() async {
        let vm = makeVM()
        vm.state.quantityText = "-5"
        vm.state.reason = .damaged
        vm.state.note = "運送途中破損"
        vm.state.api.submit = .loading

        await vm.doAction(.apiResponse(.submit(.failure(.message("庫存服務暫時無法使用")))))

        #expect(vm.state.api.submit == .error("庫存服務暫時無法使用"))
        #expect(vm.state.quantityText == "-5")
        #expect(vm.state.reason == .damaged)
        #expect(vm.state.note == "運送途中破損")
        #expect(vm.state.isValid)   // 失敗後仍可直接再送一次
    }

    @Test
    func `submit success sets success status`() async {
        let vm = makeVM()
        vm.state.quantityText = "5"
        vm.state.reason = .restock

        await vm.doAction(.apiResponse(.submit(.success(makeResultDTO(quantity: 47)))))

        #expect(vm.state.api.submit == .success)
    }

    @Test
    func `submit success calls back with primitives`() async {
        let vm = makeVM()
        var received: InventoryAdjustViewModel.Callback?
        vm.onCallback = { received = $0 }

        await vm.doAction(.apiResponse(.submit(.success(makeResultDTO(quantity: 47)))))

        #expect(received == .didAdjust(itemID: "SKU-001", quantity: 47))
    }

    @Test
    func `submit success fires the callback exactly once`() async {
        await confirmation("callback fired", expectedCount: 1) { fired in
            let vm = makeVM()
            vm.onCallback = { _ in fired() }

            await vm.doAction(.apiResponse(.submit(.success(makeResultDTO(quantity: 47)))))
        }
    }
}
