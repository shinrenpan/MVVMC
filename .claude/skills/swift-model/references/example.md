# 完整範例：OrderViewModel+Models.swift

```swift
// MARK: - State

extension OrderViewModel {
    struct State: Sendable {
        var orders: [Order] = []
        var isLoading: Bool = false
        var selectedOrder: Order? = nil
        var errorMessage: String? = nil
    }
}

// MARK: - Domain Models

extension OrderViewModel {
    struct Order: Identifiable, Sendable {
        let id: UUID
        var status: OrderStatus
        var items: [OrderItem]
        var shippingAddress: OrderAddress
        var totalAmount: Double
        var createdAt: Date
    }

    // L2: 只被 Order 使用
    enum OrderStatus: String, Sendable {
        case pending, confirmed, shipped, delivered, cancelled
    }

    struct OrderItem: Identifiable, Sendable {
        let id: UUID
        var productName: String
        var quantity: Int
        var unitPrice: Double
    }

    struct OrderAddress: Sendable {
        var street: String
        var city: String
        var zipCode: String
    }
}

// MARK: - DTOs

extension OrderViewModel {
    struct OrderDTO: DomainConvertible {
        typealias DomainModel = Order

        @SafeBox var order_id: String
        @SafeBox var order_status: String
        @SafeBox var total_amount: Double
        @SafeBox var created_at: String
        var shipping_address: OrderAddressDTO
        @SafeArray var items: [OrderItemDTO]

        static func defaultInstance() -> OrderDTO {
            OrderDTO(
                order_id: SafeBox(wrappedValue: ""),
                order_status: SafeBox(wrappedValue: ""),
                total_amount: SafeBox(wrappedValue: 0),
                created_at: SafeBox(wrappedValue: ""),
                shipping_address: .defaultInstance(),
                items: SafeArray(wrappedValue: [])
            )
        }

        func toDomain() -> Order? {
            guard !order_id.wrappedValue.isEmpty else { return nil }
            return Order(
                id: UUID(uuidString: order_id.wrappedValue) ?? UUID(),
                status: OrderStatus(rawValue: order_status.wrappedValue) ?? .pending,
                items: items.wrappedValue.compactMap { $0.toDomain() },
                shippingAddress: shipping_address.toDomain() ?? OrderAddress(street: "", city: "", zipCode: ""),
                totalAmount: total_amount.wrappedValue,
                createdAt: ISO8601DateFormatter().date(from: created_at.wrappedValue) ?? Date()
            )
        }
    }

    // L2: 只被 OrderDTO 使用
    struct OrderAddressDTO: DomainConvertible {
        typealias DomainModel = OrderAddress

        @SafeBox var street: String
        @SafeBox var city: String
        @SafeBox var zip_code: String

        static func defaultInstance() -> OrderAddressDTO {
            OrderAddressDTO(
                street: SafeBox(wrappedValue: ""),
                city: SafeBox(wrappedValue: ""),
                zip_code: SafeBox(wrappedValue: "")
            )
        }

        func toDomain() -> OrderAddress? {
            OrderAddress(
                street: street.wrappedValue,
                city: city.wrappedValue,
                zipCode: zip_code.wrappedValue
            )
        }
    }

    struct OrderItemDTO: DomainConvertible {
        typealias DomainModel = OrderItem

        @SafeBox var item_id: String
        @SafeBox var product_name: String
        @SafeBox var quantity: Int
        @SafeBox var unit_price: Double

        static func defaultInstance() -> OrderItemDTO {
            OrderItemDTO(
                item_id: SafeBox(wrappedValue: ""),
                product_name: SafeBox(wrappedValue: ""),
                quantity: SafeBox(wrappedValue: 0),
                unit_price: SafeBox(wrappedValue: 0)
            )
        }

        func toDomain() -> OrderItem? {
            guard !item_id.wrappedValue.isEmpty else { return nil }
            return OrderItem(
                id: UUID(uuidString: item_id.wrappedValue) ?? UUID(),
                productName: product_name.wrappedValue,
                quantity: quantity.wrappedValue,
                unitPrice: unit_price.wrappedValue
            )
        }
    }
}
```
