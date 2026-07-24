import SpoonjoyCore
import Foundation
import SwiftUI

struct RecipesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let viewModel: RecipeCatalogViewModel
    private let headerEyebrow: String
    private let title: String
    private let searchPrompt: String
    private let loadingTitle: String
    private let loadingSubtitle: String
    private let proofRoute: String
    private let proofSource: String
    private let emptyStateOverride: RecipeCatalogEmptyState?
    @State private var state: RecipeCatalogState
    @State private var query: String
    @State private var isLoading: Bool

    init(
        viewModel: RecipeCatalogViewModel,
        headerEyebrow: String = "My Kitchen",
        title: String = "My Recipes",
        searchPrompt: String = "Search my recipes",
        loadingTitle: String = "Loading recipes",
        loadingSubtitle: String = "Opening your recipe index.",
        proofRoute: String = "recipes",
        proofSource: String = "RecipesView",
        emptyStateOverride: RecipeCatalogEmptyState? = nil
    ) {
        self.viewModel = viewModel
        self.headerEyebrow = headerEyebrow
        self.title = title
        self.searchPrompt = searchPrompt
        self.loadingTitle = loadingTitle
        self.loadingSubtitle = loadingSubtitle
        self.proofRoute = proofRoute
        self.proofSource = proofSource
        self.emptyStateOverride = emptyStateOverride
        _state = State(initialValue: viewModel.state)
        _query = State(initialValue: viewModel.state.query)
        _isLoading = State(initialValue: viewModel.state.rows.isEmpty)
    }

    var body: some View {
        KitchenTablePage {
            KitchenTableHeader(
                eyebrow: headerEyebrow,
                title: title,
                subtitle: state.resultCountLabel,
                hidesTitleInCompactNavigation: true
            )

            if isLoading, state.rows.isEmpty {
                KitchenTableLoadingStateView(title: loadingTitle, subtitle: loadingSubtitle, systemImage: "book.closed")
                    .transition(.opacity)
            } else if let emptyState = state.resolvedEmptyState(overridingDefaultWith: emptyStateOverride) {
                recipesEmptyState(emptyState)
                    .transition(.opacity)
            } else if let leadRow = state.leadRow {
                Group {
                    RecipeCatalogLead(
                        row: leadRow,
                        accessibilityIdentifier: state.indexRows.isEmpty
                            ? "\(proofRoute).terminal"
                            : "recipe.lead.\(leadRow.id)"
                    )
                    if !state.indexRows.isEmpty {
                        recipeIndexSection(rows: state.indexRows)
                    }
                }
                .transition(.opacity)
            } else {
                recipeIndexSection(rows: state.rows)
                    .transition(.opacity)
            }
        }
        .searchable(text: $query, prompt: searchPrompt)
        .onSubmit(of: .search) {
            Task {
                await loadCatalog(query: query)
            }
        }
        .task {
            await loadCatalog(query: query)
            await RecipeCoverPrefetcher.prefetch(state.rows.compactMap(\.coverImageURL))
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: proofRoute,
                source: proofSource,
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
                    .accessibilityIdentifier("\(proofRoute).terminal")
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
                let isTerminal = row.id == rows.last?.id
                NavigationLink(value: row.openRoute) {
                    RecipeIndexRow(row: row)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(isTerminal ? "\(proofRoute).terminal" : "recipe.row.\(row.id)")
                .accessibilityLabel(row.title)
            }
        }
    }
}

struct SavedRecipesView: View {
    let viewModel: RecipeCatalogViewModel

    var body: some View {
        RecipesView(
            viewModel: viewModel,
            title: "Saved Recipes",
            searchPrompt: "Search saved recipes",
            loadingTitle: "Loading saved recipes",
            loadingSubtitle: "Opening the recipes saved in your cookbooks.",
            proofRoute: "saved-recipes",
            proofSource: "SavedRecipesView",
            emptyStateOverride: RecipeCatalogEmptyState.noSavedRecipes
        )
    }
}

struct ChefsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let profiles: [NativeCachedProfile]

    var body: some View {
        KitchenTablePage {
            KitchenTableHeader(
                eyebrow: "My Kitchen",
                title: "Chefs",
                subtitle: "\(profiles.count) \(profiles.count == 1 ? "chef" : "chefs")"
            )

            if profiles.isEmpty {
                KitchenTableSection(title: "No fellow chefs yet") {
                    Text("Cook, save, or fork another chef's recipe to start building your kitchen.")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .background(KitchenTableTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
                        .accessibilityIdentifier("chefs.terminal")
                }
            } else {
                KitchenTableSection(title: "Fellow Chefs") {
                    ForEach(profiles.map(\.profile), id: \.id) { profile in
                        let isTerminal = profile.id == profiles.last?.profile.id
                        NavigationLink(value: AppRoute.profile(identifier: profile.username)) {
                            KitchenTableObjectRow(title: profile.username, subtitle: "Open kitchen profile") {
                                Image(systemName: "person.crop.circle")
                                    .font(.title2)
                                    .foregroundStyle(KitchenTableTheme.brass)
                                    .frame(width: 44, height: 44)
                                    .background(KitchenTableTheme.paper)
                            } trailing: {
                                Image(systemName: "chevron.forward")
                                    .font(KitchenTableTheme.uiLabel)
                                    .foregroundStyle(KitchenTableTheme.brass)
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(isTerminal ? "chefs.terminal" : "chefs.row.\(profile.id)")
                        .accessibilityLabel("\(profile.username), Open kitchen profile")
                        .accessibilityHint("Opens chef profile")
                    }
                }
            }
        }
        .task {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "chefs",
                source: "ChefsView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
    }
}

private struct RecipeCatalogLead: View {
    let row: RecipeCatalogRowViewModel
    let accessibilityIdentifier: String

    var body: some View {
        NavigationLink(value: row.openRoute) {
            VStack(alignment: .leading, spacing: 10) {
                if row.coverImageURL != nil {
                    leadCover
                }

                Text("On the Counter".uppercased())
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
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(row.title)
        .accessibilityHint("Opens recipe detail")
    }

    @ViewBuilder private var leadCover: some View {
        if let coverImageURL = row.coverImageURL {
            RecipeCoverImage(
                url: coverImageURL,
                title: row.title,
                subtitle: nil,
                showsFallbackLabel: false
            )
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220)
            .clipped()
        }
    }

    private var leadSubtitle: String {
        [
            row.subtitle,
            row.chefLine,
            row.servingsLabel
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

extension RecipesView {
    @MainActor private func loadCatalog(query: String) async {
        isLoading = true
        do {
            try await viewModel.load(query: query, limit: state.limit)
            withAnimation(contentAnimation) {
                state = viewModel.state
                self.query = viewModel.state.query
                isLoading = false
            }
        } catch {
            withAnimation(contentAnimation) {
                self.query = viewModel.state.query
                isLoading = false
            }
        }
    }

    private var contentAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

private struct RecipeIndexRow: View {
    let row: RecipeCatalogRowViewModel

    init(row: RecipeCatalogRowViewModel) {
        self.row = row
    }

    var body: some View {
        KitchenTableObjectRow(
            title: row.title,
            subtitle: rowSubtitle,
            showsLeading: row.coverImageURL != nil
        ) {
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
        .joined(separator: "\n")
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
