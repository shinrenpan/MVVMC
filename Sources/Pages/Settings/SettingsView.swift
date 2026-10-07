import SwiftUI

struct SettingsView: View {
  let viewModel: SettingsViewModel

  var body: some View {
    List {
      Section("一般") {
        LabeledContent("版本", value: "1.0.0")
        LabeledContent("Build", value: "1")
      }
    }
    .navigationTitle("設定")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("關閉", systemImage: "xmark") {
          Task { await viewModel.doAction(.view(.close)) }
        }
      }
    }
  }
}

#if DEBUG
#Preview {
  NavigationStack {
    SettingsView(viewModel: SettingsViewModel())
  }
}
#endif
