import SwiftUI

@MainActor
final class UserDetailHostController: UIHostingController<UserDetailView> {
  private let viewModel: UserDetailViewModel

  init(userId: Int) {
    let viewModel = UserDetailViewModel(userId: userId)
    self.viewModel = viewModel
    super.init(rootView: UserDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
