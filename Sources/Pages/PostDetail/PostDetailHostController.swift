import SwiftUI

@MainActor
final class PostDetailHostController: UIHostingController<PostDetailView> {
  private let viewModel: PostDetailViewModel

  init(post: PostListViewModel.Post) {
    self.viewModel = PostDetailViewModel(post: post)
    super.init(rootView: PostDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    viewModel.onAction = nil
  }
}
