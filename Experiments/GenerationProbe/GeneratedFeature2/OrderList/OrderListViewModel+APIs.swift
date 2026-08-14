//
//  OrderListViewModel+APIs.swift
//  VM — endpoint 定義（擺法不在 MVVMC 規範範圍，這裡沿用 demo 的做法）
//

import Foundation

enum OrderListAPI {
    /// 每頁筆數。屬 API 合約，不放進 State。
    static let pageSize = 20

    static func fetchOrders(page: Int) async throws -> OrderListViewModel.OrderPageDTO {
        var components = URLComponents(string: "https://api.example.com/v1/orders")
        components?.queryItems = [
            .init(name: "page", value: "\(page)"),
            .init(name: "per_page", value: "\(pageSize)"),
        ]

        guard let url = components?.url else {
            throw APIError.message("Invalid orders URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.message("Server error")
        }

        return try JSONDecoder().decode(OrderListViewModel.OrderPageDTO.self, from: data)
    }
}
