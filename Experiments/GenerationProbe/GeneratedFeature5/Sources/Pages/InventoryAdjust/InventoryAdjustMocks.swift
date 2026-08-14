//
//  InventoryAdjustMocks.swift
//  Mock（整檔 #if DEBUG，選用檔）
//
//  例外處理：本頁唯一的 Domain Model 是 AdjustReason（純值 enum，造假資料沒有意義），
//  State 只有輸入緩衝。依 mvvmc-model〈Mock 資料〉的例外條款，mock 掛在 State 上。
//  這條規則真正要擋的是「mock 掛在 DTO 上」。
//

import Foundation

#if DEBUG
extension InventoryAdjustViewModel.State {
    /// 空表單（送出停用）
    static let mock: Self = .init(
        itemID: "SKU-001",
        itemName: "藍芽耳機",
        currentQuantity: 42
    )

    /// 填妥、可送出
    static let filledMock: Self = {
        var state = mock
        state.quantityText = "-5"
        state.reason = .damaged
        state.note = "運送途中破損"
        return state
    }()

    /// 送出中
    static let submittingMock: Self = {
        var state = filledMock
        state.api.submit = .loading
        return state
    }()

    /// 送出失敗，輸入保留
    static let failedMock: Self = {
        var state = filledMock
        state.api.submit = .error("庫存服務暫時無法使用")
        return state
    }()
}
#endif
