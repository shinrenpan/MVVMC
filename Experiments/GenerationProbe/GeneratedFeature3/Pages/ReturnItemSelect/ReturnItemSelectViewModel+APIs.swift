//
//  ReturnItemSelectViewModel+APIs.swift
//  MVVMC
//

import Foundation

enum ReturnItemSelectAPI {
  /// GET /orders/{id}/returnable-items
  static func fetchReturnableItems(orderID: String) async throws -> [ReturnItemSelectViewModel.ReturnableItemDTO] {
    try await Task.sleep(for: .milliseconds(300))
    guard !orderID.isEmpty else { throw APIError.message("缺少訂單編號") }
    return [
      .init(item_id: "I-1", item_name: "無線耳機", quantity: 1, unit_price: 2490, returnable: true),
      .init(item_id: "I-2", item_name: "充電線 2m", quantity: 2, unit_price: 495, returnable: true),
      .init(item_id: "I-3", item_name: "限時贈品貼紙", quantity: 1, unit_price: 0, returnable: false),
    ]
  }
}
