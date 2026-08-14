import Foundation

enum ReturnRequestAPI {
    /// GET /v1/orders/{orderID}/returnable-items
    ///
    /// 刻意由本 feature 自己取資料，而不是從訂單詳情把品項傳進來：
    /// 跨 feature 只傳 primitive，而「一組品項」不是 primitive（見報告的〈規範空白 #1〉）。
    static func fetchReturnableItems(orderID: String) async -> Result<[ReturnRequestViewModel.ReturnableItemDTO], APIError> {
        await get(path: "orders/\(orderID)/returnable-items")
    }

    /// POST /v1/returns
    static func submit(body: ReturnRequestViewModel.ReturnRequestBodyDTO) async -> Result<ReturnRequestViewModel.ReturnReceiptDTO, APIError> {
        await post(path: "returns", body: body)
    }
}

private extension ReturnRequestAPI {
    static var baseURL: URL { URL(string: "https://api.example.com/v1")! }

    static func get<T: Decodable & Sendable>(path: String) async -> Result<T, APIError> {
        do {
            var request = URLRequest(url: baseURL.appending(path: path))
            request.httpMethod = "GET"

            let (data, _) = try await URLSession.shared.data(for: request)

            return .success(try JSONDecoder().decode(T.self, from: data))
        }
        catch {
            return .failure(.message(error.localizedDescription))
        }
    }

    static func post<T: Decodable & Sendable, Body: Encodable & Sendable>(
        path: String,
        body: Body
    ) async -> Result<T, APIError> {
        do {
            var request = URLRequest(url: baseURL.appending(path: path))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, _) = try await URLSession.shared.data(for: request)

            return .success(try JSONDecoder().decode(T.self, from: data))
        }
        catch {
            return .failure(.message(error.localizedDescription))
        }
    }
}
