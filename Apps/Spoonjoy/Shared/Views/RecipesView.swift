import SpoonjoyCore
import Foundation
import SwiftUI

struct RecipesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let viewModel: RecipeCatalogViewModel
    let openRoute: (AppRoute) -> Void
    private let headerEyebrow: String
    private let title: String
    private let searchPrompt: String
    private let loadingTitle: String
    private let loadingSubtitle: String
    private let proofRoute: String
    private let proofSource: String
    private let emptyStateOverride: RecipeCatalogEmptyState?
    /// The empty list's one way in: Add a recipe for your own kitchen, Open cookbooks for the saved list.
    private let emptyAction: RecipesEmptyAction?
    /// Replaces the result count under the title when the list is not the whole set, like Everyone's most recent.
    private let subtitleOverride: String?
    @State private var state: RecipeCatalogState
    @State private var query: String
    @State private var isLoading = false
    /// The tab stack's cover-zoom namespace, so a tapped cover grows into its recipe; its own outside a tab stack.
    @Environment(\.recipeZoomNamespace) private var tabRecipeTransition
    @Namespace private var localRecipeTransition

    init(
        viewModel: RecipeCatalogViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        headerEyebrow: String = "",
        title: String = "My Recipes",
        searchPrompt: String = "Search my recipes",
        loadingTitle: String = "Loading recipes",
        loadingSubtitle: String = "Opening your recipe index.",
        proofRoute: String = "recipes",
        proofSource: String = "RecipesView",
        emptyStateOverride: RecipeCatalogEmptyState? = nil,
        emptyAction: RecipesEmptyAction? = nil,
        subtitleOverride: String? = nil
    ) {
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.headerEyebrow = headerEyebrow
        self.title = title
        self.searchPrompt = searchPrompt
        self.loadingTitle = loadingTitle
        self.loadingSubtitle = loadingSubtitle
        self.proofRoute = proofRoute
        self.proofSource = proofSource
        self.emptyStateOverride = emptyStateOverride
        self.emptyAction = emptyAction
        self.subtitleOverride = subtitleOverride
        _state = State(initialValue: viewModel.state)
        _query = State(initialValue: viewModel.state.query)
    }

    private var recipeTransition: Namespace.ID {
        tabRecipeTransition ?? localRecipeTransition
    }

    var body: some View {
        KitchenTablePage {
            KitchenTableHeader(
                eyebrow: headerEyebrow,
                title: title,
                subtitle: subtitleOverride ?? state.resultCountLabel,
                hidesTitleInCompactNavigation: true
            )

            if isLoading, state.rows.isEmpty {
                KitchenTableLoadingStateView(title: loadingTitle, subtitle: loadingSubtitle, systemImage: "book.closed")
            } else if let emptyState = state.resolvedEmptyState(overridingDefaultWith: emptyStateOverride) {
                recipesEmptyState(emptyState)
            } else {
                // The Kitchen already leads with a recipe, so the index starts at the first row instead of
                // repeating that hero.
                recipeIndex(rows: state.rows)
            }
        }
        .reloadsOnPull { await loadCatalog(query: query) }
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
        KitchenTableEmptyTile(
            systemImage: emptyState.systemImage,
            title: emptyState.title,
            message: emptyState.message
        ) {
            if emptyState == .noMatches {
                Button {
                    query = ""
                    Task { await loadCatalog(query: "") }
                } label: {
                    Label("Clear search", systemImage: "xmark.circle")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                .accessibilityIdentifier("recipes.empty.clearSearch")
            } else if let emptyAction {
                Button(action: emptyAction.perform) {
                    Label(emptyAction.title, systemImage: emptyAction.systemImage)
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
                .accessibilityIdentifier("recipes.empty.action")
            }
        }
        .accessibilityIdentifier("recipes.emptyState")
    }

    private func recipeIndex(rows: [RecipeCatalogRowViewModel]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                if row.id != rows.first?.id {
                    RecipeIndexRowSeparator()
                }
                RecipeIndexRow(row: row, namespace: recipeTransition) {
                    openRoute(row.openRoute)
                }
                .accessibilityIdentifier("recipes.row")
            }
        }
    }
}

/// The one action an empty recipe list offers.
struct RecipesEmptyAction {
    let title: String
    let systemImage: String
    let perform: () -> Void
}

/// Every public recipe, the same list the website's Recipes page shows, searched on the server.
struct EveryoneRecipesView: View {
    let viewModel: RecipeCatalogViewModel
    let openRoute: (AppRoute) -> Void

    var body: some View {
        RecipesView(
            viewModel: viewModel,
            openRoute: openRoute,
            title: "Everyone's Recipes",
            searchPrompt: "Search every recipe",
            loadingTitle: "Loading recipes",
            loadingSubtitle: "Opening every kitchen's recipes.",
            proofRoute: "everyone-recipes",
            proofSource: "EveryoneRecipesView",
            // The server returns its most recent recipes, not every recipe, so no total is claimed.
            subtitleOverride: "Recent recipes from every kitchen"
        )
    }
}

struct SavedRecipesView: View {
    let viewModel: RecipeCatalogViewModel
    let openRoute: (AppRoute) -> Void

    var body: some View {
        RecipesView(
            viewModel: viewModel,
            openRoute: openRoute,
            title: "Saved Recipes",
            searchPrompt: "Search saved recipes",
            loadingTitle: "Loading saved recipes",
            loadingSubtitle: "Opening the recipes saved in your cookbooks.",
            proofRoute: "saved-recipes",
            proofSource: "SavedRecipesView",
            emptyStateOverride: RecipeCatalogEmptyState.noSavedRecipes,
            emptyAction: RecipesEmptyAction(title: "Open cookbooks", systemImage: "books.vertical") {
                openRoute(.cookbooks)
            }
        )
    }
}

struct ChefsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let repository: (any ChefsSurfaceRepository)?
    let fallbackChefs: [NativeChefRef]
    let openRoute: (AppRoute) -> Void

    @State private var content: ChefsSurfaceContent?

    var body: some View {
        let resolved = content ?? .cachedFallback(fallbackChefs)
        KitchenTablePage {
            KitchenTableHeader(
                title: "Chefs",
                subtitle: resolved.subtitle
            )

            fellowChefsSection(resolved)

            // An empty kitchen graph says so once, above; the sections below appear when they have someone in them.
            if case .live = resolved {
                if !resolved.chefsUsingMyRecipes.isEmpty {
                    chefsUsingMyRecipesSection(resolved)
                }
                if !resolved.activity.isEmpty {
                    activitySection(resolved)
                }
            }
        }
        .task(id: fallbackChefs.map(\.id)) {
            content = await ChefsSurfaceContent.load(repository: repository, fallbackChefs: fallbackChefs)
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

    @ViewBuilder
    private func fellowChefsSection(_ resolved: ChefsSurfaceContent) -> some View {
        if resolved.fellowChefs.isEmpty {
            KitchenTableEmptyTile(
                systemImage: "person.2",
                title: "No fellow chefs yet",
                message: "Cook, save, or fork another chef's recipe to start building your kitchen."
            ) {
                Button {
                    openRoute(.everyoneRecipes)
                } label: {
                    Label("Browse everyone's recipes", systemImage: "fork.knife")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                .accessibilityIdentifier("chefs.empty.browse")
            }
        } else {
            KitchenTableSection(title: "Fellow Chefs") {
                ForEach(resolved.fellowChefs, id: \.id) { chef in
                    chefRow(
                        chef: chef,
                        subtitle: resolved.fellowChefRows.first(where: { $0.chefID == chef.id })?.interactionSummary
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func chefsUsingMyRecipesSection(_ resolved: ChefsSurfaceContent) -> some View {
        KitchenTableSection(title: "Chefs Using My Recipes") {
            ForEach(resolved.chefsUsingMyRecipes) { row in
                chefRow(
                    chef: NativeChefRef(id: row.chefID, username: row.username, photoURL: row.photoURL),
                    subtitle: row.interactionSummary
                )
            }
        }
    }

    @ViewBuilder
    private func activitySection(_ resolved: ChefsSurfaceContent) -> some View {
        KitchenTableSection(title: "Activity") {
            ForEach(resolved.activity) { row in
                Button {
                    openRoute(row.recipeRoute ?? row.otherChef.profileRoute)
                } label: {
                    KitchenTableObjectRow(title: row.label, subtitle: row.directionLabel) {
                        ChefAvatar(url: row.otherChef.photoURL, name: row.otherChef.displayName)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chefs.activity.row")
            }
        }
    }

    private func chefRow(chef: NativeChefRef, subtitle: String?) -> some View {
        Button {
            openRoute(chef.profileRoute)
        } label: {
            KitchenTableObjectRow(
                title: chef.displayName,
                subtitle: (subtitle?.isEmpty == false ? subtitle : nil) ?? "Open kitchen profile"
            ) {
                ChefAvatar(url: chef.photoURL, name: chef.displayName)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens chef profile")
    }

}

/// A chef's photo in a circle, or their initial on a vellum tile when they have none.
struct ChefAvatar: View {
    let url: URL?
    let name: String

    var body: some View {
        Group {
            if let url {
                RecipeCoverImage(url: url, title: name, subtitle: nil, showsFallbackLabel: false)
                    .scaledToFill()
            } else {
                RecipeInitialTile(title: name)
            }
        }
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(KitchenTableTheme.hairline, lineWidth: 0.5)
        }
        .accessibilityHidden(true)
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

private enum RecipeCoverPrefetcher {
    /// The pixel size a 64-point row thumbnail decodes at on a 3x screen. A 2x screen decodes smaller,
    /// and both download the same stored variant.
    static let rowThumbnailPixelSize = ImageDownsampleBucket.pixelSize(points: 64, scale: 3)

    /// Downloads the first rows' covers, at the size the rows show them, into the disk cache so they open
    /// without waiting on the network.
    static func prefetch(_ urls: [URL]) async {
        var seen = Set<URL>()
        let uniqueURLs = urls.filter { seen.insert($0).inserted }.prefix(12)
        AppImagePipeline.shared.prefetch(Array(uniqueURLs), maxPixelSize: rowThumbnailPixelSize)
    }
}
