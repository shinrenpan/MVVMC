//
//  OrderCreateViewModel+APIs.swift
//  VM — endpoint 定義
//

import Foundation

enum OrderCreateAPI {
    static func createOrder(
        _ payload: OrderCreateViewModel.CreateOrderRequestDTO
    ) async throws -> OrderCreateViewModel.CreatedOrderDTO {
        guard let url = URL(string: "https://api.example.com/v1/orders") else {
            throw APIError.message("Invalid orders URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.message("Server error")
        }

        return try JSONDecoder().decode(OrderCreateViewModel.CreatedOrderDTO.self, from: data)
    }
}
