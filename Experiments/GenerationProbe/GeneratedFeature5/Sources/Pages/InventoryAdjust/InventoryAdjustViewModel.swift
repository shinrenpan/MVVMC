//
//  InventoryAdjustViewModel.swift
//  VM
//

import Foundation

@Observable
@MainActor
final class InventoryAdjustViewModel {
    enum Action: Sendable {
        case view(ViewAction)
        case apiRequest(APIRequest)
        case apiResponse(APIResponse)
    }

    var state: State

    @ObservationIgnored
    var onCallback: (@MainActor (Callback) async -> Void)?

    /// 以 primitive 建構：父 feature 不需要（也不該）認識本 feature 的型別
    init(itemID: String, itemName: String, currentQuantity: Int) {
        self.state = .init(
            itemID: itemID,
            itemName: itemName,
            currentQuantity: currentQuantity
        )
    }

    func doAction(_ action: Action) async {
        switch action {
        case let .view(action): await handleViewAction(action)
        case let .apiRequest(request): await handleAPIRequest(request)
        case let .apiResponse(response): await handleAPIResponse(response)
        }
    }
}

// MARK: - ViewAction

extension InventoryAdjustViewModel {
    enum ViewAction: Sendable {
        case submitDidTap
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .submitDidTap:
            // 防重送的保證在這裡，不是靠 UI 把按鈕 disable。
            // UI 的 disabled 是版面，這條 guard 才是不變式。
            guard !state.isSubmitting else { return }
            guard state.isValid else { return }
            await doAction(.apiRequest(.submit))
        }
    }
}

// MARK: - Callback

extension InventoryAdjustViewModel {
    /// payload 一律 primitive：回程與去程一樣會跨出 feature 邊界，耦合是雙向的
    enum Callback: Equatable, Sendable {
        case didAdjust(itemID: String, quantity: Int)
    }
}

// MARK: - APIRequest

extension InventoryAdjustViewModel {
    enum APIRequest: Sendable {
        case submit
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .submit:
            guard let delta = state.quantityDelta, let reason = state.reason else { return }

            state.api.submit = .loading

            // request DTO 由 handleAPIRequest 從輸入緩衝組出來
            let body = AdjustRequestDTO(
                item_id: state.itemID,
                quantity_delta: delta,
                reason_code: reason.rawValue,
                note: state.note.isEmpty ? nil : state.note
            )

            do {
                let dto = try await InventoryAdjustAPI.submit(body)
                await doAction(.apiResponse(.submit(.success(dto))))
            } catch {
                await doAction(.apiResponse(.submit(.failure(.message(error.localizedDescription)))))
            }
        }
    }
}

// MARK: - APIResponse

extension InventoryAdjustViewModel {
    enum APIResponse: Sendable {
        case submit(Result<AdjustResultDTO, APIError>)
    }

    private func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case let .submit(.success(dto)):
            state.api.submit = .success
            // DTO 止步於此，只有 primitive 往父層走
            await onCallback?(.didAdjust(itemID: dto.item_id, quantity: dto.stock_quantity))

        case let .submit(.failure(.message(message))):
            // 只寫狀態欄位。quantityText / reason / note 一個都不清空。
            state.api.submit = .error(message)
        }
    }
}
