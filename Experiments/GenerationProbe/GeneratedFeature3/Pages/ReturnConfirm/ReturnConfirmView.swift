//
//  ReturnConfirmView.swift
//  MVVMC
//

import SwiftUI

// MARK: - L1

struct ReturnConfirmView: View {
  let viewModel: ReturnConfirmViewModel

  var body: some View {
    @Bindable var bVM = viewModel

    contentSection()
      .navigationTitle("確認退貨內容")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            Task { await viewModel.doAction(.view(.backButtonDidTap)) }
          } label: {
            Label("上一步", systemImage: "chevron.left")
          }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            Task { await viewModel.doAction(.view(.cancelButtonDidTap)) }
          }
        }
      }
      .safeAreaInset(edge: .bottom) { bottomBar() }
      .alert("放棄退貨申請？", isPresented: $bVM.state.isShowingCancelAlert) {
        Button("繼續填寫", role: .cancel) {}
        Button("放棄", role: .destructive) {
          Task { await viewModel.doAction(.view(.cancelAlertDidConfirm)) }
        }
      } message: {
        Text("已填寫的內容不會保留。")
      }
      .task { await viewModel.doAction(.view(.isFirstAppear)) }
  }
}

// MARK: - body 拆分

private extension ReturnConfirmView {
  @ViewBuilder func contentSection() -> some View {
    if let summary = viewModel.state.summary {
      List {
        ItemsSection(items: summary.items)
        ReasonSection(reasonTitle: summary.reasonTitle, note: viewModel.state.note)
        AmountSection(refundAmount: summary.refundAmount, estimatedDays: summary.estimatedDays)
      }
    } else {
      switch viewModel.state.api.fetchSummary {
      case .prepare, .loading:
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      case let .error(message):
        ContentUnavailableView {
          Label(message, systemImage: "exclamationmark.triangle")
        } actions: {
          Button("重試") {
            Task { await viewModel.doAction(.view(.retryButtonDidTap)) }
          }
        }
      case .success:
        ContentUnavailableView("沒有可確認的內容", systemImage: "tray")
      }
    }
  }

  @ViewBuilder func bottomBar() -> some View {
    VStack(spacing: 8) {
      // 送出失敗：內容留著，錯誤訊息以附加提示呈現
      if case let .error(message) = viewModel.state.api.submit {
        Label(message, systemImage: "exclamationmark.circle")
          .font(.caption)
          .foregroundStyle(.red)
      }

      Button {
        Task { await viewModel.doAction(.view(.submitButtonDidTap)) }
      } label: {
        if case .loading = viewModel.state.api.submit {
          ProgressView().frame(maxWidth: .infinity)
        } else {
          Text("送出退貨申請").frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(!viewModel.state.canSubmit)
    }
    .padding()
    .background(.bar)
  }
}

// MARK: - L2 / L3

private extension ReturnConfirmView {
  struct ItemsSection: View {
    let items: [ReturnConfirmViewModel.SummaryItem]

    var body: some View {
      Section("退貨商品") {
        ForEach(items) { item in
          ItemsRow(item: item)
        }
      }
    }
  }

  struct ItemsRow: View {
    let item: ReturnConfirmViewModel.SummaryItem

    var body: some View {
      HStack {
        Text(item.name)
        Spacer()
        Text("×\(item.quantity)").foregroundStyle(.secondary)
      }
    }
  }

  struct ReasonSection: View {
    let reasonTitle: String
    let note: String

    var body: some View {
      Section("退貨原因") {
        Text(reasonTitle)
        if !note.isEmpty {
          Text(note).font(.callout).foregroundStyle(.secondary)
        }
      }
    }
  }

  struct AmountSection: View {
    let refundAmount: Decimal
    let estimatedDays: Int

    var body: some View {
      Section("退款資訊") {
        LabeledContent("預計退款") {
          Text(refundAmount, format: .currency(code: "TWD"))
        }
        LabeledContent("作業時間", value: "約 \(estimatedDays) 個工作天")
      }
    }
  }
}

// MARK: - Preview

#if DEBUG
#Preview("摘要已載入") {
  let vm = ReturnConfirmViewModel(
    orderID: "10001",
    itemIDs: ["I-1", "I-2"],
    reasonCode: "damaged",
    note: "外盒凹陷"
  )
  vm.state.summary = ReturnConfirmViewModel.Summary.mock
  vm.state.api.fetchSummary = .success
  return NavigationStack { ReturnConfirmView(viewModel: vm) }
}

#Preview("送出失敗") {
  let vm = ReturnConfirmViewModel(
    orderID: "10001",
    itemIDs: ["I-1"],
    reasonCode: "damaged",
    note: ""
  )
  vm.state.summary = ReturnConfirmViewModel.Summary.mock
  vm.state.api.fetchSummary = .success
  vm.state.api.submit = .error("網路連線失敗，請稍後再試")
  return NavigationStack { ReturnConfirmView(viewModel: vm) }
}
#endif
