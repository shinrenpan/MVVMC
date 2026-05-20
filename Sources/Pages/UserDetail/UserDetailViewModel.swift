import Observation

@MainActor
@Observable
final class UserDetailViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  @ObservationIgnored
  let userId: Int

  var state: State = .init()

  init(userId: Int) {
    self.userId = userId
  }

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    case let .apiRequest(request): await handleAPIRequest(request)
    case let .apiResponse(response): await handleAPIResponse(response)
    }
  }
}

// MARK: - View Action

extension UserDetailViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchUser(userId: userId)))
    }
  }
}

// MARK: - API Request

extension UserDetailViewModel {
  enum APIRequest: Sendable {
    case fetchUser(userId: Int)
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case let .fetchUser(userId):
      guard !state.api.fetchUser.isLoading else { return }
      state.api.fetchUser = .loading
      do {
        let dto = try await UserDetailAPI.fetch(userId: userId)
        await doAction(.apiResponse(.fetchUserDidFinish(.success(dto))))
      } catch {
        await doAction(.apiResponse(.fetchUserDidFinish(.failure(.message(error.localizedDescription)))))
      }
    }
  }
}

// MARK: - API Response

extension UserDetailViewModel {
  enum APIResponse: Sendable {
    case fetchUserDidFinish(Result<UserDTO, APIError>)
  }

  private func handleAPIResponse(_ response: APIResponse) async {
    switch response {
    case let .fetchUserDidFinish(.success(dto)):
      state.user = dto.toDomain()
      state.api.fetchUser = .success
    case let .fetchUserDidFinish(.failure(.message(msg))):
      state.api.fetchUser = .error(msg)
    }
  }
}
