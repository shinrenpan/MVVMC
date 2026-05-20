import Observation

@MainActor
@Observable
final class PostListViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  @ObservationIgnored
  var onRoute: (@MainActor (Router) -> Void)?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    case let .apiRequest(request): await handleAPIRequest(request)
    case let .apiResponse(response): await handleAPIResponse(response)
    }
  }
}

// MARK: - View Action

extension PostListViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case postDidTap(Post)
    case userDidTap(Int)
    case showFilter
    case didFilterUser(Int)
    case clearFilter
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchPosts(userId: nil)))
    case let .postDidTap(post):
      onRoute?(.toDetail(post))
    case let .userDidTap(userId):
      onRoute?(.toUserDetail(userId))
    case .showFilter:
      onRoute?(.toFilter)
    case let .didFilterUser(userId):
      state.filterUserId = userId
      state.api.fetchPosts = .prepare
      await doAction(.apiRequest(.fetchPosts(userId: userId)))
    case .clearFilter:
      state.filterUserId = nil
      state.api.fetchPosts = .prepare
      await doAction(.apiRequest(.fetchPosts(userId: nil)))
    }
  }
}

// MARK: - Router

extension PostListViewModel {
  enum Router: Sendable {
    case toDetail(Post)
    case toUserDetail(Int)
    case toFilter
  }
}

// MARK: - API Request

extension PostListViewModel {
  enum APIRequest: Sendable {
    case fetchPosts(userId: Int?)
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case let .fetchPosts(userId):
      guard !state.api.fetchPosts.isLoading else { return }
      state.api.fetchPosts = .loading
      do {
        let dtos = try await PostListAPI.fetch(userId: userId)
        await doAction(.apiResponse(.fetchPosts(.success(dtos))))
      } catch {
        await doAction(.apiResponse(.fetchPosts(.failure(.message(error.localizedDescription)))))
      }
    }
  }
}

// MARK: - API Response

extension PostListViewModel {
  enum APIResponse: Sendable {
    case fetchPosts(Result<[PostDTO], APIError>)
  }

  private func handleAPIResponse(_ response: APIResponse) async {
    switch response {
    case let .fetchPosts(.success(dtos)):
      state.posts = dtos.map { $0.toDomain() }
      state.api.fetchPosts = .success
    case let .fetchPosts(.failure(.message(msg))):
      state.api.fetchPosts = .error(msg)
    }
  }
}
