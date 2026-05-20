import SwiftUI

@MainActor
final class PostDetailHostController: UIHostingController<PostDetailView> {
  private let viewModel: PostDetailViewModel

  init(id: Int, title: String, body: String) {
    let post = PostDetailViewModel.Post(id: id, title: title, body: body)
    self.viewModel = PostDetailViewModel(post: post)
    super.init(rootView: PostDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
