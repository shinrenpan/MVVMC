import SwiftUI

@MainActor
final class PostFilterHostController: UIHostingController<PostFilterView> {
  private let viewModel: PostFilterViewModel

  init(viewModel: PostFilterViewModel) {
    self.viewModel = viewModel
    super.init(rootView: PostFilterView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
