//
//  OrderDetailView.swift
//  MVVMC
//

import SwiftUI

// MARK: - Display Helpers（Model → UI 型別，屬 V 層決策）

private extension OrderDetailViewModel.LiveStatusCode {
  var title: String {
    switch self {
    case .pending: "待處理"
    case .packing: "備貨中"
    case .shipped: "已出貨"
    case .delivered: "已送達"
    case .returnProcessing: "退貨處理中"
    }
  }

  var color: Color {
    switch self {
    case .pending: .gray
    case .packing: .orange
    case .shipped: .blue
    case .delivered: .green
    case .returnProcessing: .purple
    }
  }

  var iconName: String {
    switch self {
    case .pending: "clock"
    case .packing: "shippingbox"
    case .shipped: "truck.box"
    case .delivered: "checkmark.seal"
    case .returnProcessing: "arrow.uturn.left.circle"
    }
  }
}

// MARK: - L1

struct OrderDetailView: View {
  let viewModel: OrderDetailViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // 高頻更新區塊 → 獨立 struct，讓 SwiftUI 在 props 不變時跳過它的 body；
        // 同樣重要的是反向：它每 5 秒變一次，也不會拖著 InfoSection / ItemsSection 重跑 body
        StatusSection(
          status: viewModel.state.liveStatus,
          pollStatus: viewModel.state.api.pollStatus
        )
        .task {
          // 輪詢生命週期綁在這個 .task 上：畫面消失 → Task 取消 → VM 的迴圈結束
          await viewModel.doAction(.view(.statusBarDidAppear))
        }

        contentSection()
      }
      .padding()
    }
    .navigationTitle("訂單詳情")
    .navigationBarTitleDisplayMode(.inline)
    .refreshable { await viewModel.doAction(.view(.pullToRefresh)) }
    .task { await viewModel.doAction(.view(.isFirstAppear)) }
    .safeAreaInset(edge: .bottom) { bottomBar() }
  }
}

// MARK: - body 拆分

private extension OrderDetailView {
  /// 四態呈現：先看有沒有內容，再看狀態
  @ViewBuilder func contentSection() -> some View {
    if let order = viewModel.state.order {
      // 訂單基本資料是靜態的：只在 fetchOrder 回來時變，輪詢不會動到 order，
      // 因此這兩個 struct 的 props 在輪詢期間完全不變 → body 被跳過
      InfoSection(order: order)
      ItemsSection(items: order.items)
    } else {
      switch viewModel.state.api.fetchOrder {
      case .prepare, .loading:
        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
      case let .error(message):
        ContentUnavailableView {
          Label(message, systemImage: "exclamationmark.triangle")
        } actions: {
          Button("重試") {
            Task { await viewModel.doAction(.view(.retryButtonDidTap)) }
          }
        }
      case .success:
        ContentUnavailableView("找不到訂單", systemImage: "tray")
      }
    }
  }

  @ViewBuilder func bottomBar() -> some View {
    Button {
      Task { await viewModel.doAction(.view(.returnRequestButtonDidTap)) }
    } label: {
      Text("申請退貨")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .disabled(!viewModel.state.canRequestReturn)
    .padding()
    .background(.bar)
  }
}

// MARK: - L2 / L3

private extension OrderDetailView {
  /// 即時狀態列：唯一會因為輪詢而重繪的區塊。純展示，無 Action
  struct StatusSection: View {
    let status: OrderDetailViewModel.LiveStatus?
    let pollStatus: APIStatus

    var body: some View {
      HStack(spacing: 12) {
        if let status {
          Image(systemName: status.code.iconName)
            .font(.title2)
            .foregroundStyle(status.code.color)

          VStack(alignment: .leading, spacing: 2) {
            Text(status.code.title)
              .font(.headline)
              .contentTransition(.numericText())
            if let note = status.note {
              Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Text(status.updatedAt, format: .dateTime.hour().minute().second())
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        } else {
          ProgressView()
          Text("讀取狀態中…").font(.subheadline).foregroundStyle(.secondary)
        }

        Spacer()

        if case let .error(message) = pollStatus {
          // 已有內容時，失敗只能是「附加提示」，不可以蓋掉狀態列
          Label(message, systemImage: "wifi.exclamationmark")
            .labelStyle(.iconOnly)
            .foregroundStyle(.orange)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
      .animation(.default, value: status)
    }
  }

  /// 訂單基本資料：純展示，無 Action
  struct InfoSection: View {
    let order: OrderDetailViewModel.Order

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("訂單資訊").font(.headline)
        LabeledContent("訂單編號", value: order.number)
        LabeledContent("成立時間") {
          Text(order.placedAt, format: .dateTime.year().month().day().hour().minute())
        }
        LabeledContent("收件人", value: order.recipient)
        LabeledContent("收件地址", value: order.shippingAddress)
        LabeledContent("訂單金額") {
          Text(order.totalAmount, format: .currency(code: "TWD"))
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
    }
  }

  /// 品項清單：純展示，無 Action
  struct ItemsSection: View {
    let items: [OrderDetailViewModel.OrderItem]

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("商品明細").font(.headline)
        ForEach(items) { item in
          ItemsRow(item: item)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
    }
  }

  struct ItemsRow: View {
    let item: OrderDetailViewModel.OrderItem

    var body: some View {
      HStack {
        VStack(alignment: .leading) {
          Text(item.name)
          Text("數量 \(item.quantity)").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Text(item.unitPrice, format: .currency(code: "TWD"))
          .foregroundStyle(.secondary)
      }
    }
  }
}

// MARK: - Preview

#if DEBUG
#Preview("已出貨") {
  let vm = OrderDetailViewModel(orderID: "10001")
  vm.state.order = OrderDetailViewModel.Order.mock
  vm.state.liveStatus = OrderDetailViewModel.LiveStatus.mock
  vm.state.api.fetchOrder = .success
  return NavigationStack { OrderDetailView(viewModel: vm) }
}

#Preview("退貨處理中") {
  let vm = OrderDetailViewModel(orderID: "10001")
  vm.state.order = OrderDetailViewModel.Order.mock
  vm.state.liveStatus = OrderDetailViewModel.LiveStatus.returnProcessingMock
  vm.state.api.fetchOrder = .success
  return NavigationStack { OrderDetailView(viewModel: vm) }
}

#Preview("載入中") {
  NavigationStack { OrderDetailView(viewModel: OrderDetailViewModel(orderID: "10001")) }
}
#endif
