//
//  OrderDetailViewModel+APIs.swift
//  MVVMC
//
//  Endpoint 定義。網路層怎麼發請求不在 MVVMC 規範內，這裡沿用 demo 的擺法。
//

import Foundation

enum OrderDetailAPI {
  /// GET /orders/{id}
  static func fetchOrder(id: String) async throws -> OrderDetailViewModel.OrderDTO {
    try await Task.sleep(for: .milliseconds(400))
    guard !id.isEmpty else { throw APIError.message("缺少訂單編號") }
    return .init(
      order_id: id,
      order_number: "SO-\(id)",
      placed_at: Date().addingTimeInterval(-86_400 * 3).timeIntervalSince1970,
      recipient_name: "王小明",
      shipping_address: "台北市信義區市府路 1 號",
      total_amount: 3480,
      is_returnable: true,
      items: [
        .init(item_id: "I-1", item_name: "無線耳機", quantity: 1, unit_price: 2490),
        .init(item_id: "I-2", item_name: "充電線 2m", quantity: 2, unit_price: 495),
      ]
    )
  }

  /// GET /orders/{id}/live-status — 每 5 秒輪詢
  static func fetchStatus(orderID: String) async throws -> OrderDetailViewModel.OrderStatusDTO {
    try await Task.sleep(for: .milliseconds(200))
    guard !orderID.isEmpty else { throw APIError.message("缺少訂單編號") }
    return .init(
      status_code: "shipped",
      updated_at: Date().timeIntervalSince1970,
      status_note: "已由物流中心出貨"
    )
  }
}
