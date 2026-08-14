//
//  ReturnItemSelectView.swift
//  MVVMC
//

import SwiftUI

// MARK: - L1

struct ReturnItemSelectView: View {
  let viewModel: ReturnItemSelectViewModel

  var body: some View {
    @Bindable var bVM = viewModel

    contentSection()
      .navigationTitle("選擇退貨商品")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
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

private extension ReturnItemSelectView {
  /// 四態呈現：先看有沒有內容，再看狀態
  @ViewBuilder func contentSection() -> some View {
    if viewModel.state.items.isEmpty {
      switch viewModel.state.api.fetchItems {
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
        ContentUnavailableView("這筆訂單沒有可退貨的商品", systemImage: "shippingbox")
      }
    } else {
      ListSection(
        items: viewModel.state.items,
        selectedIDs: viewModel.state.selectedIDs,
        send: handleListAction
      )
    }
  }

  @ViewBuilder func bottomBar() -> some View {
    VStack(spacing: 4) {
      Button {
        Task { await viewModel.doAction(.view(.nextButtonDidTap)) }
      } label: {
        Text("下一步").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(!viewModel.state.canGoNext)

      Text("已選 \(viewModel.state.selectedIDs.count) 項")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .background(.bar)
  }

  @MainActor func handleListAction(_ action: ListSection.Action) {
    switch action {
    case let .itemDidTap(id):
      Task { await viewModel.doAction(.view(.itemDidTap(id: id))) }
    }
  }
}

// MARK: - L2 / L3

private extension ReturnItemSelectView {
  struct ListSection: View {
    enum Action: Sendable {
      case itemDidTap(id: String)
    }

    let items: [ReturnItemSelectViewModel.ReturnableItem]
    let selectedIDs: Set<String>
    let send: @MainActor (Action) -> Void

    var body: some View {
      List(items) { item in
        ListRow(item: item, isSelected: selectedIDs.contains(item.id)) { action in
          switch action {
          case .rowDidTap:
            // 真正的 Mapping：Row 只知道「我被點了」，由本層補上是哪一筆
            send(.itemDidTap(id: item.id))
          }
        }
      }
      .listStyle(.plain)
    }
  }

  struct ListRow: View {
    enum Action: Sendable {
      case rowDidTap
    }

    let item: ReturnItemSelectViewModel.ReturnableItem
    let isSelected: Bool
    let send: @MainActor (Action) -> Void

    var body: some View {
      Button {
        send(.rowDidTap)
      } label: {
        HStack {
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
          VStack(alignment: .leading) {
            Text(item.name)
            Text("數量 \(item.quantity)").font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Text(item.unitPrice, format: .currency(code: "TWD"))
            .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - Preview

#if DEBUG
#Preview("有可退商品") {
  let vm = ReturnItemSelectViewModel(orderID: "10001")
  vm.state.items = ReturnItemSelectViewModel.ReturnableItem.mocks
  vm.state.selectedIDs = ["I-1"]
  vm.state.api.fetchItems = .success
  return NavigationStack { ReturnItemSelectView(viewModel: vm) }
}

#Preview("空狀態") {
  let vm = ReturnItemSelectViewModel(orderID: "10001")
  vm.state.api.fetchItems = .success
  return NavigationStack { ReturnItemSelectView(viewModel: vm) }
}
#endif
