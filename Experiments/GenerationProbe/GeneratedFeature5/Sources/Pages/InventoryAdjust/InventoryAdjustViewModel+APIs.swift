//
//  InventoryAdjustViewModel+APIs.swift
//  VM — endpoint 定義（選用檔，假端點）
//

import Foundation

enum InventoryAdjustAPI {
    private static let baseURL = URL(string: "https://api.example.com/v1")!

    static func submit(
        _ body: InventoryAdjustViewModel.AdjustRequestDTO
    ) async throws -> InventoryAdjustViewModel.AdjustResultDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent("inventory/adjustments"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(InventoryAdjustViewModel.AdjustResultDTO.self, from: data)
    }
}
