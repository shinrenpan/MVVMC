//
//  ReturnReasonView.swift
//  MVVMC
//

import SwiftUI

// MARK: - Display Helpers（Model → UI 文案／型別，屬 V 層決策）

private extension ReturnReasonViewModel.ReasonCategory {
  var title: String {
    switch self {
    case .damaged: "商品毀損"
    case .wrongItem: "出貨錯誤"
    case .notAsDescribed: "與描述不符"
    case .changedMind: "不想要了"
    case .other: "其他"
    }
  }

  var iconName: String {
    switch self {
    case .damaged: "exclamationmark.triangle"
    case .wrongItem: "shippingbox.and.arrow.backward"
    case .notAsDescribed: "text.magnifyingglass"
    case .changedMind: "hand.thumbsdown"
    case .other: "ellipsis.circle"
    }
  }
}

// MARK: - L1

struct ReturnReasonView: View {
  let viewModel: ReturnReasonViewModel

  var body: some View {
    @Bindable var bVM = viewModel

    Form {
      ReasonSection(
        categories: ReturnReasonViewModel.ReasonCategory.allCases,
        selected: viewModel.state.reasonCategory,
        send: handleReasonAction
      )
      NoteSection(note: $bVM.state.note)
    }
    .navigationTitle("退貨原因")
    .navigationBarTitleDisplayMode(.inline)
    // 關掉系統返回鈕，改用自己的「上一步」——系統返回鈕會直接 pop，
    // 草稿就沒有機會交還給上一頁保管
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
  }
}

// MARK: - body 拆分

private extension ReturnReasonView {
  @ViewBuilder func bottomBar() -> some View {
    Button {
      Task { await viewModel.doAction(.view(.nextButtonDidTap)) }
    } label: {
      Text("下一步").frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .disabled(!viewModel.state.isValid)
    .padding()
    .background(.bar)
  }

  @MainActor func handleReasonAction(_ action: ReasonSection.Action) {
    switch action {
    case let .categoryDidTap(category):
      Task { await viewModel.doAction(.view(.categoryDidTap(category))) }
    }
  }
}

// MARK: - L2 / L3

private extension ReturnReasonView {
  struct ReasonSection: View {
    enum Action: Sendable {
      case categoryDidTap(ReturnReasonViewModel.ReasonCategory)
    }

    let categories: [ReturnReasonViewModel.ReasonCategory]
    let selected: ReturnReasonViewModel.ReasonCategory?
    let send: @MainActor (Action) -> Void

    var body: some View {
      Section("請選擇原因") {
        ForEach(categories, id: \.self) { category in
          ReasonRow(category: category, isSelected: category == selected) { action in
            switch action {
            case .rowDidTap:
              send(.categoryDidTap(category))
            }
          }
        }
      }
    }
  }

  struct ReasonRow: View {
    enum Action: Sendable {
      case rowDidTap
    }

    let category: ReturnReasonViewModel.ReasonCategory
    let isSelected: Bool
    let send: @MainActor (Action) -> Void

    var body: some View {
      Button {
        send(.rowDidTap)
      } label: {
        HStack {
          Label(category.title, systemImage: category.iconName)
          Spacer()
          if isSelected {
            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
          }
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
    }
  }

  /// 值的雙向同步 → 用 Binding，不包裝成 Action
  struct NoteSection: View {
    @Binding var note: String

    var body: some View {
      Section("補充說明（選填）") {
        TextField("例如：外盒凹陷、配件缺少…", text: $note, axis: .vertical)
          .lineLimit(3...6)
      }
    }
  }
}

// MARK: - Preview

#if DEBUG
#Preview("空白表單") {
  let vm = ReturnReasonViewModel(orderID: "10001", itemIDs: ["I-1"], reasonCode: "", note: "")
  return NavigationStack { ReturnReasonView(viewModel: vm) }
}

#Preview("已還原草稿") {
  let vm = ReturnReasonViewModel(orderID: "10001", itemIDs: ["I-1"], reasonCode: "", note: "")
  vm.state = ReturnReasonViewModel.State.filledMock
  return NavigationStack { ReturnReasonView(viewModel: vm) }
}
#endif
