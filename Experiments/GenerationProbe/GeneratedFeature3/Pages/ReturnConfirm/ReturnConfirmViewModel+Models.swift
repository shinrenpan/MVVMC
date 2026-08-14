//
//  ReturnConfirmViewModel+Models.swift
//  MVVMC
//
//  退貨申請 Step 3：確認並送出
//

import Foundation

// MARK: - State

extension ReturnConfirmViewModel {
  struct State: Equatable, Sendable {
    var isFirstAppear: Bool = true

    /// 前兩步累積的結果，全部是 primitive
    var orderID: String = ""
    var itemIDs: [String] = []
    var reasonCode: String = ""
    var note: String = ""

    /// 摘要（品名、退款金額）由伺服器算，本頁不自己拼——金額不能由 client 決定
    var summary: Summary?

    var isShowingCancelAlert: Bool = false
    var api: API = .init()

    /// 走到這一步一定已經填過東西，取消必定要先確認
    var isDirty: Bool { !itemIDs.isEmpty }

    var canSubmit: Bool {
      guard summary != nil else { return false }
      if case .loading = api.submit { return false }
      return true
    }
  }
}

extension ReturnConfirmViewModel.State {
  struct API: Equatable, Sendable {
    var fetchSummary: APIStatus = .prepare
    var submit: APIStatus = .prepare
  }
}

// MARK: - Domain Models

extension ReturnConfirmViewModel {
  struct Summary: Equatable, Sendable {
    let items: [SummaryItem]
    let reasonTitle: String
    let refundAmount: Decimal
    let estimatedDays: Int
  }

  /// L2：只被 Summary 使用
  struct SummaryItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let quantity: Int
  }
}

// MARK: - DTOs

extension ReturnConfirmViewModel {
  struct ReturnSummaryDTO: Codable, Sendable {
    var reason_title: String
    var refund_amount: Double
    var estimated_days: Int
    var items: [ReturnSummaryItemDTO]

    func toDomain() -> Summary? {
      let items = items.compactMap { $0.toDomain() }
      guard !items.isEmpty else { return nil }
      return .init(
        items: items,
        reasonTitle: reason_title,
        refundAmount: Decimal(refund_amount),
        estimatedDays: estimated_days
      )
    }
  }

  struct ReturnSummaryItemDTO: Codable, Sendable {
    var item_id: String
    var item_name: String
    var quantity: Int

    func toDomain() -> SummaryItem? {
      guard !item_id.isEmpty else { return nil }
      return .init(id: item_id, name: item_name, quantity: quantity)
    }
  }

  /// 送給 API 的 request DTO，由 handleAPIRequest 從輸入緩衝組出來
  struct SubmitReturnRequestDTO: Codable, Sendable {
    var order_id: String
    var item_ids: [String]
    var reason_code: String
    var note: String
  }

  struct ReturnReceiptDTO: Codable, Sendable {
    var return_id: String
    var accepted_at: TimeInterval
  }
}
