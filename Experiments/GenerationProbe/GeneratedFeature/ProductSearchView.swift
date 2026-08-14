//
//  ProductSearchView.swift
//  V — 純 SwiftUI，零導航邏輯、零業務邏輯
//

import SwiftUI

// MARK: - Display Helpers（Model → UI 型別，屬 V 層決策）

private extension ProductSearchViewModel.ProductStock {
    var color: Color {
        switch self {
        case .sufficient: .green
        case .low: .orange
        case .outOfStock: .secondary
        }
    }

    var title: String {
        switch self {
        case .sufficient: "庫存充足"
        case .low: "庫存偏低"
        case .outOfStock: "缺貨"
        }
    }
}

// MARK: - L1

struct ProductSearchView: View {
    let viewModel: ProductSearchViewModel

    var body: some View {
        @Bindable var bVM = viewModel

        ScrollView {
            VStack(spacing: 16) {
                SearchSection(keyword: $bVM.state.keyword)

                CategorySection(
                    categories: viewModel.state.categories,
                    selectedID: viewModel.state.selectedCategoryID,
                    status: viewModel.state.api.fetchCategories,
                    send: handleCategoryAction
                )

                ListSection(
                    products: viewModel.state.filteredProducts,
                    status: viewModel.state.api.fetchProducts,
                    send: handleListAction
                )
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            await viewModel.doAction(.view(.pullToRefresh))
        }
        .task {
            await viewModel.doAction(.view(.isFirstAppear))
        }
    }

    @MainActor
    private func handleCategoryAction(_ action: CategorySection.Action) {
        switch action {
        case let .categoryDidTap(id):
            Task { await viewModel.doAction(.view(.categoryDidTap(id))) }

        case .retryDidTap:
            Task { await viewModel.doAction(.view(.categoryRetryDidTap)) }
        }
    }

    @MainActor
    private func handleListAction(_ action: ListSection.Action) {
        switch action {
        case let .productDidTap(product):
            Task { await viewModel.doAction(.view(.productDidTap(product))) }

        case .retryDidTap:
            Task { await viewModel.doAction(.view(.productRetryDidTap)) }
        }
    }
}

// MARK: - Search 家族

private extension ProductSearchView {
    /// 純值同步（TextField 輸入）→ 用 @Binding，不需要 enum Action（見 architecture §2 / §3）
    struct SearchSection: View {
        @Binding var keyword: String

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("搜尋商品", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                    }
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Category 家族

private extension ProductSearchView {
    struct CategorySection: View {
        enum Action: Sendable {
            case categoryDidTap(ProductSearchViewModel.Category.ID)
            case retryDidTap
        }

        let categories: [ProductSearchViewModel.Category]
        let selectedID: ProductSearchViewModel.Category.ID?
        let status: APIStatus
        let send: @MainActor (Action) -> Void

        var body: some View {
            CardContainer {
                switch status {
                case .prepare, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)

                case .success:
                    chips()

                case let .error(message):
                    errorContent(message: message)
                }
            }
        }

        @ViewBuilder
        private func chips() -> some View {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        CategoryChip(
                            name: category.name,
                            isSelected: category.id == selectedID
                        ) { action in
                            switch action {
                            case .chipDidTap:
                                send(.categoryDidTap(category.id))
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(minHeight: 44)
        }

        @ViewBuilder
        private func errorContent(message: String) -> some View {
            VStack(spacing: 8) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("重新載入分類") {
                    send(.retryDidTap)
                }
                .font(.footnote)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    struct CategoryChip: View {
        enum Action: Sendable {
            case chipDidTap
        }

        let name: String
        let isSelected: Bool
        let send: @MainActor (Action) -> Void

        var body: some View {
            Button {
                send(.chipDidTap)
            }
            label: {
                Text(name)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                    )
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - List 家族

private extension ProductSearchView {
    struct ListSection: View {
        enum Action: Sendable {
            case productDidTap(ProductSearchViewModel.Product)
            case retryDidTap
        }

        let products: [ProductSearchViewModel.Product]
        let status: APIStatus
        let send: @MainActor (Action) -> Void

        var body: some View {
            CardContainer {
                switch status {
                case .prepare, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)

                case .success:
                    rows()

                case let .error(message):
                    errorContent(message: message)
                }
            }
        }

        @ViewBuilder
        private func rows() -> some View {
            if products.isEmpty {
                Text("找不到符合條件的商品")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
            else {
                LazyVStack(spacing: 0) {
                    ForEach(products) { product in
                        ListRow(product: product) { action in
                            switch action {
                            case .rowDidTap:
                                send(.productDidTap(product))
                            }
                        }

                        if product.id != products.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func errorContent(message: String) -> some View {
            VStack(spacing: 8) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("重新載入商品") {
                    send(.retryDidTap)
                }
                .font(.footnote)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    struct ListRow: View {
        enum Action: Sendable {
            case rowDidTap
        }

        let product: ProductSearchViewModel.Product
        let send: @MainActor (Action) -> Void

        var body: some View {
            Button {
                send(.rowDidTap)
            }
            label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text(product.price, format: .currency(code: "TWD"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    ListStockBadge(stock: product.stock)

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// L4：無狀態的純裝飾零件
    struct ListStockBadge: View {
        let stock: ProductSearchViewModel.ProductStock

        var body: some View {
            Text(stock.title)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(stock.color)
                .background(Capsule().fill(stock.color.opacity(0.15)))
        }
    }
}

// MARK: - Preview

// 註：`#Preview { }` 的 body 是 ViewBuilder，**不接受 assignment 語句也不接受 return**，
// 所以 mvvmc-view §12 的模板（多行 `vm.state.x = .mocks` + `return View(...)`）實測編不過
// （Xcode 26.4.1 / Swift 6.3.1）。這裡改用 IIFE 把注入包成單一運算式，語意與規範一致。
#if DEBUG
#Preview("兩支 API 都成功") {
    ProductSearchView(viewModel: {
        let vm = ProductSearchViewModel()
        vm.state.categories = ProductSearchViewModel.Category.mocks
        vm.state.products = ProductSearchViewModel.Product.mocks
        vm.state.api.fetchCategories = .success
        vm.state.api.fetchProducts = .success
        return vm
    }())
}

#Preview("分類失敗、商品成功") {
    ProductSearchView(viewModel: {
        let vm = ProductSearchViewModel()
        vm.state.products = ProductSearchViewModel.Product.mocks
        vm.state.api.fetchCategories = .error("分類載入失敗，請稍後再試")
        vm.state.api.fetchProducts = .success
        return vm
    }())
}

#Preview("商品失敗、分類成功") {
    ProductSearchView(viewModel: {
        let vm = ProductSearchViewModel()
        vm.state.categories = ProductSearchViewModel.Category.mocks
        vm.state.api.fetchCategories = .success
        vm.state.api.fetchProducts = .error("商品載入失敗，請稍後再試")
        return vm
    }())
}

#Preview("搜尋後無結果") {
    ProductSearchView(viewModel: {
        let vm = ProductSearchViewModel()
        vm.state.categories = ProductSearchViewModel.Category.mocks
        vm.state.products = ProductSearchViewModel.Product.mocks
        vm.state.keyword = "找不到的東西"
        vm.state.api.fetchCategories = .success
        vm.state.api.fetchProducts = .success
        return vm
    }())
}

#Preview("載入中") {
    ProductSearchView(viewModel: ProductSearchViewModel())
}
#endif
