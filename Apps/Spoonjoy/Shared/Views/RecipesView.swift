import SpoonjoyCore
import SwiftUI

struct RecipesView: View {
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
        List {
            if let emptyState = state.emptyState {
                Section {
                    Label(emptyState, systemImage: "book.closed")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(state.resultCountLabel) {
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
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .task {
            await loadCatalog()
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
        HStack(spacing: 12) {
            RecipeCoverImage(url: row.coverImageURL)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.charcoal)

                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(row.chefLine)
                    if let servingsLabel = row.servingsLabel {
                        Text(servingsLabel)
                    }
                    if let coverProvenanceLabel = row.coverProvenanceLabel {
                        Text(coverProvenanceLabel)
                    }
                }
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
