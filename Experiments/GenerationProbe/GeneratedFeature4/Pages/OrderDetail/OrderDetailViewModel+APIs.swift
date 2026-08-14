import Foundation

/// Endpoint 定義。
/// 網路層怎麼發請求**不在 MVVMC 規範範圍**（見 `mvvmc-viewmodel`〈明確不在規範範圍的事〉），
/// 這裡採 demo 的擺法：一個 feature 一個 `+APIs.swift`。
enum OrderDetailAPI {
    /// GET /v1/orders/{orderID}
    static func fetchOrder(orderID: String) async -> Result<OrderDetailViewModel.OrderDetailDTO, APIError> {
        await get(path: "orders/\(orderID)")
    }

    /// GET /v1/orders/{orderID}/live-status
    static func fetchLiveStatus(orderID: String) async -> Result<OrderDetailViewModel.OrderLiveStatusDTO, APIError> {
        await get(path: "orders/\(orderID)/live-status")
    }
}

private extension OrderDetailAPI {
    static var baseURL: URL { URL(string: "https://api.example.com/v1")! }

    static func get<T: Decodable & Sendable>(path: String) async -> Result<T, APIError> {
        do {
            var request = URLRequest(url: baseURL.appending(path: path))
            request.httpMethod = "GET"

            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(T.self, from: data)

            return .success(decoded)
        }
        catch {
            // Error 止步於此，往上只傳「已翻譯」的訊息
            return .failure(.message(error.localizedDescription))
        }
    }
}
