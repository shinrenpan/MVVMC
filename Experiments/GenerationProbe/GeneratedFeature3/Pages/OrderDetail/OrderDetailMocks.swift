//
//  OrderDetailMocks.swift
//  MVVMC
//

#if DEBUG
import Foundation

extension OrderDetailViewModel.Order {
  static let mock: Self = .init(
    id: "10001",
    number: "SO-10001",
    placedAt: Date(timeIntervalSince1970: 1_754_000_000),
    recipient: "王小明",
    shippingAddress: "台北市信義區市府路 1 號",
    totalAmount: 3480,
    isReturnable: true,
    items: OrderDetailViewModel.OrderItem.mocks
  )
}

extension OrderDetailViewModel.OrderItem {
  static let mock: Self = .init(id: "I-1", name: "無線耳機", quantity: 1, unitPrice: 2490)
  static let mocks: [Self] = [
    .init(id: "I-1", name: "無線耳機", quantity: 1, unitPrice: 2490),
    .init(id: "I-2", name: "充電線 2m", quantity: 2, unitPrice: 495),
  ]
}

extension OrderDetailViewModel.LiveStatus {
  static let mock: Self = .init(
    code: .shipped,
    updatedAt: Date(timeIntervalSince1970: 1_754_300_000),
    note: "已由物流中心出貨"
  )
  static let returnProcessingMock: Self = .init(
    code: .returnProcessing,
    updatedAt: Date(timeIntervalSince1970: 1_754_400_000),
    note: "退貨申請已受理"
  )
}
#endif
