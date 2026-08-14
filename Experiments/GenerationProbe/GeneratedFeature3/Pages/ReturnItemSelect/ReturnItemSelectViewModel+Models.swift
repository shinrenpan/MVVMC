//
//  ReturnItemSelectViewModel+Models.swift
//  MVVMC
//
//  退貨申請 Step 1：選擇要退的商品
//

import Foundation

// MARK: - State

extension ReturnItemSelectViewModel {
  struct State: Equatable, Sendable {
    var isFirstAppear: Bool = true
    var orderID: String = ""
    var items: [ReturnableItem] = []

    /// 使用者的選取（輸入緩衝，還沒送出 → 屬 State 不屬 Domain Model）
    var selectedIDs: Set<String> = []

    /// 下游步驟（Step 2）返回時回拋的草稿。本頁完全不顯示它，
    /// 只是因為 Step 2 的 VC 已被 pop 掉、再次前進時需要還原輸入而暫存在這裡。
    var draftReasonCode: String = ""
    var draftNote: String = ""

    var isShowingCancelAlert: Bool = false
    var api: API = .init()

    /// 至少選一項才能下一步
    var canGoNext: Bool { !selectedIDs.isEmpty }

    /// 有沒有「已經填了東西」——決定取消時要不要跳確認對話框
    var isDirty: Bool { !selectedIDs.isEmpty || !draftReasonCode.isEmpty || !draftNote.isEmpty }

    /// 依畫面顯示順序輸出，跨頁只傳 primitive
    var selectedItemIDs: [String] {
      items.map(\.id).filter { selectedIDs.contains($0) }
    }
  }
}

extension ReturnItemSelectViewModel.State {
  struct API: Equatable, Sendable {
    var fetchItems: APIStatus = .prepare
  }
}

// MARK: - Domain Models

extension ReturnItemSelectViewModel {
  struct ReturnableItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let quantity: Int
    let unitPrice: Decimal
  }
}

// MARK: - DTOs

extension ReturnItemSelectViewModel {
  struct ReturnableItemDTO: Codable, Sendable {
    var item_id: String
    var item_name: String
    var quantity: Int
    var unit_price: Double
    var returnable: Bool

    func toDomain() -> ReturnableItem? {
      guard !item_id.isEmpty, returnable else { return nil }
      return .init(
        id: item_id,
        name: item_name,
        quantity: quantity,
        unitPrice: Decimal(unit_price)
      )
    }
  }
}
