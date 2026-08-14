//
//  InventoryListMocks.swift
//  Mock（整檔 #if DEBUG，選用檔）
//

import Foundation

#if DEBUG
extension InventoryListViewModel.Item {
    static let mock: Self = .init(id: "SKU-001", name: "藍芽耳機", quantity: 42)

    static let mocks: [Self] = [
        .init(id: "SKU-001", name: "藍芽耳機", quantity: 42),
        .init(id: "SKU-002", name: "USB-C 充電線 2M", quantity: 8),
        .init(id: "SKU-003", name: "行動電源 10000mAh", quantity: 0),
        .init(id: "SKU-004", name: "手機保護殼", quantity: 137),
        .init(id: "SKU-005", name: "螢幕保護貼", quantity: 65),
    ]
}

extension InventoryListViewModel.LiveTotal {
    static let mock: Self = .init(
        totalQuantity: 1280,
        syncedAt: Date(timeIntervalSince1970: 1_770_000_000)
    )
}
#endif
