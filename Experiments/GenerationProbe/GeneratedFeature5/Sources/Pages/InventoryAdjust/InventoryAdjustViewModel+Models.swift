//
//  InventoryAdjustViewModel+Models.swift
//  M — State / Domain Models / DTOs
//

import Foundation

// MARK: - State

extension InventoryAdjustViewModel {
    struct State: Equatable, Sendable {
        // 例外：本頁必帶品項資料（mvvmc-model〈例外：Detail View 必帶初始資料〉）。
        // 代價已知並接受：放棄無參 `.init()`，Preview / 測試一律帶參注入。
        let itemID: String
        let itemName: String
        let currentQuantity: Int

        // 輸入緩衝：使用者還沒送出的東西不是業務實體 → 屬 State，不是 Domain Model
        var quantityText: String = ""
        var reason: AdjustReason?
        var note: String = ""

        var api: API = .init()

        /// 調整數量：可正可負、不可為 0、必須是整數。解析失敗一律 nil。
        var quantityDelta: Int? {
            let trimmed = quantityText.trimmingCharacters(in: .whitespaces)
            guard let value = Int(trimmed), value != 0 else { return nil }
            return value
        }

        /// 送出後的預期庫存，純顯示用
        var previewQuantity: Int? {
            quantityDelta.map { currentQuantity + $0 }
        }

        /// 驗證是推導值 → computed property。不另存 stored 欄位，也不在 View 裡判斷。
        var isValid: Bool {
            quantityDelta != nil && reason != nil
        }

        var isSubmitting: Bool {
            api.submit == .loading
        }
    }

    struct API: Equatable, Sendable {
        var submit: APIStatus = .prepare
    }
}

// MARK: - Domain Models

extension InventoryAdjustViewModel {
    /// 會變成 `reason_code` 送給伺服器 → 出現在 API 合約裡 → 屬 Domain Model，不是 UI 狀態。
    /// 純值 enum 已隱含 Equatable，只宣告 Sendable。
    /// 顯示文案是 V 層的決策，這裡不放 title（見 InventoryAdjustView 頂端的 display helper）。
    enum AdjustReason: String, CaseIterable, Sendable {
        case restock
        case damaged
        case stocktake
        case returned
    }
}

// MARK: - DTOs

extension InventoryAdjustViewModel {
    /// 送給 API 的 request DTO 放 DTOs 區塊，由 handleAPIRequest 從輸入緩衝組出來。
    /// 刻意不在 State 上寫 `toDTO()`——那會讓輸入緩衝反過來知道 API 合約。
    struct AdjustRequestDTO: Codable, Sendable {
        var item_id: String
        var quantity_delta: Int
        var reason_code: String
        var note: String?
    }

    /// 回應 DTO。本頁沒有對應的 Domain Model（結果以 primitive 走 onCallback 回父層），
    /// 所以沒有 `toDomain()`；DTO 仍止步於 handleAPIResponse，不進 State。
    struct AdjustResultDTO: Codable, Sendable {
        var item_id: String
        var stock_quantity: Int
        var adjusted_at: String
    }
}
