import SwiftUI

@MainActor
final class PostListHostController: UIHostingController<PostListView> {
  private let viewModel: PostListViewModel
  private var tasks: [String: Task<Void, Never>] = [:]

  init(viewModel: PostListViewModel) {
    self.viewModel = viewModel
    super.init(rootView: PostListView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onAction = { [weak self] action in
      guard case let .route(router) = action else { return }
      self?.handleRouter(router)
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    tasks["onAppear"]?.cancel()
    tasks["onAppear"] = Task { await viewModel.doAction(.view(.onAppear)) }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    tasks.values.forEach { $0.cancel() }
    tasks.removeAll()
    viewModel.onAction = nil
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
