import Testing
@testable import MVVMCDemo

/// `mvvmc-testing/references/patterns.md`〈Swift Testing 實用手法〉那三段範例的活體版本。
///
/// **這個檔案存在的理由不是測試 demo，是測試規範。** 那三段原本只帶一個戳記
/// （「Swift 6.3.1 / Xcode 26.4.1 編譯驗證過」），而戳記不會自己過期——`TODO.md`
/// 已經記著它們在 Xcode 27 下沒有重跑。戳記留在文件裡，沒有任何東西在複驗它；
/// 放進測試 target 之後，每一次 `xcodebuild test` 都是一次複驗。
///
/// 所以這裡的斷言刻意保持樸素：重點是**這三種寫法在當前工具鏈下仍然編得過、跑得對**，
/// 不是 demo 的商業邏輯（那由其他三個測試檔負責）。
@MainActor
struct SwiftTestingTechniqueTests {

  // MARK: - 參數化測試：同一段驗證跑多組輸入

  @Test(arguments: [0, 1, 5])
  func `fetchPosts maps every DTO regardless of count`(count: Int) async {
    let vm = PostListViewModel()
    let dtos = (0..<count).map {
      PostListViewModel.PostDTO(id: $0, user_id: $0, title: "Title \($0)", body: "Body")
    }
    await vm.doAction(.apiResponse(.fetchPosts(.success(dtos))))
    #expect(vm.state.posts.count == count)
  }

  // MARK: - `#require` 解 Optional：失敗即中止，不讓後續斷言連環爆

  /// `UserDTO.toDomain()` 在 `name` 為空時回傳 `nil`，所以 `state.user` 真的可能是 nil——
  /// 這裡不是為了示範而硬湊一個 Optional。
  @Test
  func `fetchUser success sets user`() async throws {
    let vm = UserDetailViewModel(userId: 1)
    let dto = UserDetailViewModel.UserDTO(
      id: 1, name: "Alice Chen", email: "alice@example.com", company: "MVVMC Corp"
    )
    await vm.doAction(.apiResponse(.fetchUserDidFinish(.success(dto))))

    let user = try #require(vm.state.user)   // nil → 在此中止，不會爆在下一行
    #expect(user.name == "Alice Chen")
    #expect(user.company == "MVVMC Corp")
  }

  // MARK: - `confirmation` 驗證呼叫次數

  /// 「有沒有被呼叫」用變數捕捉就夠；`confirmation` 的價值在「**剛好幾次**」。
  @Test
  func `didSelectUser fires the callback exactly once`() async {
    await confirmation("callback fired", expectedCount: 1) { fired in
      let vm = PostFilterViewModel()
      vm.onCallback = { _ in fired() }
      await vm.doAction(.view(.didSelectUser(.init(id: 3))))
    }
  }

  /// 防重入那一半在 demo 裡走的是 state 斷言而不是 callback
  /// （`isFirstAppear` 的 guard 擋掉的是 API 請求，不是回呼），
  /// 見 `PostListViewModelTests.isFirstAppear guard blocks duplicate trigger`。
  @Test
  func `cancel and showAll each fire exactly once`() async {
    await confirmation("two distinct callbacks", expectedCount: 2) { fired in
      let vm = PostFilterViewModel()
      vm.onCallback = { _ in fired() }
      await vm.doAction(.view(.showAll))
      await vm.doAction(.view(.cancel))
    }
  }
}
