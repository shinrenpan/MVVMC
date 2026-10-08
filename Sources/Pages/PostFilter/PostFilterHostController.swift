import SwiftUI

@MainActor
final class PostFilterHostController: UIHostingController<PostFilterView> {
  private let viewModel: PostFilterViewModel

  /// 跨 feature 且需要回傳：父層只給 callback，VM 在這裡組好再掛上
  /// （`mvvmc-hostcontroller`〈兩種 init 形狀怎麼選〉第三列）——父層不認識 `PostFilterViewModel`。
  init(onCallback: @escaping @MainActor (PostFilterViewModel.Callback) async -> Void) {
    let viewModel = PostFilterViewModel()
    viewModel.onCallback = onCallback
    self.viewModel = viewModel
    super.init(rootView: PostFilterView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
