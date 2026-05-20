import Testing
@testable import MVVMCDemo

@MainActor
struct PostFilterViewModelTests {

  @Test
  func `didSelectUser calls correct callback`() async {
    let vm = PostFilterViewModel()
    var received: PostFilterViewModel.Callback?
    vm.onCallback = { received = $0 }

    let user = PostFilterViewModel.User(id: 2)
    await vm.doAction(.view(.didSelectUser(user)))
    #expect(received == .didSelectUser(user))
  }

  @Test
  func `showAll calls showAll callback`() async {
    let vm = PostFilterViewModel()
    var received: PostFilterViewModel.Callback?
    vm.onCallback = { received = $0 }

    await vm.doAction(.view(.showAll))
    #expect(received == .showAll)
  }

  @Test
  func `cancel calls didCancel callback`() async {
    let vm = PostFilterViewModel()
    var received: PostFilterViewModel.Callback?
    vm.onCallback = { received = $0 }

    await vm.doAction(.view(.cancel))
    #expect(received == .didCancel)
  }
}
