//
//  ReturnConfirmMocks.swift
//  MVVMC
//

#if DEBUG
import Foundation

extension ReturnConfirmViewModel.Summary {
  static let mock: Self = .init(
    items: ReturnConfirmViewModel.SummaryItem.mocks,
    reasonTitle: "商品毀損",
    refundAmount: 2985,
    estimatedDays: 7
  )
}

extension ReturnConfirmViewModel.SummaryItem {
  static let mock: Self = .init(id: "I-1", name: "無線耳機", quantity: 1)
  static let mocks: [Self] = [
    .init(id: "I-1", name: "無線耳機", quantity: 1),
    .init(id: "I-2", name: "充電線 2m", quantity: 1),
  ]
}
#endif
