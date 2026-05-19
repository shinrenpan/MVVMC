//  ___FILENAME___
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

import SwiftUI

@MainActor
final class ___FILEBASENAME___HostController: UIHostingController<___FILEBASENAME___View> {
  private let viewModel: ___FILEBASENAME___ViewModel
  private var tasks: [String: Task<Void, Never>] = [:]

  init(viewModel: ___FILEBASENAME___ViewModel) {
    self.viewModel = viewModel
    super.init(rootView: ___FILEBASENAME___View(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    tasks["onAppear"]?.cancel()
    tasks["onAppear"] = Task { await viewModel.doAction(.view(.onAppear)) }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    tasks.values.forEach { $0.cancel() }
    tasks.removeAll()
    viewModel.onAction = nil
  }
}
