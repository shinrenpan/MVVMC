//
//  OrderListHostController.swift
//  C
//

import SwiftUI
import UIKit

@MainActor
final class OrderListHostController: UIHostingController<OrderListView> {

    private let viewModel: OrderListViewModel

    init(viewModel: OrderListViewModel) {
        self.viewModel = viewModel
        super.init(rootView: OrderListView(viewModel: viewModel))
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

private extension OrderListHostController {
    func handleRouter(_ router: OrderListViewModel.Router) {
        switch router {
        case .toCreateOrder:
            let createViewModel = OrderCreateViewModel()

            // 導航前先接上 callback：子頁送出成功後由這裡負責關閉 + 通知列表
            createViewModel.onCallback = { [weak self] callback in
                guard let self else { return }
                switch callback {
                case .didCreateOrder:
                    AppRouter.shared.back(from: self)
                    await self.viewModel.doAction(.view(.orderDidCreate))
                }
            }

            AppRouter.shared.to(OrderCreateHostController(viewModel: createViewModel), from: self)
        }
    }
}
