//
//  ReturnItemSelectMocks.swift
//  MVVMC
//

#if DEBUG
import Foundation

extension ReturnItemSelectViewModel.ReturnableItem {
  static let mock: Self = .init(id: "I-1", name: "無線耳機", quantity: 1, unitPrice: 2490)
  static let mocks: [Self] = [
    .init(id: "I-1", name: "無線耳機", quantity: 1, unitPrice: 2490),
    .init(id: "I-2", name: "充電線 2m", quantity: 2, unitPrice: 495),
  ]
}
#endif
