import SwiftUI

// MARK: - State

extension OrderListViewModel {
  struct State: Sendable {
    var isFirstAppear: Bool = true
    var orderDTOs: [OrderDTO] = []
    var selectedUser: PostListViewModel.User?
    var errorMessage: Error?
  }
}

// MARK: - Domain Models

extension OrderListViewModel {
  struct Order: Identifiable, Equatable, Sendable {
    let id: String
    var status: OrderStatus
    var totalAmount: Double

    var statusColor: Color {
      switch status {
      case .pending: .orange
      case .shipped: .green
      }
    }
  }

  enum OrderStatus: String, Sendable {
    case pending, shipped
  }
}

// MARK: - DTOs

extension OrderListViewModel {
  struct OrderDTO: Codable, Equatable, Sendable {
    var orderId: String
    var orderStatus: String
    var totalAmount: Double

    enum CodingKeys: String, CodingKey {
      case orderId = "order_id"
      case orderStatus = "order_status"
      case totalAmount = "total_amount"
    }

    func toDomain() -> Order {
      .init(
        id: orderId,
        status: OrderStatus(rawValue: orderStatus) ?? .pending,
        totalAmount: totalAmount
      )
    }
  }
}
