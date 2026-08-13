import Testing
@testable import MVVMCDemo

@MainActor
struct PostListViewModelTests {

  // MARK: - isFirstAppear

  @Test
  func `isFirstAppear guard blocks duplicate trigger`() async {
    let vm = PostListViewModel()
    vm.state.isFirstAppear = false
    await vm.doAction(.view(.isFirstAppear))
    #expect(vm.state.api.fetchPosts == .prepare)
  }

  // MARK: - apiResponse injection（不走 API，直接注入結果）

  @Test
  func `fetchPosts success populates posts`() async {
    let vm = PostListViewModel()
    let dtos: [PostListViewModel.PostDTO] = [
      .init(id: 1, user_id: 1, title: "Title A", body: "Body A"),
      .init(id: 2, user_id: 2, title: "Title B", body: "Body B"),
    ]
    await vm.doAction(.apiResponse(.fetchPosts(.success(dtos))))
    #expect(vm.state.posts.count == 2)
    #expect(vm.state.posts[0].title == "Title A")
    #expect(vm.state.posts[0].userId == 1)
    #expect(vm.state.api.fetchPosts == .success)
  }

  @Test
  func `fetchPosts failure sets error status`() async {
    let vm = PostListViewModel()
    await vm.doAction(.apiResponse(.fetchPosts(.failure(.message("Network error")))))
    #expect(vm.state.posts.isEmpty)
    #expect(vm.state.api.fetchPosts == .error("Network error"))
  }

  // 善用 State 的 Equatable：一行鎖定完整狀態，多餘的變動也會被抓出
  @Test
  func `fetchPosts success produces expected state`() async {
    let vm = PostListViewModel()
    let dtos: [PostListViewModel.PostDTO] = [
      .init(id: 1, user_id: 1, title: "Title A", body: "Body A"),
    ]
    await vm.doAction(.apiResponse(.fetchPosts(.success(dtos))))

    var expected = PostListViewModel.State()
    expected.posts = [.init(id: 1, userId: 1, title: "Title A", body: "Body A")]
    expected.api.fetchPosts = .success
    #expect(vm.state == expected)
  }

  // MARK: - Router（驗證導航意圖，不驗證導航行為）

  @Test
  func `postDidTap routes to detail`() async {
    let vm = PostListViewModel()
    var received: PostListViewModel.Router?
    vm.onRoute = { received = $0 }

    let post = PostListViewModel.Post(id: 1, userId: 1, title: "Title A", body: "Body A")
    await vm.doAction(.view(.postDidTap(post)))
    #expect(received == .toDetail(post))
  }

  @Test
  func `userDidTap routes to user detail`() async {
    let vm = PostListViewModel()
    var received: PostListViewModel.Router?
    vm.onRoute = { received = $0 }

    await vm.doAction(.view(.userDidTap(3)))
    #expect(received == .toUserDetail(3))
  }

  // MARK: - filter

  @Test
  func `didFilterUser sets filterUserId`() async {
    let vm = PostListViewModel()
    vm.state.isFirstAppear = false
    // 注意：此測試會觸發實際 API（含 Task.sleep），約 1 秒完成
    await vm.doAction(.view(.didFilterUser(3)))
    #expect(vm.state.filterUserId == 3)
  }

  @Test
  func `clearFilter resets filterUserId to nil`() async {
    let vm = PostListViewModel()
    vm.state.isFirstAppear = false
    vm.state.filterUserId = 3
    // 注意：此測試會觸發實際 API（含 Task.sleep），約 1 秒完成
    await vm.doAction(.view(.clearFilter))
    #expect(vm.state.filterUserId == nil)
  }
}
