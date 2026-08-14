import SwiftUI
import UIKit

@MainActor
final class OrderDetailHostController: UIHostingController<OrderDetailView> {

    private let viewModel: OrderDetailViewModel

    /// 跨 feature 只收 primitive；ViewModel 在 C 層組裝
    ///（見 `mvvmc-hostcontroller`〈變體：傳入原始參數〉）
    init(orderID: String) {
        let viewModel = OrderDetailViewModel(orderID: orderID)
        self.viewModel = viewModel
        super.init(rootView: OrderDetailView(viewModel: viewModel))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.onRoute = { [weak self] router in
            self?.handleRouter(router)
        }
    }
}

private extension OrderDetailHostController {
    func handleRouter(_ router: OrderDetailViewModel.Router) {
        switch router {
        case let .toReturnRequest(orderID):
            let returnVM = ReturnRequestViewModel(orderID: orderID)

            returnVM.onCallback = { [weak self] callback in
                guard let self else { return }

                switch callback {
                case let .didSubmit(returnID):
                    // 退貨申請是「一個 feature 內的三個 step」，所以這裡只退一層就回到訂單詳情，
                    // 不需要逐層中繼、也不需要 backTo（見 `mvvmc-structure`〈多步驟流程優先合成一個 feature〉）
                    AppRouter.shared.back(from: self)
                    await self.viewModel.doAction(.view(.returnRequestDidSubmit(returnID: returnID)))

                case .didCancel:
                    AppRouter.shared.back(from: self)
                }
            }

            // 用 `.modal` 而非預設 `.push`：表單填到一半不該被隨手側滑掉。
            // 目前手勢政策與轉場樣式綁在同一個 TransitionStyle 上，
            // 這是規範記載的已知限制與唯一解（見 `mvvmc-navigation`〈轉場與手勢〉）
            AppRouter.shared.to(
                ReturnRequestHostController(viewModel: returnVM),
                from: self,
                style: .modal
            )
        }
    }
}
