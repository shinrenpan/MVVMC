//
//  InventoryListViewModel+Models.swift
//  M — State / Domain Models / DTOs
//

import Foundation

// MARK: - State

extension InventoryListViewModel {
    struct State: Equatable, Sendable {
        /// 分頁大小。游標形式與 pageSize 放哪屬專案自訂（mvvmc-viewmodel patterns〈分頁載入〉）
        static let pageSize: Int = 30

        var isFirstAppear: Bool = true
        var api: API = .init()

        // 低頻：只有分頁載入 / 下拉刷新 / 調整成功才變動
        var items: [Item] = []
        var page: Int = 0

        /// 「還有沒有下一頁」來自 API 回應，不由 View 用「回傳筆數 < pageSize」去猜
        var hasMore: Bool = true

        // 高頻：每 10 秒輪詢一次。
        // 刻意與 items 平行擺放，不塞進 Item / 不做成 items 的聚合欄位——
        // 否則每輪輪詢都會讓整包 items 不相等，ListSection 的 props 比較永遠不成立，
        // V 層再怎麼拆 struct 都擋不住（mvvmc-model〈高頻變動的欄位不要塞進低頻 Model〉）
        var liveTotal: LiveTotal?

        /// 輪詢閘門：只有 Preview / 測試會設成 true，正式流程永遠是 false。
        /// 這**不是**防重入旗標（那是明文禁止的 fail-closed 寫法），
        /// 而是為了滿足「Preview 禁止觸發真實網路」所需的開關——輪詢的 `.task`
        /// 沒有 `isFirstAppear` 那種天然的 run-once 旗標可關。
        var isSyncSuspended: Bool = false

        // 推導值：由現有欄位算出、只被 UI 使用 → computed property，不另存 stored 欄位
        var isEmpty: Bool { items.isEmpty }
    }

    /// 請求狀態容器。形狀不在規範範圍，這裡沿用 demo 的做法。
    /// 首次載入與載入更多**各自一格**——共用一格的話，第 2 頁失敗會蓋掉第 1 頁的 .success，
    /// View 就再也無法表達「內容還在、只是下一頁沒載到」。
    struct API: Equatable, Sendable {
        var fetchItems: APIStatus = .prepare
        var fetchMoreItems: APIStatus = .prepare
        var syncTotal: APIStatus = .prepare
    }
}

// MARK: - Domain Models

extension InventoryListViewModel {
    struct Item: Identifiable, Equatable, Sendable {
        let id: String
        var name: String
        var quantity: Int
    }
}

extension InventoryListViewModel {
    /// 輪詢回來的即時總量。與 Item 分開，因為兩者更新頻率差三個數量級。
    struct LiveTotal: Equatable, Sendable {
        var totalQuantity: Int
        var syncedAt: Date
    }
}

// MARK: - DTOs

// 註：此 API 假設以 snake_case 回傳，DTO 命名 1:1 對齊 response key，不加 CodingKeys。
extension InventoryListViewModel {
    struct InventoryPageDTO: Codable, Sendable {
        var items: [InventoryItemDTO]
        var page: Int
        var page_size: Int
        var has_more: Bool
    }

    // L2：只被 InventoryPageDTO 使用
    struct InventoryItemDTO: Codable, Sendable {
        var item_id: String
        var item_name: String
        var stock_quantity: Int
        var updated_at: String

        func toDomain() -> Item? {
            guard !item_id.isEmpty else { return nil }
            return .init(id: item_id, name: item_name, quantity: stock_quantity)
        }
    }
}

extension InventoryListViewModel {
    struct InventoryTotalDTO: Codable, Sendable {
        var total_quantity: Int
        var synced_at: TimeInterval

        func toDomain() -> LiveTotal {
            .init(
                totalQuantity: total_quantity,
                syncedAt: Date(timeIntervalSince1970: synced_at)
            )
        }
    }
}
