//
//  OrderListMocks.swift
//  M — Mock（整檔 #if DEBUG）
//

#if DEBUG
import Foundation

extension OrderListViewModel.Order {
    static let mock: Self = .init(
        id: "A-0001",
        customerName: "王小明",
        productName: "無線耳機",
        quantity: 2,
        status: .pending,
        createdAt: .now
    )

    static let mocks: [Self] = [
        .init(id: "A-0001", customerName: "王小明", productName: "無線耳機", quantity: 2, status: .pending, createdAt: .now),
        .init(id: "A-0002", customerName: "陳美玲", productName: "機械鍵盤", quantity: 1, status: .confirmed, createdAt: .now),
        .init(id: "A-0003", customerName: "林大衛", productName: "27 吋螢幕", quantity: 3, status: .shipped, createdAt: .now),
        .init(id: "A-0004", customerName: "張雅婷", productName: "人體工學椅", quantity: 1, status: .cancelled, createdAt: .now),
    ]
}
#endif
