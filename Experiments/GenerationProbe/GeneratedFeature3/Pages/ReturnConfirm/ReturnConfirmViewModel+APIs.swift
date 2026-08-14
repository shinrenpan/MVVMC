//
//  ReturnConfirmViewModel+APIs.swift
//  MVVMC
//

import Foundation

enum ReturnConfirmAPI {
  /// POST /returns/preview — 退款金額由伺服器計算
  static func fetchSummary(
    orderID: String,
    itemIDs: [String],
    reasonCode: String
  ) async throws -> ReturnConfirmViewModel.ReturnSummaryDTO {
    try await Task.sleep(for: .milliseconds(350))
    guard !orderID.isEmpty, !itemIDs.isEmpty else {
      throw APIError.message("退貨資料不完整")
    }
    return .init(
      reason_title: "商品毀損",
      refund_amount: 2985,
      estimated_days: 7,
      items: itemIDs.map {
        .init(item_id: $0, item_name: "商品 \($0)", quantity: 1)
      }
    )
  }

  /// POST /returns
  static func submitReturn(
    _ request: ReturnConfirmViewModel.SubmitReturnRequestDTO
  ) async throws -> ReturnConfirmViewModel.ReturnReceiptDTO {
    try await Task.sleep(for: .milliseconds(600))
    guard !request.reason_code.isEmpty else { throw APIError.message("缺少退貨原因") }
    return .init(return_id: "RMA-20260814-001", accepted_at: Date().timeIntervalSince1970)
  }
}
