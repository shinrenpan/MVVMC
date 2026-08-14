//
//  OrderCreateHostController.swift
//  C
//

import SwiftUI
import UIKit

/// 這一頁不發起任何導航（送出成功後的關閉由父 HostController 在 onCallback 內執行），
/// 所以沒有 Router、也不需要 viewDidLoad。
@MainActor
final class OrderCreateHostController: UIHostingController<OrderCreateView> {

    private let viewModel: OrderCreateViewModel

    init(viewModel: OrderCreateViewModel) {
        self.viewModel = viewModel
        super.init(rootView: OrderCreateView(viewModel: viewModel))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
