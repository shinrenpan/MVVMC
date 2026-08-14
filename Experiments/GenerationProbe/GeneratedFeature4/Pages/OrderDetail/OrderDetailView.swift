import SwiftUI

// MARK: - Display Helper（Model → UI 型別）

private extension OrderDetailViewModel.LiveStatusStage {
    var title: String {
        switch self {
        case .pending: "待付款"
        case .paid: "已付款"
        case .shipped: "運送中"
        case .delivered: "已送達"
        case .returning: "退貨處理中"
        case .returned: "退貨完成"
        case .cancelled: "已取消"
        }
    }

    var color: Color {
        switch self {
        case .pending: .orange
        case .paid: .blue
        case .shipped: .indigo
        case .delivered: .green
        case .returning: .purple
        case .returned: .gray
        case .cancelled: .red
        }
    }

    var systemImage: String {
        switch self {
        case .pending: "creditcard"
        case .paid: "checkmark.seal"
        case .shipped: "shippingbox"
        case .delivered: "house"
        case .returning: "arrow.uturn.backward.circle"
        case .returned: "checkmark.circle"
        case .cancelled: "xmark.circle"
        }
    }
}

// MARK: - L1

struct OrderDetailView: View {
    let viewModel: OrderDetailViewModel

    var body: some View {
        // 包一層 ZStack 是為了給 `.task` 一個「身分穩定」的掛載點：
        // content() 內部是 if/else，載入完成時分支翻轉會換掉 view 身分，
        // 直接把 `.task` 掛在 content() 上會讓輪詢在載入完成的瞬間被取消並重啟。
        ZStack {
            content()
        }
        .navigationTitle("訂單詳情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.doAction(.view(.isFirstAppear))
        }
        // 輪詢迴圈掛在 L1 的 `.task`：迴圈本體在 VM，取消由 `.task` 的生命週期負責。
        // 不能掛在 StatusSection 上——子組件只有同步的 `send`，無法 await 一條長時間執行的鏈，
        // `.task { send(...) }` 會在 send 回傳的瞬間就結束、連帶取消整條鏈。
        .task {
            await viewModel.doAction(.view(.liveStatusDidAppear))
        }
    }

    @MainActor
    private func handleFooterAction(_ action: FooterSection.Action) {
        switch action {
        case .returnRequestDidTap:
            Task { await viewModel.doAction(.view(.returnRequestButtonDidTap)) }
        }
    }

    // MARK: body 拆分（@ViewBuilder private func，不用 computed property）

    @ViewBuilder private func content() -> some View {
        // 先看有沒有內容，再看狀態（見 mvvmc-view §1〈四態呈現〉）
        if let order = viewModel.state.order {
            loadedContent(order: order)
        }
        else {
            switch viewModel.state.api.fetchOrder {
            case .prepare, .loading:
                ProgressView()

            case let .error(message):
                ContentUnavailableView {
                    Label("載入失敗", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("重試") {
                        Task { await viewModel.doAction(.view(.retryDidTap)) }
                    }
                }

            case .success:
                ContentUnavailableView("找不到這筆訂單", systemImage: "tray")
            }
        }
    }

    @ViewBuilder private func loadedContent(order: OrderDetailViewModel.Order) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // 高頻更新 → 獨立 struct，且只吃自己需要的 props。
                // 輪詢改變的只有這三個值，其餘 Section 的 props 不變 → SwiftUI 直接跳過它們的 body。
                StatusSection(
                    status: viewModel.state.liveStatus,
                    apiStatus: viewModel.state.api.fetchLiveStatus,
                    returnID: viewModel.state.latestReturnID
                )

                InfoSection(order: order)

                ItemsSection(items: order.items, totalAmount: order.totalAmount)
            }
            .padding()
        }
        .refreshable {
            await viewModel.doAction(.view(.pullToRefresh))
        }
        .safeAreaInset(edge: .bottom) {
            FooterSection(isEnabled: viewModel.state.canRequestReturn, send: handleFooterAction)
        }
    }
}

// MARK: - Status 家族

private extension OrderDetailView {
    /// 純展示元件：沒有互動 → 依 mvvmc-view §3 不定義 `enum Action`
    struct StatusSection: View {
        let status: OrderDetailViewModel.LiveStatus?
        let apiStatus: APIStatus
        let returnID: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                if let status {
                    HStack(spacing: 8) {
                        Image(systemName: status.stage.systemImage)
                            .foregroundStyle(status.stage.color)

                        Text(status.stage.title)
                            .font(.headline)
                            .foregroundStyle(status.stage.color)
                            .contentTransition(.numericText())

                        Spacer()

                        Text(status.updatedAt.formatted(date: .omitted, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let returnID {
                        Text("退貨申請編號：\(returnID)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // 已經有內容 → 失敗只能是「附加提示」，不可蓋掉使用者正在看的東西
                    if case .error = apiStatus {
                        Label("狀態更新暫時中斷", systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                else {
                    switch apiStatus {
                    case .prepare, .loading:
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("讀取即時狀態…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                    case let .error(message):
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                    case .success:
                        Text("目前沒有狀態資訊")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.background.secondary))
        }
    }
}

// MARK: - Info 家族

private extension OrderDetailView {
    struct InfoSection: View {
        let order: OrderDetailViewModel.Order

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("訂單資訊")
                    .font(.headline)

                LabeledContent("訂單編號", value: order.orderNumber)
                LabeledContent("成立時間", value: order.placedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("收件人", value: order.recipientName)
                LabeledContent("收件地址", value: order.shippingAddress)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.background.secondary))
        }
    }
}

// MARK: - Items 家族

private extension OrderDetailView {
    struct ItemsSection: View {
        let items: [OrderDetailViewModel.OrderItem]
        let totalAmount: Double

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("商品明細")
                    .font(.headline)

                ForEach(items) { item in
                    ItemsRow(item: item)
                }

                Divider()

                LabeledContent("訂單總額", value: totalAmount.formatted(.currency(code: "TWD")))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.background.secondary))
        }
    }

    struct ItemsRow: View {
        let item: OrderDetailViewModel.OrderItem

        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.productName)
                    Text("x\(item.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.subtotal.formatted(.currency(code: "TWD")))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Footer 家族

private extension OrderDetailView {
    struct FooterSection: View {
        enum Action: Sendable {
            case returnRequestDidTap
        }

        let isEnabled: Bool
        let send: @MainActor (Action) -> Void

        var body: some View {
            Button {
                send(.returnRequestDidTap)
            } label: {
                Text("申請退貨")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isEnabled)
            .padding()
            .background(.bar)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("已送達，可申請退貨") {
    let vm = OrderDetailViewModel(orderID: "ORD-1001")
    vm.state.order = OrderDetailViewModel.Order.mock
    vm.state.api.fetchOrder = .success
    vm.state.liveStatus = OrderDetailViewModel.LiveStatus.mock
    vm.state.api.fetchLiveStatus = .success

    return NavigationStack {
        OrderDetailView(viewModel: vm)
    }
}

#Preview("退貨處理中") {
    let vm = OrderDetailViewModel(orderID: "ORD-1001")
    vm.state.order = OrderDetailViewModel.Order.mock
    vm.state.api.fetchOrder = .success
    vm.state.liveStatus = OrderDetailViewModel.LiveStatus.returningMock
    vm.state.latestReturnID = "RMA-77001"
    vm.state.api.fetchLiveStatus = .success

    return NavigationStack {
        OrderDetailView(viewModel: vm)
    }
}

#Preview("載入中") {
    let vm = OrderDetailViewModel(orderID: "ORD-1001")
    vm.state.api.fetchOrder = .loading

    return NavigationStack {
        OrderDetailView(viewModel: vm)
    }
}

#Preview("載入失敗") {
    let vm = OrderDetailViewModel(orderID: "ORD-1001")
    vm.state.api.fetchOrder = .error("網路連線中斷")

    return NavigationStack {
        OrderDetailView(viewModel: vm)
    }
}
#endif
