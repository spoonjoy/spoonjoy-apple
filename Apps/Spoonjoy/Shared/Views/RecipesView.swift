import SpoonjoyCore
import Foundation
import SwiftUI

struct RecipesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let viewModel: RecipeCatalogViewModel
    let openRoute: (AppRoute) -> Void
    @State private var state: RecipeCatalogState

    init(
        viewModel: RecipeCatalogViewModel,
        openRoute: @escaping (AppRoute) -> Void
    ) {
        self.viewModel = viewModel
        self.openRoute = openRoute
        _state = State(initialValue: viewModel.state)
    }

    var body: some View {
        KitchenTablePage {
            KitchenTableHeader(
                eyebrow: "Cookbook",
                title: "Recipes",
                subtitle: state.resultCountLabel
            )

            if let emptyState = state.emptyState {
                KitchenEmptySection(title: emptyState, systemImage: "book.closed", tint: KitchenTableTheme.brass)
            } else {
                KitchenTableSection(title: "Recipe Index") {
                    ForEach(state.rows) { row in
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
        .task {
            await loadCatalog()
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

    @MainActor private func loadCatalog() async {
        do {
            try await viewModel.load(query: state.query, limit: state.limit)
            state = viewModel.state
        } catch {
            state = viewModel.state
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
