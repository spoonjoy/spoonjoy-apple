import SpoonjoyCore
import Foundation
import SwiftUI

struct RecipesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let viewModel: RecipeCatalogViewModel
    let openRoute: (AppRoute) -> Void
    @State private var state: RecipeCatalogState
    @State private var query: String
    @State private var isLoading = false

    init(
        viewModel: RecipeCatalogViewModel,
        openRoute: @escaping (AppRoute) -> Void
    ) {
        self.viewModel = viewModel
        self.openRoute = openRoute
        _state = State(initialValue: viewModel.state)
        _query = State(initialValue: viewModel.state.query)
    }

    var body: some View {
        KitchenTablePage {
            KitchenTableHeader(
                eyebrow: "Cookbook",
                title: "Recipes",
                subtitle: state.resultCountLabel
            )

            OfflineStatusView(indicator: state.offlineIndicator, prominence: .quiet)

            if isLoading, state.rows.isEmpty {
                KitchenTableLoadingStateView(title: "Loading recipes", subtitle: "Opening your recipe index.", systemImage: "book.closed")
            } else if let emptyState = state.emptyState {
                recipesEmptyState(emptyState)
            } else if let leadRow = state.leadRow {
                RecipeCatalogLead(row: leadRow, openRoute: openRoute)
                if !state.indexRows.isEmpty {
                    recipeIndexSection(rows: state.indexRows)
                }
            } else {
                recipeIndexSection(rows: state.rows)
            }
        }
        .searchable(text: $query, prompt: "Search recipes")
        .onSubmit(of: .search) {
            Task {
                await loadCatalog(query: query)
            }
        }
        .task {
            await loadCatalog(query: query)
            await RecipeCoverPrefetcher.prefetch(state.rows.compactMap(\.coverImageURL))
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "recipes",
                source: "RecipesView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
    }

    private func recipesEmptyState(_ emptyState: RecipeCatalogEmptyState) -> some View {
        KitchenTableSection(title: emptyState.title) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: emptyState.systemImage)
                    .font(.title3)
                    .foregroundStyle(KitchenTableTheme.brass)
                    .frame(width: 28)
                Text(emptyState.message)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(KitchenTableTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        }
    }

    private func recipeIndexSection(rows: [RecipeCatalogRowViewModel]) -> some View {
        KitchenTableSection(title: "Recipe Index") {
            ForEach(rows) { row in
                Button {
                    openRoute(row.openRoute)
                } label: {
                    RecipeIndexRow(row: row)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RecipeCatalogLead: View {
    let row: RecipeCatalogRowViewModel
    let openRoute: (AppRoute) -> Void

    var body: some View {
        Button {
            openRoute(row.openRoute)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                RecipeCoverImage(
                    url: row.coverImageURL,
                    title: row.title,
                    subtitle: nil,
                    showsFallbackLabel: false
                )
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220)
                .clipped()

                Text("Latest from the kitchen".uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(KitchenTableTheme.brass)
                Text(row.title)
                    .font(KitchenTableTheme.displayTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(leadSubtitle)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens recipe detail")
    }

    private var leadSubtitle: String {
        [
            row.subtitle,
            row.chefLine,
            row.servingsLabel
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " - ")
    }
}

extension RecipesView {
    @MainActor private func loadCatalog(query: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await viewModel.load(query: query, limit: state.limit)
            state = viewModel.state
            self.query = viewModel.state.query
        } catch {
            state = viewModel.state
            self.query = viewModel.state.query
        }
    }
}

private struct RecipeIndexRow: View {
    let row: RecipeCatalogRowViewModel

    init(row: RecipeCatalogRowViewModel) {
        self.row = row
    }

    var body: some View {
        KitchenTableObjectRow(title: row.title, subtitle: rowSubtitle) {
            RecipeCoverImage(
                url: row.coverImageURL,
                title: row.title,
                subtitle: nil,
                showsFallbackLabel: false
            )
        } trailing: {
            Image(systemName: "chevron.forward")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
                .accessibilityHidden(true)
        }
        .accessibilityHint("Opens recipe detail")
    }

    private var rowSubtitle: String {
        [
            row.subtitle,
            row.chefLine,
            row.servingsLabel
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " - ")
    }
}

private enum RecipeCoverPrefetcher {
    static func prefetch(_ urls: [URL]) async {
        let uniqueURLs = Array(Set(urls)).prefix(12)
        await withTaskGroup(of: Void.self) { group in
            for url in uniqueURLs {
                group.addTask {
                    var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 3)
                    request.allowsConstrainedNetworkAccess = true
                    request.allowsExpensiveNetworkAccess = true
                    _ = try? await URLSession.shared.data(for: request)
                }
            }
        }
    }
}
