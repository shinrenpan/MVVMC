import SwiftUI

@MainActor
final class PostListHostController: UIHostingController<PostListView> {
  private let viewModel: PostListViewModel

  init(viewModel: PostListViewModel) {
    self.viewModel = viewModel
    super.init(rootView: PostListView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }
}

// MARK: - Router

private extension PostListHostController {
  func handleRouter(_ router: PostListViewModel.Router) {
    switch router {
    case let .toDetail(post):
      let vc = PostDetailHostController(post: post)
      navigationController?.pushViewController(vc, animated: true)
    }
  }
}
