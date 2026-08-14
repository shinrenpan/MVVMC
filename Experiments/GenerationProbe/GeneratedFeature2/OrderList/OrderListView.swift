//
//  OrderListView.swift
//  V
//

import SwiftUI

// MARK: - Display Helper（Model → UI 型別，屬 V 層決策）

private extension OrderListViewModel.OrderStatus {
    var displayName: String {
        switch self {
        case .pending: "待確認"
        case .confirmed: "已確認"
        case .shipped: "已出貨"
        case .cancelled: "已取消"
        }
    }

    var color: Color {
        switch self {
        case .pending: .orange
        case .confirmed: .blue
        case .shipped: .green
        case .cancelled: .secondary
        }
    }
}

// MARK: - L1

struct OrderListView: View {
    let viewModel: OrderListViewModel

    var body: some View {
        content()
            .navigationTitle("訂單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增", systemImage: "plus") {
                        Task { await viewModel.doAction(.view(.addButtonDidTap)) }
                    }
                }
            }
            .task { await viewModel.doAction(.view(.isFirstAppear)) }
            .refreshable { await viewModel.doAction(.view(.pullToRefresh)) }
    }

    /// 有內容就一律顯示列表——首次載入的 loading / error 只在「沒有任何內容」時才蓋掉整頁，
    /// 這樣下拉刷新與第 N 頁失敗都不會洗掉使用者眼前的資料。
    @ViewBuilder private func content() -> some View {
        if viewModel.state.orders.isEmpty {
            emptyContent()
        } else {
            ListSection(
                orders: viewModel.state.orders,
                nextPageStatus: viewModel.state.api.fetchNextPage,
                hasMore: viewModel.state.paging.hasMore,
                send: handleListAction
            )
        }
    }

    @ViewBuilder private func emptyContent() -> some View {
        switch viewModel.state.api.fetchFirstPage {
        case .prepare, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .error(message):
            ContentUnavailableView {
                Label("載入失敗", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("重新載入") {
                    Task { await viewModel.doAction(.view(.retryFirstPageDidTap)) }
                }
            }

        case .success:
            ContentUnavailableView("目前沒有訂單", systemImage: "tray")
        }
    }

    @MainActor private func handleListAction(_ action: ListSection.Action) {
        switch action {
        case .footerDidAppear:
            Task { await viewModel.doAction(.view(.listFooterDidAppear)) }
        case .nextPageRetryDidTap:
            Task { await viewModel.doAction(.view(.retryNextPageDidTap)) }
        }
    }
}

// MARK: - L2 / L3

private extension OrderListView {
    struct ListSection: View {
        enum Action: Sendable {
            case footerDidAppear
            case nextPageRetryDidTap
        }

        let orders: [OrderListViewModel.Order]
        let nextPageStatus: APIStatus
        let hasMore: Bool
        let send: @MainActor (Action) -> Void

        var body: some View {
            List {
                // ListRow 不持有 @State，ForEach 的 Identifiable 身份已足夠，
                // 不需要額外 .id()（見 architecture.md §8 的適用條件）
                ForEach(orders) { order in
                    ListRow(order: order)
                }

                ListFooter(status: nextPageStatus, hasMore: hasMore) { action in
                    switch action {
                    case .didAppear: send(.footerDidAppear)
                    case .retryDidTap: send(.nextPageRetryDidTap)
                    }
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }

    /// 純展示，無互動 → 不需要 enum Action
    struct ListRow: View {
        let order: OrderListViewModel.Order

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(order.customerName)
                        .font(.headline)
                    Spacer()
                    Text(order.status.displayName)
                        .font(.caption)
                        .foregroundStyle(order.status.color)
                }

                Text(order.productName)
                    .font(.subheadline)

                HStack {
                    Text("數量 \(order.quantity)")
                    Spacer()
                    Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    /// 觸底載入的觸發點與狀態指示。
    /// 只回報「我出現了」，要不要真的載入由 ViewModel 判斷。
    struct ListFooter: View {
        enum Action: Sendable {
            case didAppear
            case retryDidTap
        }

        let status: APIStatus
        let hasMore: Bool
        let send: @MainActor (Action) -> Void

        var body: some View {
            Group {
                if hasMore {
                    switch status {
                    case let .error(message):
                        VStack(spacing: 8) {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("重試") { send(.retryDidTap) }
                                .buttonStyle(.bordered)
                        }
                    default:
                        ProgressView()
                    }
                } else {
                    Text("沒有更多了")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .onAppear { send(.didAppear) }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("有資料 · 還有下一頁") {
    let vm = OrderListViewModel()
    vm.state.orders = OrderListViewModel.Order.mocks
    vm.state.api.fetchFirstPage = .success
    vm.state.paging = .init(nextPage: 2, hasMore: true)
    return OrderListView(viewModel: vm)
}

#Preview("有資料 · 下一頁失敗") {
    let vm = OrderListViewModel()
    vm.state.orders = OrderListViewModel.Order.mocks
    vm.state.api.fetchFirstPage = .success
    vm.state.api.fetchNextPage = .error("連線逾時")
    vm.state.paging = .init(nextPage: 2, hasMore: true)
    return OrderListView(viewModel: vm)
}

#Preview("有資料 · 全部載完") {
    let vm = OrderListViewModel()
    vm.state.orders = OrderListViewModel.Order.mocks
    vm.state.api.fetchFirstPage = .success
    vm.state.paging = .init(nextPage: 3, hasMore: false)
    return OrderListView(viewModel: vm)
}

#Preview("首次載入失敗") {
    let vm = OrderListViewModel()
    vm.state.api.fetchFirstPage = .error("無法連線到伺服器")
    return OrderListView(viewModel: vm)
}

#Preview("空狀態") {
    let vm = OrderListViewModel()
    vm.state.api.fetchFirstPage = .success
    return OrderListView(viewModel: vm)
}
#endif
