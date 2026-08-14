//
//  OrderCreateView.swift
//  V
//

import SwiftUI

// MARK: - L1

struct OrderCreateView: View {
    let viewModel: OrderCreateViewModel

    var body: some View {
        @Bindable var bVM = viewModel

        Form {
            DraftSection(
                draft: $bVM.state.draft,
                isEditable: !viewModel.state.isSubmitting
            )

            SubmitSection(
                isEnabled: viewModel.state.canSubmit,
                isSubmitting: viewModel.state.isSubmitting,
                errorMessage: viewModel.state.errorMessage,
                send: handleSubmitAction
            )
        }
        .navigationTitle("新增訂單")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor private func handleSubmitAction(_ action: SubmitSection.Action) {
        switch action {
        case .submitDidTap:
            Task { await viewModel.doAction(.view(.submitDidTap)) }
        }
    }
}

// MARK: - L2

private extension OrderCreateView {
    /// 純值同步 → 只收 Draft 這一片 Binding，不需要 enum Action
    struct DraftSection: View {
        @Binding var draft: OrderCreateViewModel.Draft
        let isEditable: Bool

        var body: some View {
            Section("訂單資訊") {
                TextField("客戶名稱", text: $draft.customerName)
                    .textInputAutocapitalization(.never)

                TextField("商品名稱", text: $draft.productName)
                    .textInputAutocapitalization(.never)

                TextField("數量", text: $draft.quantityText)
                    .keyboardType(.numberPad)

                TextField("備註（選填）", text: $draft.note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .disabled(!isEditable)
        }
    }

    struct SubmitSection: View {
        enum Action: Sendable {
            case submitDidTap
        }

        let isEnabled: Bool
        let isSubmitting: Bool
        let errorMessage: String?
        let send: @MainActor (Action) -> Void

        var body: some View {
            Section {
                Button {
                    send(.submitDidTap)
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("送出")
                        }
                        Spacer()
                    }
                }
                .disabled(!isEnabled)
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("空表單 · 送出停用") {
    OrderCreateView(viewModel: OrderCreateViewModel())
}

#Preview("填寫完成") {
    let vm = OrderCreateViewModel()
    vm.state.draft = OrderCreateViewModel.Draft.mock
    return OrderCreateView(viewModel: vm)
}

#Preview("送出中") {
    let vm = OrderCreateViewModel()
    vm.state.draft = OrderCreateViewModel.Draft.mock
    vm.state.api.createOrder = .loading
    return OrderCreateView(viewModel: vm)
}

#Preview("送出失敗 · 內容保留") {
    let vm = OrderCreateViewModel()
    vm.state.draft = OrderCreateViewModel.Draft.mock
    vm.state.api.createOrder = .error("建立訂單失敗，請稍後再試")
    return OrderCreateView(viewModel: vm)
}
#endif
