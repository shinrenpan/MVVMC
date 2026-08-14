//
//  InventoryListView.swift
//  V
//

import SwiftUI

// MARK: - Display Helper（Model → UI 呈現，屬 V 層決策，放檔案頂端）

private extension InventoryListViewModel.LiveTotal {
    var totalText: String {
        totalQuantity.formatted()
    }

    var syncedText: String {
        syncedAt.formatted(date: .omitted, time: .standard)
    }
}

// MARK: - L1

struct InventoryListView: View {
    let viewModel: InventoryListViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 高頻更新區塊 → 獨立 struct。輪詢只改 liveTotal / api.syncTotal，
            // ListSection 的 props 不變 → SwiftUI 直接跳過整個列表的 body
            SyncSection(
                liveTotal: viewModel.state.liveTotal,
                status: viewModel.state.api.syncTotal
            )

            contentSection()
        }
        .navigationTitle("庫存")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.doAction(.view(.pullToRefresh))
        }
        // 兩個 .task 都掛在 L1 的穩定容器上：
        // 1. 掛在子組件會壞掉——子組件收到的 send 是同步 closure，輪詢鏈會立刻被取消
        // 2. 掛在 contentSection() 的 if/else 分支內會在載入完成時被取消重建
        .task {
            await viewModel.doAction(.view(.isFirstAppear))
        }
        .task {
            await viewModel.doAction(.view(.syncDidAppear))
        }
    }

    // body 拆分用 @ViewBuilder func，不用 computed property
    @ViewBuilder private func contentSection() -> some View {
        // 判斷順序：先看有沒有內容，再看狀態。
        // 反過來寫的話，「第 2 頁載入失敗」會落進 .error 分支，把使用者眼前的清單整個換掉。
        if viewModel.state.isEmpty {
            switch viewModel.state.api.fetchItems {
            case .prepare, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case let .error(message):
                // 首次載入失敗 → 整頁空白 + 錯誤
                ContentUnavailableView(message, systemImage: "exclamationmark.triangle")

            case .success:
                ContentUnavailableView("目前沒有庫存品項", systemImage: "shippingbox")
            }
        } else {
            // 已經有內容：內容永遠留著，載入中／失敗只表現成 footer 的附加提示
            ListSection(
                items: viewModel.state.items,
                hasMore: viewModel.state.hasMore,
                loadMoreStatus: viewModel.state.api.fetchMoreItems,
                send: handleListAction
            )
        }
    }

    @MainActor private func handleListAction(_ action: ListSection.Action) {
        switch action {
        case let .rowDidTap(item):
            Task { await viewModel.doAction(.view(.itemDidTap(item))) }

        case .bottomDidReach:
            Task { await viewModel.doAction(.view(.listBottomDidReach)) }

        case .retryDidTap:
            Task { await viewModel.doAction(.view(.loadMoreRetryDidTap)) }
        }
    }
}

// MARK: - Sync 家族

private extension InventoryListView {
    // L2：純展示，無互動 → 不定義 enum Action
    struct SyncSection: View {
        let liveTotal: InventoryListViewModel.LiveTotal?
        let status: APIStatus

        var body: some View {
            HStack(spacing: 8) {
                Label("即時同步", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                detail()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }

        @ViewBuilder private func detail() -> some View {
            if let liveTotal {
                // 有值就永遠顯示值：輪詢失敗不該把使用者剛剛看到的總量清掉
                VStack(alignment: .trailing, spacing: 2) {
                    Text("總庫存 \(liveTotal.totalText)")
                        .font(.footnote.weight(.semibold))
                        .contentTransition(.numericText())

                    Text(syncedNote(liveTotal.syncedText))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                switch status {
                case .prepare, .loading:
                    ProgressView()
                        .controlSize(.small)

                case let .error(message):
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                case .success:
                    EmptyView()
                }
            }
        }

        private func syncedNote(_ time: String) -> String {
            if case .error = status {
                return "同步失敗，顯示 \(time) 的資料"
            }
            return "更新於 \(time)"
        }
    }
}

// MARK: - List 家族（同前綴組件放同一個 private extension）

private extension InventoryListView {
    // L2
    struct ListSection: View {
        enum Action: Sendable {
            case rowDidTap(InventoryListViewModel.Item)
            case bottomDidReach
            case retryDidTap
        }

        let items: [InventoryListViewModel.Item]
        let hasMore: Bool
        let loadMoreStatus: APIStatus
        let send: @MainActor (Action) -> Void

        var body: some View {
            List {
                ForEach(items) { item in
                    ListRow(item: item) { action in
                        switch action {
                        case .rowDidTap:
                            send(.rowDidTap(item))
                        }
                    }
                    .id(item.id)
                }

                ListFooter(hasMore: hasMore, status: loadMoreStatus) { action in
                    // 真正的 Mapping：footer 說「我出現了」，列表把它翻成「捲到底了」
                    switch action {
                    case .didAppear:
                        send(.bottomDidReach)
                    case .retryDidTap:
                        send(.retryDidTap)
                    }
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }

    // L3
    struct ListRow: View {
        enum Action: Sendable {
            case rowDidTap
        }

        let item: InventoryListViewModel.Item
        let send: @MainActor (Action) -> Void

        var body: some View {
            Button {
                send(.rowDidTap)
            } label: {
                HStack {
                    Text(item.name)

                    Spacer()

                    Text(item.quantity.formatted())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    // L3
    struct ListFooter: View {
        enum Action: Sendable {
            /// 從 footer 自身視角命名：它只知道「我出現在畫面上了」
            case didAppear
            case retryDidTap
        }

        let hasMore: Bool
        let status: APIStatus
        let send: @MainActor (Action) -> Void

        var body: some View {
            content()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .onAppear { send(.didAppear) }
        }

        @ViewBuilder private func content() -> some View {
            if !hasMore {
                Text("沒有更多了")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                switch status {
                case let .error(message):
                    VStack(spacing: 8) {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("重試") { send(.retryDidTap) }
                            .buttonStyle(.bordered)
                    }

                case .prepare, .loading, .success:
                    ProgressView()
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("有資料 + 還有下一頁") {
    let vm = InventoryListViewModel()
    vm.state.isFirstAppear = false      // 少了這行，.task 會打真實 API
    vm.state.isSyncSuspended = true     // 同理，關掉輪詢迴圈
    vm.state.items = InventoryListViewModel.Item.mocks
    vm.state.liveTotal = InventoryListViewModel.LiveTotal.mock
    vm.state.api.fetchItems = .success
    vm.state.api.syncTotal = .success
    return NavigationStack { InventoryListView(viewModel: vm) }
}

#Preview("第 2 頁載入失敗（內容還在）") {
    let vm = InventoryListViewModel()
    vm.state.isFirstAppear = false
    vm.state.isSyncSuspended = true
    vm.state.items = InventoryListViewModel.Item.mocks
    vm.state.liveTotal = InventoryListViewModel.LiveTotal.mock
    vm.state.api.fetchItems = .success
    vm.state.api.fetchMoreItems = .error("連線逾時")
    return NavigationStack { InventoryListView(viewModel: vm) }
}

#Preview("首次載入失敗（整頁空白）") {
    let vm = InventoryListViewModel()
    vm.state.isFirstAppear = false
    vm.state.isSyncSuspended = true
    vm.state.api.fetchItems = .error("無法載入庫存清單")
    return NavigationStack { InventoryListView(viewModel: vm) }
}

#Preview("全部載完") {
    let vm = InventoryListViewModel()
    vm.state.isFirstAppear = false
    vm.state.isSyncSuspended = true
    vm.state.items = InventoryListViewModel.Item.mocks
    vm.state.hasMore = false
    vm.state.api.fetchItems = .success
    return NavigationStack { InventoryListView(viewModel: vm) }
}
#endif
