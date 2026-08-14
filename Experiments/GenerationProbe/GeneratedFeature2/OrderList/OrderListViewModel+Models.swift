//
//  OrderListViewModel+Models.swift
//  M — State / Domain Models / DTOs
//

import Foundation

// MARK: - State

extension OrderListViewModel {
    struct State: Equatable, Sendable {
        var isFirstAppear: Bool = true
        var api: API = .init()
        var orders: [Order] = []
        var paging: Paging = .init()
    }

    /// 請求狀態容器。形狀不在規範範圍（見 mvvmc-model〈State 欄位型別〉）。
    /// 首頁與下一頁分開追蹤：兩者是語意不同的失敗——首次載入失敗要整頁空白，
    /// 第 N 頁失敗時既有內容必須留著。合成一個欄位就表達不出這個差異。
    struct API: Equatable, Sendable {
        var fetchFirstPage: APIStatus = .prepare
        var fetchNextPage: APIStatus = .prepare
    }

    /// 分頁游標，屬純 UI 狀態。
    struct Paging: Equatable, Sendable {
        var nextPage: Int = 1
        var hasMore: Bool = true
    }
}

// MARK: - Domain Models

extension OrderListViewModel {
    struct Order: Identifiable, Equatable, Sendable {
        let id: String
        var customerName: String
        var productName: String
        var quantity: Int
        var status: OrderStatus
        var createdAt: Date
    }

    /// L2：只被 Order 使用。純值 enum 已隱含 Equatable，只宣告 Sendable。
    enum OrderStatus: String, Sendable {
        case pending, confirmed, shipped, cancelled
    }
}

// MARK: - DTOs

extension OrderListViewModel {
    /// GET /v1/orders?page=&per_page= 的回應。
    struct OrderPageDTO: Codable, Sendable {
        var page: Int
        var per_page: Int
        var total: Int
        var total_pages: Int
        var orders: [OrderDTO]

        /// 還有沒有下一頁，由 API 合約決定，不由呼叫端猜（例如「回傳筆數 < pageSize」）。
        var hasMore: Bool { page < total_pages }
    }

    /// L2：只被 OrderPageDTO 使用。
    struct OrderDTO: Codable, Sendable {
        var order_id: String
        var customer_name: String
        var product_name: String
        var quantity: Int
        var order_status: String
        var created_at: String

        func toDomain() -> Order? {
            guard !order_id.isEmpty else { return nil }
            return .init(
                id: order_id,
                customerName: customer_name,
                productName: product_name,
                quantity: quantity,
                // ?? .pending 是佔位選擇；未知 enum 值該降級或丟棄屬業務決定
                status: OrderStatus(rawValue: order_status) ?? .pending,
                createdAt: (try? Date(created_at, strategy: .iso8601)) ?? .distantPast
            )
        }
    }
}
