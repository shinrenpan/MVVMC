//
//  OrderDetailHostController.swift
//  MVVMC
//

import SwiftUI
import UIKit

@MainActor
final class OrderDetailHostController: UIHostingController<OrderDetailView> {

  private let viewModel: OrderDetailViewModel

  /// 跨 feature 邊界只收 primitive，ViewModel 在 C 層組裝
  init(orderID: String) {
    self.viewModel = OrderDetailViewModel(orderID: orderID)
    super.init(rootView: OrderDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }
}

private extension OrderDetailHostController {
  func handleRouter(_ router: OrderDetailViewModel.Router) {
    switch router {
    case let .toReturnItemSelect(orderID):
      let stepVM = ReturnItemSelectViewModel(orderID: orderID)
      stepVM.onCallback = { [weak self] callback in
        guard let self else { return }
        switch callback {
        case .didCancel:
          // 用 backTo 而非 back：這個 callback 可能是從第 2、3 步一路中繼上來的，
          // 只有「退到我自己」這個描述在任何深度都成立
          AppRouter.shared.backTo(self, from: self)

        case let .didSubmit(returnID):
          AppRouter.shared.backTo(self, from: self)
          await self.viewModel.doAction(.view(.returnFlowDidSubmit(returnID: returnID)))
        }
      }
      AppRouter.shared.to(ReturnItemSelectHostController(viewModel: stepVM), from: self)
    }
  }
}
