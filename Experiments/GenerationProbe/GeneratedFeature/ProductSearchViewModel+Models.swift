//
//  ProductSearchViewModel+Models.swift
//  M — State / Domain Models / DTOs
//

import Foundation

// MARK: - State

extension ProductSearchViewModel {
    struct State: Equatable, Sendable {
        var isFirstAppear: Bool = true
        var api: API = .init()

        /// 搜尋關鍵字。由 View 透過 `@Bindable` 直接雙向綁定（見 mvvmc-view §2 值同步用 Binding）
        var keyword: String = ""

        var categories: [Category] = []
        var selectedCategoryID: Category.ID? = nil
        var products: [Product] = []

        /// 關鍵字 + 分類的即時過濾結果。
        /// computed property 不參與 Equatable 合成 → 零成本，且不可能與來源不同步
        var filteredProducts: [Product] {
            products.filter { product in
                let matchesCategory = selectedCategoryID == nil || selectedCategoryID == product.categoryID
                let matchesKeyword = keyword.isEmpty
                    || product.name.localizedCaseInsensitiveContains(keyword)

                return matchesCategory && matchesKeyword
            }
        }
    }

    /// 請求狀態容器。兩支 API 各自追蹤，任一支失敗不影響另一支的顯示。
    /// APIStatus 為專案共用 enum（.prepare / .loading / .success / .error(String)）
    struct API: Equatable, Sendable {
        var fetchCategories: APIStatus = .prepare
        var fetchProducts: APIStatus = .prepare
    }
}

// MARK: - Domain Models

extension ProductSearchViewModel {
    struct Product: Identifiable, Equatable, Sendable {
        let id: String
        var name: String
        var price: Decimal
        var categoryID: String
        var stock: ProductStock
    }

    /// L2：只被 Product 使用 → 同一個 extension + Product 前綴。
    /// 純值 enum 已隱含 Equatable，只宣告 Sendable
    enum ProductStock: String, Sendable {
        case sufficient
        case low
        case outOfStock
    }

    struct Category: Identifiable, Equatable, Sendable {
        let id: String
        var name: String
    }
}

// MARK: - DTOs

// 註：此假想 API 以 snake_case 回傳，DTO 命名 1:1 對齊 response key，不加 CodingKeys。
// 清理（改 camelCase、取捨欄位）是 toDomain() 的責任。
extension ProductSearchViewModel {
    struct ProductDTO: Codable, Sendable {
        var product_id: String
        var product_name: String
        var price: Decimal
        var category_id: String
        var stock_status: String
        var updated_at: String

        func toDomain() -> Product? {
            guard !product_id.isEmpty else { return nil }

            return .init(
                id: product_id,
                name: product_name,
                price: price,
                categoryID: category_id,
                // 未知庫存值降級為 .outOfStock：寧可少賣，不要讓使用者下單到沒貨的商品。
                // 這是業務決定，不是通則
                stock: ProductStock(rawValue: stock_status) ?? .outOfStock
            )
        }
    }

    struct CategoryDTO: Codable, Sendable {
        var category_id: String
        var category_name: String
        var sort_order: Int

        func toDomain() -> Category? {
            guard !category_id.isEmpty else { return nil }

            return .init(id: category_id, name: category_name)
        }
    }
}
