import Foundation

@Observable
@MainActor
final class OrderDetailViewModel {
    enum Action: Sendable {
        case view(ViewAction)
        case apiRequest(APIRequest)
        case apiResponse(APIResponse)
    }

    var state: State = .init()

    @ObservationIgnored
    var onRoute: (@MainActor (Router) -> Void)?

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

extension OrderDetailViewModel {
    enum ViewAction: Sendable {
        case isFirstAppear
        case pullToRefresh
        case retryDidTap
        /// 即時狀態列出現在畫面上 → 啟動輪詢（迴圈本體在 VM，生命週期綁 View 的 `.task`）
        case liveStatusDidAppear
        case returnRequestButtonDidTap
        /// 子頁（退貨申請）回傳的結果。依 `mvvmc-viewmodel` 註解，子頁 callback 歸 ViewAction。
        case returnRequestDidSubmit(returnID: String)
    }

    private func handleViewAction(_ action: ViewAction) async {
        switch action {
        case .isFirstAppear:
            guard state.isFirstAppear else { return }
            state.isFirstAppear = false
            await doAction(.apiRequest(.fetchOrder))

        case .pullToRefresh, .retryDidTap:
            await doAction(.apiRequest(.fetchOrder))

        case .liveStatusDidAppear:
            await doAction(.apiRequest(.startLiveStatusPolling))

        case .returnRequestButtonDidTap:
            guard state.canRequestReturn else { return }
            onRoute?(.toReturnRequest(orderID: orderID))

        case let .returnRequestDidSubmit(returnID):
            state.latestReturnID = returnID
            // 樂觀更新：不等下一輪輪詢，立刻把狀態列改成「退貨處理中」
            //（`mvvmc-viewmodel`〈錯誤的流動〉明文允許 VM 自行構造 Domain Model 做樂觀更新）
            state.liveStatus = .init(stage: .returning, updatedAt: .now)
            // 再補一次即時查詢，讓伺服器真值儘快蓋上來
            await doAction(.apiRequest(.fetchLiveStatusOnce))
        }
    }
}

// MARK: - Router

extension OrderDetailViewModel {
    enum Router: Equatable, Sendable {
        /// 跨 feature 只傳 primitive（見 `mvvmc-structure`〈跨 feature 怎麼傳資料〉）
        case toReturnRequest(orderID: String)
    }
}

// MARK: - APIRequest

extension OrderDetailViewModel {
    enum APIRequest: Sendable {
        case fetchOrder
        /// 輪詢迴圈本體
        case startLiveStatusPolling
        /// 單次查詢（輪詢每一輪、以及樂觀更新後的補查都走這裡）
        case fetchLiveStatusOnce
    }

    private func handleAPIRequest(_ request: APIRequest) async {
        switch request {
        case .fetchOrder:
            state.api.fetchOrder = .loading
            let result = await OrderDetailAPI.fetchOrder(orderID: orderID)
            await doAction(.apiResponse(.fetchOrderDidFinish(result)))

        case .startLiveStatusPolling:
            // 刻意不加「是否已在輪詢」的旗標：`.task` 被取消／重建時，
            // 舊迴圈的收尾與新迴圈的啟動誰先跑到 MainActor 沒有保證，
            // 旗標一旦搶先被新迴圈讀到 true，輪詢會永久停擺（fail-closed）。
            // 取消的責任交給 `.task` 的結構化生命週期即可（見報告〈規範空白 #3〉）。
            var isFirstRound = true

            while !Task.isCancelled {
                // 只有首次寫 .loading，之後靜默更新——否則狀態列每 5 秒閃一次
                if isFirstRound {
                    state.api.fetchLiveStatus = .loading
                    isFirstRound = false
                }

                await doAction(.apiRequest(.fetchLiveStatusOnce))

                do {
                    try await Task.sleep(for: .seconds(5))
                }
                catch {
                    return // 被取消
                }
            }

        case .fetchLiveStatusOnce:
            let result = await OrderDetailAPI.fetchLiveStatus(orderID: orderID)
            await doAction(.apiResponse(.fetchLiveStatusDidFinish(result)))
        }
    }
}

// MARK: - APIResponse

extension OrderDetailViewModel {
    enum APIResponse: Sendable {
        case fetchOrderDidFinish(Result<OrderDetailDTO, APIError>)
        case fetchLiveStatusDidFinish(Result<OrderLiveStatusDTO, APIError>)
    }

    private func handleAPIResponse(_ response: APIResponse) async {
        switch response {
        case let .fetchOrderDidFinish(.success(dto)):
            guard let order = dto.toDomain() else {
                state.api.fetchOrder = .error("訂單資料格式有誤，請稍後再試")
                return
            }
            state.order = order
            state.api.fetchOrder = .success

        case let .fetchOrderDidFinish(.failure(.message(message))):
            // 失敗只寫狀態欄位，既有的 order 保留不清空
            state.api.fetchOrder = .error(message)

        case let .fetchLiveStatusDidFinish(.success(dto)):
            if let liveStatus = dto.toDomain() {
                state.liveStatus = liveStatus
            }
            state.api.fetchLiveStatus = .success

        case let .fetchLiveStatusDidFinish(.failure(.message(message))):
            state.api.fetchLiveStatus = .error(message)
        }
    }
}
