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
        List(viewModel.state.posts) { post in
          PostRow(post: post) {
            Task { await viewModel.doAction(.view(.postDidTap(post))) }
          } onUserTap: {
            Task { await viewModel.doAction(.view(.userDidTap(post.userId))) }
          }
        }
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
}

// MARK: - Subviews

private extension PostListView {
  struct PostRow: View {
    let post: PostListViewModel.Post
    let onTap: @MainActor () -> Void
    let onUserTap: @MainActor () -> Void

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
        .onTapGesture { onTap() }

        Button("User \(post.userId)") {
          onUserTap()
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
