//
//  InventoryAdjustHostController.swift
//  C — 本頁沒有自己的導航目的地，只負責承載 View（Template 1）
//

import UIKit
import SwiftUI

@MainActor
final class InventoryAdjustHostController: UIHostingController<InventoryAdjustView> {

    private let viewModel: InventoryAdjustViewModel

    /// 用「標準」形狀 init(viewModel:)：本頁要透過 onCallback 回傳結果，
    /// 父層必須先拿到 VM 實例才掛得上 callback，沒有別的辦法。
    init(viewModel: InventoryAdjustViewModel) {
        self.viewModel = viewModel
        super.init(rootView: InventoryAdjustView(viewModel: viewModel))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
