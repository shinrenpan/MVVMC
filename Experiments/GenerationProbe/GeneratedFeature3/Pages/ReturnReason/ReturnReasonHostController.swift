//
//  ReturnReasonHostController.swift
//  MVVMC
//

import SwiftUI
import UIKit

@MainActor
final class ReturnReasonHostController: UIHostingController<ReturnReasonView> {

  private let viewModel: ReturnReasonViewModel

  init(viewModel: ReturnReasonViewModel) {
    self.viewModel = viewModel
    super.init(rootView: ReturnReasonView(viewModel: viewModel))
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

private extension ReturnReasonHostController {
  func handleRouter(_ router: ReturnReasonViewModel.Router) {
    switch router {
    case let .toConfirm(orderID, itemIDs, reasonCode, note):
      let stepVM = ReturnConfirmViewModel(
        orderID: orderID,
        itemIDs: itemIDs,
        reasonCode: reasonCode,
        note: note
      )
      stepVM.onCallback = { [weak self] callback in
        guard let self else { return }
        switch callback {
        case .didGoBack:
          // 第 3 步沒有輸入緩衝要交還，pop 完就結束，不需要驚動 ViewModel
          AppRouter.shared.back(from: self)

        case .didCancel:
          await self.viewModel.doAction(.view(.childDidCancel))

        case let .didSubmit(returnID):
          await self.viewModel.doAction(.view(.childDidSubmit(returnID: returnID)))
        }
      }
      AppRouter.shared.to(ReturnConfirmHostController(viewModel: stepVM), from: self)
    }
  }
}
