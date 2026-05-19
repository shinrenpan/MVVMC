import Observation

@MainActor
@Observable
final class PostListViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case route(Router)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  @ObservationIgnored
  var onAction: (@MainActor (Action) -> Void)?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    case let .route(router): await handleRouter(router)
    case let .apiRequest(request): await handleAPIRequest(request)
    case let .apiResponse(response): await handleAPIResponse(response)
    }
  }
}

// MARK: - View Action

extension PostListViewModel {
  enum ViewAction: Sendable {
    case onAppear
    case postDidTap(Post)
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .onAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchPosts))
    case let .postDidTap(post):
      await doAction(.route(.toDetail(post)))
    }
  }
}

// MARK: - Router

extension PostListViewModel {
  enum Router: Sendable {
    case toDetail(Post)
  }

  private func handleRouter(_ router: Router) async {
    onAction?(.route(router))
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
