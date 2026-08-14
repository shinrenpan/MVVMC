#if DEBUG
import Foundation

extension ReturnRequestViewModel.ReturnableItem {
    static let mock: Self = .init(id: "ITEM-1", productName: "無線耳機", quantity: 1, unitPrice: 2980)

    static let mocks: [Self] = [
        .init(id: "ITEM-1", productName: "無線耳機", quantity: 1, unitPrice: 2980),
        .init(id: "ITEM-2", productName: "充電線 1M", quantity: 2, unitPrice: 350),
        .init(id: "ITEM-3", productName: "收納袋", quantity: 1, unitPrice: 500),
    ]
}
#endif
