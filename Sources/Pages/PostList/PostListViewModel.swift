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
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchPosts))
    case let .postDidTap(post):
      onRoute?(.toDetail(post))
    }
  }
}

// MARK: - Router

extension PostListViewModel {
  enum Router: Sendable {
    case toDetail(Post)
  }
}

// MARK: - API Request

extension PostListViewModel {
  enum APIRequest: Sendable {
    case fetchPosts
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case .fetchPosts:
      guard !state.api.fetchPosts.isLoading else { return }
      state.api.fetchPosts = .loading
      do {
        let dtos = try await PostListAPI.fetch()
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
