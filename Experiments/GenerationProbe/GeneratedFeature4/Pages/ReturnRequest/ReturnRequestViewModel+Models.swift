import Foundation

// MARK: - State

extension ReturnRequestViewModel {
    /// 三個步驟共用同一份「還沒送出的草稿」→ 依 `mvvmc-structure`〈多步驟流程（wizard）優先合成一個 feature〉，
    /// 做成單一 feature，用 `step` 驅動畫面切換。回上一步時內容還在，是「同一個 State 沒被丟掉」的自然結果。
    struct State: Equatable, Sendable {
        var isFirstAppear: Bool = true
        var api: API = .init()

        var step: Step = .selectItems

        /// 可退貨品項（步驟 1 的資料來源）
        var items: [ReturnableItem] = []

        // MARK: 使用者的輸入緩衝（尚未送出 → 屬 State，不是 Domain Model）

        var selectedItemIDs: Set<String> = []
        var reason: ReturnReason?
        var note: String = ""

        /// 取消確認對話框（`.alert` 由 V 層以 `@Bindable` 綁定，見 `mvvmc-view`〈Alert 與確認對話框〉）
        var isShowingCancelAlert: Bool = false

        // MARK: 推導值（computed property，不另存會不同步的 stored 欄位）

        var selectedItems: [ReturnableItem] {
            items.filter { selectedItemIDs.contains($0.id) }
        }

        /// 目前這一步能不能往下走
        var canProceed: Bool {
            switch step {
            case .selectItems: !selectedItemIDs.isEmpty
            case .reason: reason != nil
            case .confirm: !isSubmitting
            }
        }

        var canGoBack: Bool {
            step != .selectItems
        }

        var isSubmitting: Bool {
            api.submit == .loading
        }

        /// 已經填過東西 → 取消時要先跳確認
        var hasDraftInput: Bool {
            !selectedItemIDs.isEmpty || reason != nil || !note.isEmpty
        }

        var refundAmount: Double {
            selectedItems.reduce(0) { $0 + $1.subtotal }
        }
    }

    /// 純 UI 狀態：步驟切換不經 AppRouter，只是同一頁的 state 轉移
    enum Step: Int, Sendable, CaseIterable {
        case selectItems
        case reason
        case confirm
    }

    struct API: Equatable, Sendable {
        var fetchItems: APIStatus = .prepare
        var submit: APIStatus = .prepare
    }
}

// MARK: - Domain Models

extension ReturnRequestViewModel {
    struct ReturnableItem: Identifiable, Equatable, Sendable {
        let id: String
        var productName: String
        var quantity: Int
        var unitPrice: Double

        var subtotal: Double { unitPrice * Double(quantity) }
    }
}

extension ReturnRequestViewModel {
    /// 退貨原因類別。只帶業務語意，顯示文案是 V 層的事（見 `mvvmc-view`〈Display Helper〉）。
    /// 純值 enum 已隱含 Equatable。
    enum ReturnReason: String, Sendable, CaseIterable, Identifiable {
        case damaged
        case wrongItem
        case notAsDescribed
        case missingParts
        case changedMind

        var id: String { rawValue }
    }
}

// MARK: - DTOs

extension ReturnRequestViewModel {
    struct ReturnableItemDTO: Codable, Sendable {
        var item_id: String
        var product_name: String
        var quantity: Int
        var unit_price: Double
        var returnable: Bool

        func toDomain() -> ReturnableItem? {
            guard !item_id.isEmpty, returnable else { return nil }

            return .init(
                id: item_id,
                productName: product_name,
                quantity: quantity,
                unitPrice: unit_price
            )
        }
    }

    /// 送出用的 request DTO：由 `handleAPIRequest` 從輸入緩衝組出來。
    /// 刻意不在 State 上寫 `toDTO()`——那會讓輸入緩衝反過來知道 API 合約。
    struct ReturnRequestBodyDTO: Codable, Sendable {
        var order_id: String
        var item_ids: [String]
        var reason_code: String
        var note: String?
    }

    struct ReturnReceiptDTO: Codable, Sendable {
        var return_id: String
        var accepted_at: String
    }
}
