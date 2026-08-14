//
//  ProductSearchViewModel+APIs.swift
//  VM — endpoint 定義（選用檔案）
//
//  註：MVVMC 對「網路層怎麼發請求」明確不表態（見 mvvmc-viewmodel〈明確不在規範範圍的事〉）。
//  這裡採 demo 的擺法：endpoint 集中在 +APIs.swift，回傳 DTO，不碰 state。
//

import Foundation

enum ProductSearchAPI {
    private static let baseURL = URL(string: "https://api.example.com/v1")!

    /// `@concurrent`：request + JSON decode 與 UI 無關，不佔用 MainActor
    /// （呼叫端 ViewModel 是 @MainActor，且專案開了 SWIFT_APPROACHABLE_CONCURRENCY，
    ///  不標的話這段會留在主 actor 上跑）
    @concurrent
    static func fetchCategories() async throws -> [ProductSearchViewModel.CategoryDTO] {
        try await get("/product-categories", as: [ProductSearchViewModel.CategoryDTO].self)
    }

    @concurrent
    static func fetchProducts() async throws -> [ProductSearchViewModel.ProductDTO] {
        try await get("/products", as: [ProductSearchViewModel.ProductDTO].self)
    }
}

private extension ProductSearchAPI {
    static func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let url = baseURL.appending(path: path)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.message("無法解析伺服器回應")
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw APIError.message("伺服器錯誤（\(http.statusCode)）")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
