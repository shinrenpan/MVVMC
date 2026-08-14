import SwiftUI

// MARK: - Display Helper（Model → UI 型別 / 顯示文案）

private extension ReturnRequestViewModel.ReturnReason {
    var title: String {
        switch self {
        case .damaged: "商品破損"
        case .wrongItem: "出貨錯誤"
        case .notAsDescribed: "與描述不符"
        case .missingParts: "缺少配件"
        case .changedMind: "不想要了"
        }
    }

    var systemImage: String {
        switch self {
        case .damaged: "exclamationmark.triangle"
        case .wrongItem: "shippingbox.and.arrow.backward"
        case .notAsDescribed: "text.badge.xmark"
        case .missingParts: "puzzlepiece"
        case .changedMind: "hand.raised"
        }
    }
}

private extension ReturnRequestViewModel.Step {
    var title: String {
        switch self {
        case .selectItems: "選擇退貨商品"
        case .reason: "填寫退貨原因"
        case .confirm: "確認退貨內容"
        }
    }

    var progressText: String {
        "步驟 \(rawValue + 1) / \(Self.allCases.count)"
    }
}

// MARK: - L1

struct ReturnRequestView: View {
    let viewModel: ReturnRequestViewModel

    var body: some View {
        @Bindable var bVM = viewModel

        // 1. 傳的是 `$bVM`（型別 Bindable<VM>），不是 `bVM`（型別 VM）。
        //    mvvmc-view §11 的範例寫成 `userSection(bVM: bVM)` 再於 func 內用 `$bVM.state...`，
        //    兩處各差一個 `$`，照抄會編不過（見報告〈規範空白 #5〉）。
        // 2. 外面包 ZStack：content 內是 switch step，分支翻轉會換掉 view 身分，
        //    直接把 `.task` / `.alert` 掛在上面會在換頁時被連帶重建。
        ZStack {
            content(bVM: $bVM)
        }
        .navigationTitle(viewModel.state.step.title)
        .navigationBarTitleDisplayMode(.inline)
        // 三個 step 在同一頁，所以要擋掉系統返回鈕，改用自己的「上一步」
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    Task { await viewModel.doAction(.view(.cancelButtonDidTap)) }
                }
                .disabled(viewModel.state.isSubmitting)
            }

            ToolbarItem(placement: .principal) {
                Text(viewModel.state.step.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            FooterSection(
                step: viewModel.state.step,
                isPrimaryEnabled: viewModel.state.canProceed,
                isSubmitting: viewModel.state.isSubmitting,
                send: handleFooterAction
            )
        }
        .task {
            await viewModel.doAction(.view(.isFirstAppear))
        }
        // 「要不要顯示」是值的雙向同步 → @Bindable；「按了什麼」才是事件 → doAction
        .alert("尚未送出的內容會遺失", isPresented: $bVM.state.isShowingCancelAlert) {
            Button("繼續填寫", role: .cancel) {}

            Button("放棄申請", role: .destructive) {
                Task { await viewModel.doAction(.view(.discardDidConfirm)) }
            }
        } message: {
            Text("離開後已選擇的商品與填寫的原因都不會保留。")
        }
    }

    // MARK: Action handlers（L1 協調邏輯，與 body 同層）

    @MainActor
    private func handleSelectItemsAction(_ action: SelectItemsSection.Action) {
        switch action {
        case let .itemDidSelect(id):
            Task { await viewModel.doAction(.view(.itemDidTap(id: id))) }
        }
    }

    @MainActor
    private func handleReasonAction(_ action: ReasonSection.Action) {
        switch action {
        case let .reasonDidSelect(reason):
            Task { await viewModel.doAction(.view(.reasonDidTap(reason))) }
        }
    }

    @MainActor
    private func handleFooterAction(_ action: FooterSection.Action) {
        switch action {
        case .primaryDidTap:
            Task { await viewModel.doAction(.view(.primaryButtonDidTap)) }

        case .backDidTap:
            Task { await viewModel.doAction(.view(.backButtonDidTap)) }
        }
    }

    // MARK: body 拆分

    @ViewBuilder private func content(bVM: Bindable<ReturnRequestViewModel>) -> some View {
        switch viewModel.state.step {
        case .selectItems:
            selectItemsStep()

        case .reason:
            ReasonSection(
                selected: viewModel.state.reason,
                note: bVM.state.note,
                send: handleReasonAction
            )

        case .confirm:
            ConfirmSection(
                items: viewModel.state.selectedItems,
                reason: viewModel.state.reason,
                note: viewModel.state.note,
                submitStatus: viewModel.state.api.submit
            )
        }
    }

    @ViewBuilder private func selectItemsStep() -> some View {
        // 先看有沒有內容，再看狀態
        if viewModel.state.items.isEmpty {
            switch viewModel.state.api.fetchItems {
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
                ContentUnavailableView("這筆訂單沒有可退貨的商品", systemImage: "tray")
            }
        }
        else {
            SelectItemsSection(
                items: viewModel.state.items,
                selectedIDs: viewModel.state.selectedItemIDs,
                send: handleSelectItemsAction
            )
        }
    }
}

// MARK: - SelectItems 家族（步驟 1）

private extension ReturnRequestView {
    struct SelectItemsSection: View {
        enum Action: Sendable {
            case itemDidSelect(id: String)
        }

        let items: [ReturnRequestViewModel.ReturnableItem]
        let selectedIDs: Set<String>
        let send: @MainActor (Action) -> Void

        var body: some View {
            List {
                Section {
                    ForEach(items) { item in
                        SelectItemsRow(item: item, isSelected: selectedIDs.contains(item.id)) { action in
                            switch action {
                            case .rowDidTap:
                                // 中間層做真正的 Mapping：補上「是哪一筆」
                                send(.itemDidSelect(id: item.id))
                            }
                        }
                    }
                } footer: {
                    Text("至少選擇一項商品才能進入下一步。")
                }
            }
        }
    }

    struct SelectItemsRow: View {
        enum Action: Sendable {
            case rowDidTap
        }

        let item: ReturnRequestViewModel.ReturnableItem
        let isSelected: Bool
        let send: @MainActor (Action) -> Void

        var body: some View {
            Button {
                send(.rowDidTap)
            } label: {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.productName)
                        Text("x\(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(item.subtotal.formatted(.currency(code: "TWD")))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Reason 家族（步驟 2）

private extension ReturnRequestView {
    struct ReasonSection: View {
        enum Action: Sendable {
            case reasonDidSelect(ReturnRequestViewModel.ReturnReason)
        }

        let selected: ReturnRequestViewModel.ReturnReason?
        /// 補充說明是「值的雙向同步」→ Binding；原因選取是「事件」→ Action（見 mvvmc-view §2）
        @Binding var note: String
        let send: @MainActor (Action) -> Void

        var body: some View {
            List {
                Section("退貨原因") {
                    ForEach(ReturnRequestViewModel.ReturnReason.allCases) { reason in
                        ReasonRow(reason: reason, isSelected: selected == reason) { action in
                            switch action {
                            case .rowDidTap:
                                send(.reasonDidSelect(reason))
                            }
                        }
                    }
                }

                Section("補充說明（選填）") {
                    TextField("例如：外盒凹陷、螢幕有刮痕…", text: $note, axis: .vertical)
                        .lineLimit(3 ... 6)
                }
            }
        }
    }

    struct ReasonRow: View {
        enum Action: Sendable {
            case rowDidTap
        }

        let reason: ReturnRequestViewModel.ReturnReason
        let isSelected: Bool
        let send: @MainActor (Action) -> Void

        var body: some View {
            Button {
                send(.rowDidTap)
            } label: {
                HStack {
                    Label(reason.title, systemImage: reason.systemImage)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Confirm 家族（步驟 3）

private extension ReturnRequestView {
    /// 純展示元件：送出按鈕在 FooterSection，這裡沒有互動 → 不定義 enum Action
    struct ConfirmSection: View {
        let items: [ReturnRequestViewModel.ReturnableItem]
        let reason: ReturnRequestViewModel.ReturnReason?
        let note: String
        let submitStatus: APIStatus

        var body: some View {
            List {
                Section("退貨商品") {
                    ForEach(items) { item in
                        LabeledContent(item.productName) {
                            Text("x\(item.quantity)")
                        }
                    }

                    LabeledContent("預計退款金額") {
                        Text(refundAmount.formatted(.currency(code: "TWD")))
                            .monospacedDigit()
                    }
                    .font(.headline)
                }

                Section("退貨原因") {
                    if let reason {
                        Label(reason.title, systemImage: reason.systemImage)
                    }

                    if !note.isEmpty {
                        Text(note)
                            .foregroundStyle(.secondary)
                    }
                }

                if case let .error(message) = submitStatus {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
        }

        private var refundAmount: Double {
            items.reduce(0) { $0 + $1.subtotal }
        }
    }
}

// MARK: - Footer 家族

private extension ReturnRequestView {
    struct FooterSection: View {
        enum Action: Sendable {
            case backDidTap
            case primaryDidTap
        }

        let step: ReturnRequestViewModel.Step
        let isPrimaryEnabled: Bool
        let isSubmitting: Bool
        let send: @MainActor (Action) -> Void

        var body: some View {
            HStack(spacing: 12) {
                if step != .selectItems {
                    Button("上一步") {
                        send(.backDidTap)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isSubmitting)
                }

                Button {
                    send(.primaryDidTap)
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    else {
                        Text(step == .confirm ? "送出退貨申請" : "下一步")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isPrimaryEnabled || isSubmitting)
            }
            .padding()
            .background(.bar)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("步驟 1：選擇商品") {
    let vm = ReturnRequestViewModel(orderID: "ORD-1001")
    vm.state.items = ReturnRequestViewModel.ReturnableItem.mocks
    vm.state.api.fetchItems = .success

    return NavigationStack {
        ReturnRequestView(viewModel: vm)
    }
}

#Preview("步驟 2：填寫原因") {
    let vm = ReturnRequestViewModel(orderID: "ORD-1001")
    vm.state.items = ReturnRequestViewModel.ReturnableItem.mocks
    vm.state.api.fetchItems = .success
    vm.state.selectedItemIDs = ["ITEM-1"]
    vm.state.step = .reason

    return NavigationStack {
        ReturnRequestView(viewModel: vm)
    }
}

#Preview("步驟 3：確認") {
    let vm = ReturnRequestViewModel(orderID: "ORD-1001")
    vm.state.items = ReturnRequestViewModel.ReturnableItem.mocks
    vm.state.api.fetchItems = .success
    vm.state.selectedItemIDs = ["ITEM-1", "ITEM-2"]
    vm.state.reason = .damaged
    vm.state.note = "外盒嚴重凹陷"
    vm.state.step = .confirm

    return NavigationStack {
        ReturnRequestView(viewModel: vm)
    }
}

#Preview("步驟 3：送出失敗") {
    let vm = ReturnRequestViewModel(orderID: "ORD-1001")
    vm.state.items = ReturnRequestViewModel.ReturnableItem.mocks
    vm.state.api.fetchItems = .success
    vm.state.selectedItemIDs = ["ITEM-1"]
    vm.state.reason = .wrongItem
    vm.state.step = .confirm
    vm.state.api.submit = .error("伺服器忙碌中，請稍後再試")

    return NavigationStack {
        ReturnRequestView(viewModel: vm)
    }
}
#endif
