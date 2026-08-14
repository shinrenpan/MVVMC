//
//  OrderCreateMocks.swift
//  M — Mock（整檔 #if DEBUG）
//
//  註：規範說 mock 掛在 Domain Model 上、不掛 State / DTO。這一頁沒有 Domain Model
//  （見 Models 檔尾），而 Preview 又不該自己造資料，兩條規則在這裡碰頭。
//  取捨：讓樣本輸入留在 M 層的 Mocks 檔（掛在 Draft 上），Preview 端維持只做注入。
//

#if DEBUG
extension OrderCreateViewModel.Draft {
    static let mock: Self = .init(
        customerName: "王小明",
        productName: "無線耳機",
        quantityText: "2",
        note: "請於平日下午配送"
    )
}
#endif
