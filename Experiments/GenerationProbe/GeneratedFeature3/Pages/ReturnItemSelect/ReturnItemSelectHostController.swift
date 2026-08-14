//
//  ReturnItemSelectHostController.swift
//  MVVMC
//

import SwiftUI
import UIKit

@MainActor
final class ReturnItemSelectHostController: UIHostingController<ReturnItemSelectView> {

  private let viewModel: ReturnItemSelectViewModel

  init(viewModel: ReturnItemSelectViewModel) {
    self.viewModel = viewModel
    super.init(rootView: ReturnItemSelectView(viewModel: viewModel))
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

private extension ReturnItemSelectHostController {
  func handleRouter(_ router: ReturnItemSelectViewModel.Router) {
    switch router {
    case let .toReason(orderID, itemIDs, reasonCode, note):
      // 需要同時滿足兩件事：跨 feature 只傳 primitive + 事前設定 onCallback，
      // 所以 VM 必須在父層組裝（C 層內部建 VM 的變體無法設 callback）
      let stepVM = ReturnReasonViewModel(
        orderID: orderID,
        itemIDs: itemIDs,
        reasonCode: reasonCode,
        note: note
      )
      stepVM.onCallback = { [weak self] callback in
        guard let self else { return }
        switch callback {
        case let .didGoBack(reasonCode, note):
          // 只有「回上一步」由本層負責 pop——它退的正好是我的下一頁
          AppRouter.shared.back(from: self)
          await self.viewModel.doAction(.view(.childDidGoBack(reasonCode: reasonCode, note: note)))

        case .didCancel:
          // 不 pop：終點是訂單詳情頁，由它一次退到位，否則會看到多段動畫
          await self.viewModel.doAction(.view(.childDidCancel))

        case let .didSubmit(returnID):
          await self.viewModel.doAction(.view(.childDidSubmit(returnID: returnID)))
        }
      }
      AppRouter.shared.to(ReturnReasonHostController(viewModel: stepVM), from: self)
    }
  }
}
