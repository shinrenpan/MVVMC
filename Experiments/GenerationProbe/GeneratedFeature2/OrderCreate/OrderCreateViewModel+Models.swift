//
//  OrderCreateViewModel+Models.swift
//  M — State / DTOs（本 feature 沒有 Domain Models 區塊，理由見檔尾註解）
//

import Foundation

// MARK: - State

extension OrderCreateViewModel {
    struct State: Equatable, Sendable {
        var api: API = .init()
        var draft: Draft = .init()

        var isSubmitting: Bool { api.createOrder == .loading }

        /// 送出按鈕的啟用條件：欄位齊全 + 沒有正在送出
        var canSubmit: Bool { draft.isValid && !isSubmitting }

        /// 已翻譯好的錯誤訊息，View 直接顯示、不做任何判讀
        var errorMessage: String? {
            guard case let .error(message) = api.createOrder else { return nil }
            return message
        }
    }

    struct API: Equatable, Sendable {
        var createOrder: APIStatus = .prepare
    }

    /// 編輯中的表單草稿——是使用者的輸入緩衝（含尚未通過驗證的字串），不是業務模型，
    /// 所以放在 State 區塊而不是 Domain Models。
    struct Draft: Equatable, Sendable {
        var customerName: String = ""
        var productName: String = ""
        /// TextField 綁的是字串：必須能表達「還沒填」與「填了 0」的差別
        var quantityText: String = ""
        var note: String = ""

        /// nil 代表未填或不合法（非數字 / <= 0）
        var quantity: Int? {
            guard let value = Int(quantityText.trimmingCharacters(in: .whitespaces)), value > 0 else {
                return nil
            }
            return value
        }

        var isValid: Bool {
            !customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && quantity != nil
        }
    }
}

// MARK: - DTOs

extension OrderCreateViewModel {
    /// POST /v1/orders 的 request body。
    /// 規範只描述「回應方向」的 DTO，這裡沿用同一個區塊放送出方向的 payload——
    /// 它同樣是與 API 合約 1:1 對齊、不進 State 的拋棄式資料。
    struct CreateOrderRequestDTO: Codable, Sendable {
        var customer_name: String
        var product_name: String
        var quantity: Int
        var note: String?
    }

    /// POST /v1/orders 的回應。
    struct CreatedOrderDTO: Codable, Sendable {
        var order_id: String
        var order_status: String
    }
}

// 沒有 Domain Models 區塊：這一頁不顯示任何來自伺服器的業務資料，
// 建立成功後只把「成功了」這件事透過 onCallback 往上拋，列表自行重新載入。
// 硬造一個沒有消費者的 Order Domain Model 只會是死碼。
