//
//  OrderDetailViewModel+Models.swift
//  MVVMC
//

import Foundation

// MARK: - State

extension OrderDetailViewModel {
  struct State: Equatable, Sendable {
    var isFirstAppear: Bool = true
    var orderID: String = ""

    /// 訂單基本資料：只在 fetchOrder 成功時整包換掉，輪詢不會碰它。
    /// 與 liveStatus 分開存是「只有狀態列該重繪」的前提——同一顆 struct 內任一欄位變動
    /// 都會讓持有它的子 View props 改變。
    var order: Order?

    /// 即時狀態列：每 5 秒輪詢一次，只有這一格會被改寫。
    var liveStatus: LiveStatus?

    /// 退貨流程送出後拿到的退貨單號（本頁只用來顯示）。
    var submittedReturnID: String?

    var api: API = .init()

    var canRequestReturn: Bool {
      guard let order, let liveStatus else { return false }
      return order.isReturnable && liveStatus.code.allowsReturnRequest
    }
  }
}

extension OrderDetailViewModel.State {
  struct API: Equatable, Sendable {
    var fetchOrder: APIStatus = .prepare
    var pollStatus: APIStatus = .prepare
  }
}

// MARK: - Domain Models

extension OrderDetailViewModel {
  struct Order: Identifiable, Equatable, Sendable {
    let id: String
    let number: String
    let placedAt: Date
    let recipient: String
    let shippingAddress: String
    let totalAmount: Decimal
    let isReturnable: Bool
    let items: [OrderItem]
  }

  /// L2：只被 Order 使用 → 同一個 extension，加 Order prefix
  struct OrderItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let quantity: Int
    let unitPrice: Decimal
  }
}

extension OrderDetailViewModel {
  struct LiveStatus: Equatable, Sendable {
    let code: LiveStatusCode
    let updatedAt: Date
    /// 物流／客服附註，由 API 給，沒有就是 nil
    let note: String?
  }

  /// L2：只被 LiveStatus 使用。純值 enum 已隱含 Equatable，只宣告 Sendable
  enum LiveStatusCode: String, Sendable {
    case pending
    case packing
    case shipped
    case delivered
    case returnProcessing

    /// 業務語意（不是顯示決策）：什麼狀態下允許申請退貨
    var allowsReturnRequest: Bool {
      switch self {
      case .shipped, .delivered: true
      case .pending, .packing, .returnProcessing: false
      }
    }
  }
}

// MARK: - DTOs

extension OrderDetailViewModel {
  struct OrderDTO: Codable, Sendable {
    var order_id: String
    var order_number: String
    var placed_at: TimeInterval
    var recipient_name: String
    var shipping_address: String
    var total_amount: Double
    var is_returnable: Bool
    var items: [OrderItemDTO]

    func toDomain() -> Order? {
      guard !order_id.isEmpty else { return nil }
      return .init(
        id: order_id,
        number: order_number,
        placedAt: Date(timeIntervalSince1970: placed_at),
        recipient: recipient_name,
        shippingAddress: shipping_address,
        totalAmount: Decimal(total_amount),
        isReturnable: is_returnable,
        items: items.compactMap { $0.toDomain() }
      )
    }
  }

  struct OrderItemDTO: Codable, Sendable {
    var item_id: String
    var item_name: String
    var quantity: Int
    var unit_price: Double

    func toDomain() -> OrderItem? {
      guard !item_id.isEmpty, quantity > 0 else { return nil }
      return .init(
        id: item_id,
        name: item_name,
        quantity: quantity,
        unitPrice: Decimal(unit_price)
      )
    }
  }

  struct OrderStatusDTO: Codable, Sendable {
    var status_code: String
    var updated_at: TimeInterval
    var status_note: String?

    func toDomain() -> LiveStatus? {
      guard let code = LiveStatusCode(rawValue: status_code) else { return nil }
      return .init(
        code: code,
        updatedAt: Date(timeIntervalSince1970: updated_at),
        note: status_note
      )
    }
  }
}
