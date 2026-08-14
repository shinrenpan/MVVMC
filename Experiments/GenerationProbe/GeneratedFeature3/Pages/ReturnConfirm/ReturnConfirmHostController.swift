//
//  ReturnConfirmHostController.swift
//  MVVMC
//

import SwiftUI
import UIKit

@MainActor
final class ReturnConfirmHostController: UIHostingController<ReturnConfirmView> {

  private let viewModel: ReturnConfirmViewModel

  init(viewModel: ReturnConfirmViewModel) {
    self.viewModel = viewModel
    super.init(rootView: ReturnConfirmView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // 這是流程最後一頁：沒有 onRoute，所有出口都走 onCallback 交給上一頁處理
}
