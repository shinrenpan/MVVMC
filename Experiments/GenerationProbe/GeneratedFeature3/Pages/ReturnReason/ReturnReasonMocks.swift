//
//  ReturnReasonMocks.swift
//  MVVMC
//
//  表單頁沒有「有資料可造」的 Domain Model（ReasonCategory 是純值 enum，
//  造 mock 沒有意義），依 mvvmc-model 的例外把 mock 掛在 State 上。
//

#if DEBUG
import Foundation

extension ReturnReasonViewModel.State {
  static let filledMock: Self = .init(
    orderID: "10001",
    itemIDs: ["I-1", "I-2"],
    reasonCategory: .damaged,
    note: "外盒凹陷，耳機無法充電"
  )
}
#endif
