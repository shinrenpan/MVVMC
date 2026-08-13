# 完整範例：OrderViewModel+Models.swift

```swift
// MARK: - State

extension OrderViewModel {
    struct State: Equatable, Sendable {
        var isFirstAppear: Bool = true
        var api: API = .init()
        var orders: [Order] = []
    }

    // 請求狀態容器。形狀（叫不叫 api、狀態有哪些 case）不在規範範圍，
    // 這裡示範的是 demo 的做法；APIStatus 是專案自訂的共用 enum
    // （.prepare / .loading / .success / .error）。見 SKILL.md〈State 欄位型別〉
    struct API: Equatable, Sendable {
        var fetchOrders: APIStatus = .prepare
    }
}

// MARK: - Domain Models

extension OrderViewModel {
    struct Order: Identifiable, Equatable, Sendable {
        let id: String
        var status: OrderStatus
        var items: [OrderItem]
        var totalAmount: Double
    }

    // L2：只被 Order 使用（純值 enum 已隱含 Equatable）
    enum OrderStatus: String, Sendable {
        case pending, confirmed, shipped, delivered, cancelled
    }

    struct OrderItem: Identifiable, Equatable, Sendable {
        let id: String
        var productName: String
        var quantity: Int
        var unitPrice: Double
    }
}

// MARK: - DTOs

// 註：這裡的 snake_case 只是因為假設此 API 用 snake_case 回傳；
// DTO 命名對齊 API 實際 key 即可，不強制 snake_case 或任何命名風格。
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
                // ?? .pending 只是範例佔位；未知 enum 值如何處理（降級、丟棄、報錯）
                // 應由業務決定，不是通則建議。
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
