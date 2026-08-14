import Foundation

// MARK: - State

extension OrderDetailViewModel {
    struct State: Equatable, Sendable {
        var isFirstAppear: Bool = true
        var api: API = .init()

        /// 訂單基本資料（低頻：首次載入 / 下拉刷新才變）
        var order: Order?

        /// 即時狀態列（高頻：每 5 秒輪詢一次）
        ///
        /// 刻意**不**放進 `Order`：兩者來自各自獨立的 API
        /// （見 `mvvmc-model`〈Domain Models〉「兩份資料來自各自獨立的 API 時優先只存參照」），
        /// 而且合併後任何一次輪詢都會讓 `Order` 整包 !=，
        /// 使 `InfoSection` / `ItemsSection` 跟著重繪（見 `mvvmc-view` §7）。
        var liveStatus: LiveStatus?

        /// 送出退貨申請後拿到的申請編號（樂觀更新時一併寫入）
        var latestReturnID: String?

        var canRequestReturn: Bool {
            guard order != nil, let stage = liveStatus?.stage else { return false }
            return stage.allowsReturnRequest
        }
    }

    /// 請求狀態容器。形狀不在規範範圍（見 `mvvmc-model`〈State 欄位型別〉）。
    /// 輪詢與訂單載入各自追蹤，任一支失敗不會蓋掉另一支（見 `mvvmc-viewmodel`〈多個 API 的並發〉）。
    struct API: Equatable, Sendable {
        var fetchOrder: APIStatus = .prepare
        var fetchLiveStatus: APIStatus = .prepare
    }
}

// MARK: - Domain Models

extension OrderDetailViewModel {
    struct Order: Identifiable, Equatable, Sendable {
        let id: String
        var orderNumber: String
        var placedAt: Date
        var recipientName: String
        var shippingAddress: String
        var items: [OrderItem]
        var totalAmount: Double
    }

    /// L2：只被 `Order` 使用 → 同一個 extension，沿用 `Order` 前綴
    struct OrderItem: Identifiable, Equatable, Sendable {
        let id: String
        var productName: String
        var quantity: Int
        var unitPrice: Double

        var subtotal: Double { unitPrice * Double(quantity) }
    }
}

extension OrderDetailViewModel {
    /// 即時狀態列的資料。與 `Order` 分屬不同 API、不同更新頻率，故各自一個 Model。
    struct LiveStatus: Equatable, Sendable {
        var stage: LiveStatusStage
        var updatedAt: Date
    }

    /// L2：只被 `LiveStatus` 使用（純值 enum 已隱含 Equatable，只宣告 Sendable）
    enum LiveStatusStage: String, Sendable {
        case pending
        case paid
        case shipped
        case delivered
        case returning
        case returned
        case cancelled

        /// 業務語意的推導值——不是顯示決策，所以留在 M 層。
        /// 「這個狀態該顯示成什麼顏色／文案」則屬 V 層（見 `mvvmc-view`〈Display Helper〉）。
        var allowsReturnRequest: Bool {
            switch self {
            case .shipped, .delivered: true
            case .pending, .paid, .returning, .returned, .cancelled: false
            }
        }
    }
}

// MARK: - DTOs

extension OrderDetailViewModel {
    /// 假設此 API 以 snake_case 回傳；DTO 命名與 API key 1:1，不加 CodingKeys。
    struct OrderDetailDTO: Codable, Sendable {
        var order_id: String
        var order_number: String
        var placed_at: String
        var recipient_name: String
        var shipping_address: String
        var total_amount: Double
        var items: [OrderItemDTO]

        func toDomain() -> Order? {
            guard !order_id.isEmpty else { return nil }

            return .init(
                id: order_id,
                orderNumber: order_number,
                placedAt: ISO8601DateFormatter().date(from: placed_at) ?? .now,
                recipientName: recipient_name,
                shippingAddress: shipping_address,
                items: items.compactMap { $0.toDomain() },
                totalAmount: total_amount
            )
        }
    }

    /// L2：只被 `OrderDetailDTO` 使用
    struct OrderItemDTO: Codable, Sendable {
        var item_id: String
        var product_name: String
        var quantity: Int
        var unit_price: Double

        func toDomain() -> OrderItem? {
            guard !item_id.isEmpty else { return nil }

            return .init(
                id: item_id,
                productName: product_name,
                quantity: quantity,
                unitPrice: unit_price
            )
        }
    }

    struct OrderLiveStatusDTO: Codable, Sendable {
        var order_id: String
        var status_code: String
        var status_updated_at: String

        func toDomain() -> LiveStatus? {
            guard let stage = LiveStatusStage(rawValue: status_code) else { return nil }

            return .init(
                stage: stage,
                updatedAt: ISO8601DateFormatter().date(from: status_updated_at) ?? .now
            )
        }
    }
}
