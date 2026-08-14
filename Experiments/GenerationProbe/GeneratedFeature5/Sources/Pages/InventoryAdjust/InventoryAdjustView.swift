//
//  InventoryAdjustView.swift
//  V
//

import SwiftUI

// MARK: - Display Helper（文案與顏色都是 V 層的顯示決策）

private extension InventoryAdjustViewModel.AdjustReason {
    var title: String {
        switch self {
        case .restock: "進貨補充"
        case .damaged: "損壞報廢"
        case .stocktake: "盤點校正"
        case .returned: "退貨入庫"
        }
    }
}

// MARK: - L1

struct InventoryAdjustView: View {
    let viewModel: InventoryAdjustViewModel

    var body: some View {
        // @Bindable 只在 body 宣告一次，子元件只收切片
        @Bindable var bVM = viewModel

        Form {
            HeaderSection(
                itemName: viewModel.state.itemName,
                currentQuantity: viewModel.state.currentQuantity,
                previewQuantity: viewModel.state.previewQuantity
            )

            FormSection(
                quantityText: $bVM.state.quantityText,
                reason: $bVM.state.reason,
                note: $bVM.state.note,
                isEditable: !viewModel.state.isSubmitting
            )

            SubmitSection(
                isValid: viewModel.state.isValid,
                status: viewModel.state.api.submit,
                send: handleSubmitAction
            )
        }
        .navigationTitle("調整庫存")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor private func handleSubmitAction(_ action: SubmitSection.Action) {
        switch action {
        case .submitDidTap:
            Task { await viewModel.doAction(.view(.submitDidTap)) }
        }
    }
}

// MARK: - Header 家族

private extension InventoryAdjustView {
    // L2：純展示 → 不定義 enum Action
    struct HeaderSection: View {
        let itemName: String
        let currentQuantity: Int
        let previewQuantity: Int?

        var body: some View {
            Section("品項") {
                LabeledContent("名稱", value: itemName)

                LabeledContent("目前庫存") {
                    Text(currentQuantity.formatted())
                        .monospacedDigit()
                }

                if let previewQuantity {
                    LabeledContent("調整後") {
                        Text(previewQuantity.formatted())
                            .monospacedDigit()
                            .foregroundStyle(previewQuantity < 0 ? .red : .primary)
                    }
                }
            }
        }
    }
}

// MARK: - Form 家族

private extension InventoryAdjustView {
    // L2：欄位都是「值的雙向同步」→ 一律 @Binding，沒有需要通知父層的事件，故無 enum Action。
    // 表單頁收 3 個 Binding 是規範明講的合理情形（Binding 無法打包成 Model slice）。
    struct FormSection: View {
        @Binding var quantityText: String
        @Binding var reason: InventoryAdjustViewModel.AdjustReason?
        @Binding var note: String
        let isEditable: Bool

        var body: some View {
            Section("調整內容") {
                LabeledContent("調整數量") {
                    TextField("可正可負，例：-5", text: $quantityText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numbersAndPunctuation)
                        .monospacedDigit()
                }

                Picker("調整原因", selection: $reason) {
                    Text("請選擇").tag(InventoryAdjustViewModel.AdjustReason?.none)

                    ForEach(InventoryAdjustViewModel.AdjustReason.allCases, id: \.self) { item in
                        Text(item.title).tag(InventoryAdjustViewModel.AdjustReason?.some(item))
                    }
                }

                LabeledContent("備註（選填）") {
                    TextField("選填", text: $note)
                        .multilineTextAlignment(.trailing)
                }
            }
            // 送出中整個表單不可編輯。這是「版面」，View 自己依 state 判斷即可；
            // 「不能重複送出」的保證另外由 VM 的 guard 負責。
            .disabled(!isEditable)
        }
    }
}

// MARK: - Submit 家族

private extension InventoryAdjustView {
    // L2
    struct SubmitSection: View {
        enum Action: Sendable {
            case submitDidTap
        }

        let isValid: Bool
        let status: APIStatus
        let send: @MainActor (Action) -> Void

        private var isSubmitting: Bool { status == .loading }

        var body: some View {
            Section {
                Button {
                    send(.submitDidTap)
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("送出")
                        }
                        Spacer()
                    }
                }
                .disabled(!isValid || isSubmitting)
            } footer: {
                // 失敗訊息在這裡顯示；輸入緩衝完全沒被動過，使用者填的東西還在
                if case let .error(message) = status {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Preview

// 本頁沒有 run-once 的 `.task`，也沒有輪詢，所以 Preview 不會觸發任何網路請求。
#if DEBUG
#Preview("空表單（送出停用）") {
    let vm = InventoryAdjustViewModel(itemID: "SKU-001", itemName: "藍芽耳機", currentQuantity: 42)
    vm.state = InventoryAdjustViewModel.State.mock
    return NavigationStack { InventoryAdjustView(viewModel: vm) }
}

#Preview("填妥可送出") {
    let vm = InventoryAdjustViewModel(itemID: "SKU-001", itemName: "藍芽耳機", currentQuantity: 42)
    vm.state = InventoryAdjustViewModel.State.filledMock
    return NavigationStack { InventoryAdjustView(viewModel: vm) }
}

#Preview("送出中（表單鎖定）") {
    let vm = InventoryAdjustViewModel(itemID: "SKU-001", itemName: "藍芽耳機", currentQuantity: 42)
    vm.state = InventoryAdjustViewModel.State.submittingMock
    return NavigationStack { InventoryAdjustView(viewModel: vm) }
}

#Preview("送出失敗（輸入保留）") {
    let vm = InventoryAdjustViewModel(itemID: "SKU-001", itemName: "藍芽耳機", currentQuantity: 42)
    vm.state = InventoryAdjustViewModel.State.failedMock
    return NavigationStack { InventoryAdjustView(viewModel: vm) }
}
#endif
