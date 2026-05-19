import SwiftUI

struct PostDetailView: View {
  let viewModel: PostDetailViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(viewModel.state.post.title)
          .font(.title2)
          .fontWeight(.bold)

        Divider()

        Text(viewModel.state.post.body)
          .font(.body)
          .foregroundStyle(.secondary)
          .lineSpacing(4)
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle("Post \(viewModel.state.post.id)")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#if DEBUG
#Preview {
  NavigationStack {
    PostDetailView(viewModel: PostDetailViewModel(post: .mock))
  }
}
#endif
