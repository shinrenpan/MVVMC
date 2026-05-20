import SwiftUI

struct PostFilterView: View {
  let viewModel: PostFilterViewModel

  var body: some View {
    NavigationStack {
      List {
        Button("Show All") {
          Task { await viewModel.doAction(.view(.showAll)) }
        }
        ForEach(viewModel.state.users) { user in
          Button(user.displayName) {
            Task { await viewModel.doAction(.view(.didSelectUser(user))) }
          }
        }
      }
      .navigationTitle("Filter by User")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            Task { await viewModel.doAction(.view(.cancel)) }
          }
        }
      }
    }
  }
}

#if DEBUG
#Preview {
  PostFilterView(viewModel: PostFilterViewModel())
}
#endif
