import Observation
import UIKit

@MainActor
@Observable
final class OrderListViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  var onRoute: ((Router) -> Void)?

  weak var presentingController: UIViewController?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    case let .apiRequest(request): await handleAPIRequest(request)
    case let .apiResponse(response): await handleAPIResponse(response)
    }
  }

  func refresh() async {
    await doAction(.apiRequest(.fetchOrders))
  }
}

// MARK: - View Action

extension OrderListViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case orderDidTap(Order)
    case shareDidTap(URL)
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchOrders))

    case let .orderDidTap(order):
      onRoute?(.toDetail(order))

    case let .shareDidTap(url):
      let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      presentingController?.present(activity, animated: true)
    }
  }
}

// MARK: - Router

extension OrderListViewModel {
  enum Router: Sendable {
    case toDetail(Order)
  }
}

// MARK: - API

extension OrderListViewModel {
  enum APIRequest: Sendable {
    case fetchOrders
  }

  enum APIResponse: Sendable {
    case fetchOrdersDidFinish(Result<[OrderDTO], APIError>)
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case .fetchOrders:
      do {
        let dtos = try await OrderAPI.fetch()
        state.orderDTOs = dtos
        await doAction(.apiResponse(.fetchOrdersDidFinish(.success(dtos))))
      } catch {
        state.errorMessage = error
      }
    }
  }

  private func handleAPIResponse(_ response: APIResponse) async {
    switch response {
    case let .fetchOrdersDidFinish(.success(dtos)):
      state.orderDTOs = dtos
    case let .fetchOrdersDidFinish(.failure(error)):
      state.errorMessage = error
    }
  }
}
