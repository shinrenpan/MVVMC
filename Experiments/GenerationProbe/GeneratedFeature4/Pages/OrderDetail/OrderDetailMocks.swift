#if DEBUG
import Foundation

extension OrderDetailViewModel.Order {
    static let mock: Self = .init(
        id: "ORD-1001",
        orderNumber: "20260814-001",
        placedAt: .now.addingTimeInterval(-86400 * 3),
        recipientName: "潘信仁",
        shippingAddress: "台北市信義區市府路 1 號",
        items: OrderDetailViewModel.OrderItem.mocks,
        totalAmount: 4180
    )
}

extension OrderDetailViewModel.OrderItem {
    static let mock: Self = .init(id: "ITEM-1", productName: "無線耳機", quantity: 1, unitPrice: 2980)

    static let mocks: [Self] = [
        .init(id: "ITEM-1", productName: "無線耳機", quantity: 1, unitPrice: 2980),
        .init(id: "ITEM-2", productName: "充電線 1M", quantity: 2, unitPrice: 350),
        .init(id: "ITEM-3", productName: "收納袋", quantity: 1, unitPrice: 500),
    ]
}

extension OrderDetailViewModel.LiveStatus {
    static let mock: Self = .init(stage: .delivered, updatedAt: .now)
    static let returningMock: Self = .init(stage: .returning, updatedAt: .now)
}
#endif
