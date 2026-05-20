# 完整範例：OrderViewModel+Models.swift

```swift
// MARK: - State

extension OrderViewModel {
    struct State: Sendable {
        var isFirstAppear: Bool = true
        var orders: [Order] = []
    }
}

// MARK: - Domain Models

extension OrderViewModel {
    struct Order: Identifiable, Sendable {
        let id: String
        var status: OrderStatus
        var items: [OrderItem]
        var totalAmount: Double
    }

    // L2：只被 Order 使用
    enum OrderStatus: String, Sendable {
        case pending, confirmed, shipped, delivered, cancelled
    }

    struct OrderItem: Identifiable, Sendable {
        let id: String
        var productName: String
        var quantity: Int
        var unitPrice: Double
    }
}

// MARK: - DTOs

extension OrderViewModel {
    struct OrderDTO: Codable, Sendable {
        var order_id: String
        var order_status: String
        var total_amount: Double
        var items: [OrderItemDTO]

        func toDomain() -> Order? {
            guard !order_id.isEmpty else { return nil }
            return .init(
                id: order_id,
                status: OrderStatus(rawValue: order_status) ?? .pending,
                items: items.compactMap { $0.toDomain() },
                totalAmount: total_amount
            )
        }
    }

    // L2：只被 OrderDTO 使用
    struct OrderItemDTO: Codable, Sendable {
        var item_id: String
        var product_name: String
        var quantity: Int
        var unit_price: Double

        func toDomain() -> OrderItem? {
            guard !item_id.isEmpty else { return nil }
            return .init(id: item_id, productName: product_name, quantity: quantity, unitPrice: unit_price)
        }
    }
}
```
