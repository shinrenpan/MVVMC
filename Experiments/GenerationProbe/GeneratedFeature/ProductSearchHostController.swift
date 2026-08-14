//
//  ProductSearchHostController.swift
//  C — 純 Router，所有導航經 AppRouter.shared
//

import SwiftUI
import UIKit

@MainActor
final class ProductSearchHostController: UIHostingController<ProductSearchView> {

    private let viewModel: ProductSearchViewModel

    init(viewModel: ProductSearchViewModel) {
        self.viewModel = viewModel
        super.init(rootView: ProductSearchView(viewModel: viewModel))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "商品搜尋"

        viewModel.onRoute = { [weak self] router in
            self?.handleRouter(router)
        }
    }
}

private extension ProductSearchHostController {
    func handleRouter(_ router: ProductSearchViewModel.Router) {
        switch router {
        case let .toDetail(product):
            // 跨 feature 只傳 primitive，不傳 Domain Model（見 mvvmc-structure）
            AppRouter.shared.to(
                ProductDetailHostController(
                    id: product.id,
                    name: product.name,
                    price: product.price
                ),
                from: self
            )
        }
    }
}
