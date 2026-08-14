import Foundation

@Observable
@MainActor
final class ReturnRequestViewModel {
    enum Action: Sendable {
        case view(ViewAction)
        case apiRequest(APIRequest)
        case apiResponse(APIResponse)
    }

    var state: State = .init()

    /// 只有跨 VC 回傳的需求，沒有導航需求（三個 step 都在同一頁）→ 只宣告 `onCallback`
    @ObservationIgnored
    var onCallback: (@MainActor (Callback) async -> Void)?

    @ObservationIgnored
    private let orderID: String

    init(orderID: String) {
        self.orderID = orderID
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

extension ReturnRequestViewModel {
    enum ViewAction: Sendable {
        case isFirstAppear
        case retryDidTap
        case itemDidTap(id: String)
        case reasonDidTap(ReturnReason)
        /// 底部主要按鈕（步驟 1、2 是「下一步」，步驟 3 是「送出」）——
        /// 由 VM 依 `state.step` 決定意義，View 不讀 state 做流程決策
        case primaryButtonDidTap
        case backButtonDidTap
        case cancelButtonDidTap
        /// 取消確認對話框按下「放棄申請」
        case discardDidConfirm
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .isFirstAppear:
            guard state.isFirstAppear else { return }
            state.isFirstAppear = false
            await doAction(.apiRequest(.fetchItems))

        case .retryDidTap:
            await doAction(.apiRequest(.fetchItems))

        case let .itemDidTap(id):
            guard !state.isSubmitting else { return }

            if state.selectedItemIDs.contains(id) {
                state.selectedItemIDs.remove(id)
            }
            else {
                state.selectedItemIDs.insert(id)
            }

        case let .reasonDidTap(reason):
            guard !state.isSubmitting else { return }
            state.reason = reason

        case .primaryButtonDidTap:
            guard state.canProceed else { return }

            switch state.step {
            case .selectItems: state.step = .reason
            case .reason: state.step = .confirm
            case .confirm: await doAction(.apiRequest(.submit))
            }

        case .backButtonDidTap:
            guard !state.isSubmitting else { return }

            switch state.step {
            case .selectItems: break
            case .reason: state.step = .selectItems
            case .confirm: state.step = .reason
            }

        case .cancelButtonDidTap:
            guard !state.isSubmitting else { return }

            // 已經填了東西才需要確認；空白表單直接走人
            if state.hasDraftInput {
                state.isShowingCancelAlert = true
            }
            else {
                await onCallback?(.didCancel)
            }

        case .discardDidConfirm:
            state.isShowingCancelAlert = false
            await onCallback?(.didCancel)
        }
    }
}

// MARK: - Callback

extension ReturnRequestViewModel {
    /// payload 傳 primitive：父層不需要認識本 feature 的任何 Domain Model
    enum Callback: Equatable, Sendable {
        case didSubmit(returnID: String)
        case didCancel
    }
}

// MARK: - APIRequest

extension ReturnRequestViewModel {
    enum APIRequest: Sendable {
        case fetchItems
        case submit
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .fetchItems:
            state.api.fetchItems = .loading
            let result = await ReturnRequestAPI.fetchReturnableItems(orderID: orderID)
            await doAction(.apiResponse(.fetchItemsDidFinish(result)))

        case .submit:
            // 防重複送出：閘門在 VM，不靠 UI 禁用來保證
            guard !state.isSubmitting else { return }
            guard let reason = state.reason, !state.selectedItemIDs.isEmpty else { return }

            state.api.submit = .loading

            let body = ReturnRequestBodyDTO(
                order_id: orderID,
                item_ids: state.selectedItems.map(\.id),
                reason_code: reason.rawValue,
                note: state.note.isEmpty ? nil : state.note
            )

            let result = await ReturnRequestAPI.submit(body: body)
            await doAction(.apiResponse(.submitDidFinish(result)))
        }
    }
}

// MARK: - APIResponse

extension ReturnRequestViewModel {
    enum APIResponse: Sendable {
        case fetchItemsDidFinish(Result<[ReturnableItemDTO], APIError>)
        case submitDidFinish(Result<ReturnReceiptDTO, APIError>)
    }

    private func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case let .fetchItemsDidFinish(.success(dtos)):
            state.items = dtos.compactMap { $0.toDomain() }
            // 伺服器可能回收了某些品項的退貨資格 → 清掉已不存在的選取
            let validIDs = Set(state.items.map(\.id))
            state.selectedItemIDs.formIntersection(validIDs)
            state.api.fetchItems = .success

        case let .fetchItemsDidFinish(.failure(.message(message))):
            state.api.fetchItems = .error(message)

        case let .submitDidFinish(.success(dto)):
            state.api.submit = .success
            await onCallback?(.didSubmit(returnID: dto.return_id))

        case let .submitDidFinish(.failure(.message(message))):
            // 失敗只寫狀態欄位，使用者填的東西一律保留
            state.api.submit = .error(message)
        }
    }
}
