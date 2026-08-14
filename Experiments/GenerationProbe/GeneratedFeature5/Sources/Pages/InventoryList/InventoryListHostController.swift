//
//  InventoryListHostController.swift
//  C — 純 Router
//

import UIKit
import SwiftUI

@MainActor
final class InventoryListHostController: UIHostingController<InventoryListView> {

    private let viewModel: InventoryListViewModel

    init(viewModel: InventoryListViewModel) {
        self.viewModel = viewModel
        super.init(rootView: InventoryListView(viewModel: viewModel))
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

// MARK: - Router

private extension InventoryListHostController {
    func handleRouter(_ router: InventoryListViewModel.Router) {
        switch router {
        case let .toAdjust(item):
            // 這一頁需要接子頁的結果 → 用「標準」形狀：父層先建子 VM、掛好 onCallback，
            // 再 init(viewModel:)。跨 feature 邊界只傳 primitive，不傳 Item。
            let adjustViewModel = InventoryAdjustViewModel(
                itemID: item.id,
                itemName: item.name,
                currentQuantity: item.quantity
            )

            adjustViewModel.onCallback = { [weak self] callback in
                guard let self else { return }
                switch callback {
                case let .didAdjust(itemID, quantity):
                    AppRouter.shared.back(from: self)
                    await self.viewModel.doAction(.view(.didAdjustItem(id: itemID, quantity: quantity)))
                }
            }

            AppRouter.shared.to(
                InventoryAdjustHostController(viewModel: adjustViewModel),
                from: self
            )
        }
    }
}
