import SwiftUI

struct UserDetailView: View {
  let viewModel: UserDetailViewModel

  var body: some View {
    Group {
      switch viewModel.state.api.fetchUser {
      case .loading where viewModel.state.user == nil:
        ProgressView()
      case let .error(message):
        ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
      default:
        if let user = viewModel.state.user {
          InfoSection(user: user)
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
  vm.state.user = .init(id: 1, name: "Alice Chen", email: "alice@example.com", company: "MVVMC Corp")
  return NavigationStack {
    UserDetailView(viewModel: vm)
  }
}
#endif
