import SwiftUI
import UIKit

@MainActor
final class OrderListHostController: UIHostingController<OrderListView> {
  let viewModel = OrderListViewModel()

  init() {
    super.init(rootView: OrderListView())
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()

    viewModel.presentingController = self

    viewModel.onRoute = { router in
      switch router {
      case let .toDetail(order):
        let detail = OrderDetailHostController(orderId: order.id)
        self.navigationController?.pushViewController(detail, animated: true)
      }
    }

    Task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    viewModel.onRoute = nil
  }
}
