//
//  InventoryListViewModel+APIs.swift
//  VM — endpoint 定義（選用檔）
//
//  註：「網路層怎麼發請求」明確不在 MVVMC 規範範圍（mvvmc-viewmodel〈明確不在規範範圍的事〉）。
//  這裡沿用 demo 的擺法（endpoint 放 +APIs.swift），只是其中一種做法。
//  端點是假的，僅示範 throw → handleAPIRequest 接住 → 包成 APIError 的流動。
//

import Foundation

enum InventoryListAPI {
    private static let baseURL = URL(string: "https://api.example.com/v1")!

    static func fetchItems(page: Int, pageSize: Int) async throws -> InventoryListViewModel.InventoryPageDTO {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("inventory/items"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(InventoryListViewModel.InventoryPageDTO.self, from: data)
    }

    static func fetchTotal() async throws -> InventoryListViewModel.InventoryTotalDTO {
        let url = baseURL.appendingPathComponent("inventory/total")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(InventoryListViewModel.InventoryTotalDTO.self, from: data)
    }
}
