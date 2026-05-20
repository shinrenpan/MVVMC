import Testing
@testable import MVVMCDemo

@MainActor
struct UserDetailViewModelTests {

  // MARK: - isFirstAppear

  @Test
  func `isFirstAppear guard blocks duplicate trigger`() async {
    let vm = UserDetailViewModel(userId: 1)
    vm.state.isFirstAppear = false
    await vm.doAction(.view(.isFirstAppear))
    #expect(vm.state.api.fetchUser == .prepare)
  }

  // MARK: - apiResponse injection（不走 API，直接注入結果）

  @Test
  func `fetchUser success sets user state`() async {
    let vm = UserDetailViewModel(userId: 1)
    let dto = UserDetailViewModel.UserDTO(
      id: 1, name: "Alice Chen", email: "alice@example.com", company: "MVVMC Corp"
    )
    await vm.doAction(.apiResponse(.fetchUserDidFinish(.success(dto))))
    #expect(vm.state.user?.name == "Alice Chen")
    #expect(vm.state.user?.email == "alice@example.com")
    #expect(vm.state.api.fetchUser == .success)
  }

  @Test
  func `fetchUser failure sets error status`() async {
    let vm = UserDetailViewModel(userId: 99)
    await vm.doAction(.apiResponse(.fetchUserDidFinish(.failure(.message("Not found")))))
    #expect(vm.state.user == nil)
    #expect(vm.state.api.fetchUser == .error("Not found"))
  }
}
