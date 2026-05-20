enum APIError: Error, Sendable {
  case message(String)
}

enum APIStatus: Equatable, Sendable {
  case prepare
  case loading
  case success
  case error(String)

  var isLoading: Bool {
    if case .loading = self { return true }
    return false
  }
}
