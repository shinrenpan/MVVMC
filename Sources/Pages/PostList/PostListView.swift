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
          }
        }
      }
    }
    .navigationTitle("Posts")
  }
}

// MARK: - Subviews

private extension PostListView {
  struct PostRow: View {
    let post: PostListViewModel.Post
    let onTap: @MainActor () -> Void

    var body: some View {
      Button(action: onTap) {
        VStack(alignment: .leading, spacing: 4) {
          Text(post.title)
            .font(.headline)
            .foregroundStyle(.primary)
          Text(post.body)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
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
