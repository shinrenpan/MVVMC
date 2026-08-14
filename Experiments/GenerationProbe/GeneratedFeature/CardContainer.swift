//
//  CardContainer.swift
//  共用 UI 組件（Sources/Components/）— 不帶 feature 前綴、不屬於任何頁面的 private extension
//
//  提拔理由（mvvmc-view §4〈跨 Section 共用組件的處理〉）：
//  CategorySection 與 ListSection 兩個 Section 都要用同一種圓角卡片外框，
//  塞進其中任一個的 private extension 會造成另一個反向依賴。
//
//  Slot 模式（mvvmc-view §10）：容器只負責外框樣式，內容完全由呼叫方決定。
//  容器自身沒有互動 → 不定義 enum Action。
//

import SwiftUI

struct CardContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}

#if DEBUG
#Preview("卡片容器") {
    VStack(spacing: 16) {
        CardContainer {
            Text("單行內容")
        }

        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Text("多行內容").font(.headline)
                Text("容器只管外框，內容自由組合")
            }
        }
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
#endif
