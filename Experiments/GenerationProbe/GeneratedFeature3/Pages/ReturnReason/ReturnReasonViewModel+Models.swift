//
//  ReturnReasonViewModel+Models.swift
//  MVVMC
//
//  退貨申請 Step 2：填寫退貨原因（表單頁）
//

import Foundation

// MARK: - State

extension ReturnReasonViewModel {
  struct State: Equatable, Sendable {
    /// 前一步帶進來、本頁不使用、但必須往下一步傳的資料（pass-through）
    var orderID: String = ""
    var itemIDs: [String] = []

    /// 輸入緩衝：使用者還沒送出的東西不是業務實體，屬 State
    var reasonCategory: ReasonCategory?
    var note: String = ""

    var isShowingCancelAlert: Bool = false

    /// 驗證是推導值，不另存 stored 欄位
    var isValid: Bool { reasonCategory != nil }

    var isDirty: Bool {
      reasonCategory != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 跨頁一律傳 primitive
    var reasonCode: String { reasonCategory?.rawValue ?? "" }
  }
}

// MARK: - Domain Models

extension ReturnReasonViewModel {
  /// 退貨原因類別。純值 enum 已隱含 Equatable，只宣告 Sendable
  enum ReasonCategory: String, CaseIterable, Sendable {
    case damaged
    case wrongItem
    case notAsDescribed
    case changedMind
    case other

    /// 業務規則（不是顯示決策）：這個原因是否必須補充說明
    var requiresNote: Bool { self == .other }
  }
}
