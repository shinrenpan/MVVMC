import SwiftUI
import UIKit

/// 三個步驟共用同一份草稿 → 一個 feature、一個 HostController、一個 ViewModel。
/// 因此沒有中繼鏈、沒有深層回傳，送出成功後父層只要 `back(from:)` 一次就回到訂單詳情。
@MainActor
final class ReturnRequestHostController: UIHostingController<ReturnRequestView> {

    private let viewModel: ReturnRequestViewModel

    /// 由父 HostController 建好 ViewModel（它要先掛 `onCallback`）再注入，
    /// 對應 `mvvmc-hostcontroller` Template 3。
    init(viewModel: ReturnRequestViewModel) {
        self.viewModel = viewModel
        super.init(rootView: ReturnRequestView(viewModel: viewModel))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
