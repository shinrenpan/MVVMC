//
//  ProductSearchMocks.swift
//  M — Mock（整檔 #if DEBUG，供 Preview 與測試使用）
//

#if DEBUG
import Foundation

extension ProductSearchViewModel.Product {
    static let mock: Self = .init(
        id: "p1",
        name: "無線降噪耳機",
        price: 5990,
        categoryID: "c1",
        stock: .sufficient
    )

    static let mocks: [Self] = [
        .init(id: "p1", name: "無線降噪耳機", price: 5990, categoryID: "c1", stock: .sufficient),
        .init(id: "p2", name: "機械式鍵盤", price: 3280, categoryID: "c1", stock: .low),
        .init(id: "p3", name: "人體工學椅", price: 12800, categoryID: "c2", stock: .outOfStock),
        .init(id: "p4", name: "升降桌", price: 15900, categoryID: "c2", stock: .sufficient),
        .init(id: "p5", name: "手沖咖啡壺", price: 1480, categoryID: "c3", stock: .low),
    ]
}

extension ProductSearchViewModel.Category {
    static let mock: Self = .init(id: "c1", name: "3C")

    static let mocks: [Self] = [
        .init(id: "c1", name: "3C"),
        .init(id: "c2", name: "家具"),
        .init(id: "c3", name: "廚房"),
        .init(id: "c4", name: "運動"),
    ]
}
#endif
