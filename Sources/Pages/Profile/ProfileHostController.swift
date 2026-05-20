import SwiftUI

@MainActor
final class ProfileHostController: UIHostingController<ProfileView> {
  private let viewModel: ProfileViewModel

  init() {
    let viewModel = ProfileViewModel()
    self.viewModel = viewModel
    super.init(rootView: ProfileView(viewModel: viewModel))
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

private extension ProfileHostController {
  func handleRouter(_ router: ProfileViewModel.Router) {
    switch router {
    case .toPosts:
      AppRouter.shared.tab(0, from: self)
    case .toSettings:
      AppRouter.shared.sheet(SettingsHostController(viewModel: .init()), from: self)
    }
  }
}
