import SwiftUI

struct UserDetailView: View {
  let viewModel: UserDetailViewModel

  var body: some View {
    Group {
      // 四態：先看有沒有內容，再看狀態（`mvvmc-view` 規則 13）——與 PostListView 同一個形狀
      if let user = viewModel.state.user {
        InfoSection(user: user)
      } else {
        switch viewModel.state.api.fetchUser {
        case .prepare, .loading:
          ProgressView()
        case let .error(message):
          ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
        case .success:
          ContentUnavailableView("User Not Found", systemImage: "person.slash")
        }
      }
    }
    .navigationTitle(viewModel.state.user?.name ?? "User \(viewModel.userId)")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }
}

// MARK: - Subviews

private extension UserDetailView {
  // L2：純展示元件 —— 無使用者互動，依規範不需要 enum Action
  struct InfoSection: View {
    let user: UserDetailViewModel.User

    var body: some View {
      List {
        Section {
          LabeledContent("Name", value: user.name)
          LabeledContent("Email", value: user.email)
          LabeledContent("Company", value: user.company)
        }
      }
    }
  }
}

#if DEBUG
#Preview {
  let vm = UserDetailViewModel(userId: 1)
  vm.state.isFirstAppear = false   // 否則 .task 會在 Preview 觸發真實 API
  vm.state.user = UserDetailViewModel.User.mock
  return NavigationStack {
    UserDetailView(viewModel: vm)
  }
}
#endif
