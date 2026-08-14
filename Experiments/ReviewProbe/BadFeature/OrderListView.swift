import SwiftUI

struct OrderListView: View {
  @State private var viewModel = OrderListViewModel()

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(viewModel.state.orderDTOs, id: \.orderId) { dto in
          OrderRow(order: dto.toDomain(), viewModel: viewModel)
        }
      }
      .padding()
    }
    .navigationTitle("Orders")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        refreshButton
      }
    }
    .task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }

  private var refreshButton: some View {
    Button("Refresh") {
      Task { await viewModel.refresh() }
    }
  }
}

struct OrderRow: View {
  enum Action: Sendable {
    case orderDetailDidTap(OrderListViewModel.Order)
  }

  let order: OrderListViewModel.Order
  let viewModel: OrderListViewModel

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(order.id)
          .font(.headline)
        Text(order.status.rawValue)
          .font(.caption)
          .foregroundStyle(order.statusColor)
      }
      Spacer()
      Text(order.totalAmount, format: .currency(code: "TWD"))
    }
    .contentShape(Rectangle())
    .onTapGesture {
      Task { await viewModel.doAction(.view(.orderDidTap(order))) }
    }
  }
}
