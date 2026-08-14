//
//  OrderCreateViewModel.swift
//  VM
//

import Foundation

@Observable
@MainActor
final class OrderCreateViewModel {
    enum Action: Sendable {
        case view(ViewAction)
        case apiRequest(APIRequest)
        case apiResponse(APIResponse)
    }

    var state: State = .init()

    @ObservationIgnored
    var onCallback: (@MainActor (Callback) async -> Void)?

    func doAction(_ action: Action) async {
        switch action {
        case let .view(action): await handleViewAction(action)
        case let .apiRequest(request): await handleAPIRequest(request)
        case let .apiResponse(response): await handleAPIResponse(response)
        }
    }
}

// MARK: - ViewAction

extension OrderCreateViewModel {
    enum ViewAction: Sendable {
        case submitDidTap
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .submitDidTap:
            // 防重入 + 防未填完就送出。按鈕雖然已 disabled，流程判斷仍留在 VM
            guard state.canSubmit else { return }
            await doAction(.apiRequest(.createOrder))
        }
    }
}

// MARK: - Callback

extension OrderCreateViewModel {
    enum Callback: Sendable {
        case didCreateOrder
    }
}

// MARK: - APIRequest

extension OrderCreateViewModel {
    enum APIRequest: Sendable {
        case createOrder
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .createOrder:
            guard let quantity = state.draft.quantity else { return }

            let payload = CreateOrderRequestDTO(
                customer_name: state.draft.customerName.trimmingCharacters(in: .whitespacesAndNewlines),
                product_name: state.draft.productName.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                note: state.draft.note.isEmpty ? nil : state.draft.note
            )

            state.api.createOrder = .loading

            do {
                let dto = try await OrderCreateAPI.createOrder(payload)
                await doAction(.apiResponse(.createOrder(.success(dto))))
            } catch {
                await doAction(.apiResponse(.createOrder(.failure(.message(error.localizedDescription)))))
            }
        }
    }
}

// MARK: - APIResponse

extension OrderCreateViewModel {
    enum APIResponse: Sendable {
        case createOrder(Result<CreatedOrderDTO, APIError>)
    }

    private func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case .createOrder(.success):
            state.api.createOrder = .success
            // 關閉這一頁是 C 層的事：VM 只回報「建立完成」
            await onCallback?(.didCreateOrder)

        case let .createOrder(.failure(.message(message))):
            // draft 原封不動 → 使用者已填的內容保留
            state.api.createOrder = .error(message)
        }
    }
}
