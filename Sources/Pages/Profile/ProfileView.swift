import SwiftUI

struct ProfileView: View {
  let viewModel: ProfileViewModel

  var body: some View {
    List {
      Section("App") {
        LabeledContent("版本", value: "1.0.0")
      }
      Section {
        Button("前往文章列表") {
          Task { await viewModel.doAction(.view(.toPosts)) }
        }
      }
    }
    .navigationTitle("Profile")
  }
}

#if DEBUG
#Preview {
  ProfileView(viewModel: ProfileViewModel())
}
#endif
