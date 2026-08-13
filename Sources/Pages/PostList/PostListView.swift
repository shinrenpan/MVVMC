import SwiftUI

struct PostListView: View {
  let viewModel: PostListViewModel

  var body: some View {
    Group {
      switch viewModel.state.api.fetchPosts {
      case .loading where viewModel.state.posts.isEmpty:
        ProgressView()
      case let .error(message):
        ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
      default:
        ListSection(posts: viewModel.state.posts, send: handleListAction)
      }
    }
    .navigationTitle(viewModel.state.filterUserId.map { "User \($0)'s Posts" } ?? "Posts")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Profile") {
          Task { await viewModel.doAction(.view(.toProfile)) }
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Filter") {
          Task { await viewModel.doAction(.view(.showFilter)) }
        }
      }
    }
    .task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }

  // handler 與 body 同層，標 @MainActor 以匹配 send 的型別
  @MainActor private func handleListAction(_ action: ListSection.Action) {
    switch action {
    case let .postDidTap(post):
      Task { await viewModel.doAction(.view(.postDidTap(post))) }
    case let .userDidTap(userId):
      Task { await viewModel.doAction(.view(.userDidTap(userId))) }
    }
  }
}

// MARK: - Subviews

private extension PostListView {
  // L2：佈局層。職責是 List + ForEach 的組合，並把 L3 的「這一列發生了什麼」
  // 映射成帶業務語意的 Action（Mapping，而非純 Forwarding）
  struct ListSection: View {
    enum Action: Sendable {
      case postDidTap(PostListViewModel.Post)
      case userDidTap(Int)
    }

    let posts: [PostListViewModel.Post]
    let send: @MainActor (Action) -> Void

    var body: some View {
      List(posts) { post in
        ListRow(post: post) { action in
          switch action {
          case .rowDidTap:
            send(.postDidTap(post))
          case .userButtonDidTap:
            send(.userDidTap(post.userId))
          }
        }
      }
    }
  }

  // L3：零件層。Action 從自身視角描述事件（「這一列被點了」），
  // 不預設上層要拿它做什麼（不叫 postDidTap）
  struct ListRow: View {
    enum Action: Sendable {
      case rowDidTap
      case userButtonDidTap
    }

    let post: PostListViewModel.Post
    let send: @MainActor (Action) -> Void

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        VStack(alignment: .leading, spacing: 4) {
          Text(post.title)
            .font(.headline)
            .foregroundStyle(.primary)
          Text(post.body)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { send(.rowDidTap) }

        Button("User \(post.userId)") {
          send(.userButtonDidTap)
        }
        .font(.caption)
        .foregroundStyle(Color.accentColor)
        .buttonStyle(.plain)
      }
      .padding(.vertical, 4)
    }
  }
}

#if DEBUG
#Preview {
  let vm = PostListViewModel()
  vm.state.posts = PostListViewModel.Post.mocks
  return NavigationStack {
    PostListView(viewModel: vm)
  }
}
#endif
