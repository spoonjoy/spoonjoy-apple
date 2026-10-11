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
    @State private var state: RecipeCatalogState
    @State private var query: String
    @State private var isLoading = false

    init(
        viewModel: RecipeCatalogViewModel,
        openRoute: @escaping (AppRoute) -> Void,
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
        self.openRoute = openRoute
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
            } else if let emptyState = state.resolvedEmptyState(overridingDefaultWith: emptyStateOverride) {
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
                .accessibilityIdentifier("recipes.row")
            }
        }
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
            emptyStateOverride: RecipeCatalogEmptyState.noSavedRecipes
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
                eyebrow: "My Kitchen",
                title: "Chefs",
                subtitle: resolved.subtitle
            )

            fellowChefsSection(resolved)

            if case .live = resolved {
                chefsUsingMyRecipesSection(resolved)
                activitySection(resolved)
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
            emptySection(
                title: "No fellow chefs yet",
                message: "Cook, save, or fork another chef's recipe to start building your kitchen."
            )
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
        if resolved.chefsUsingMyRecipes.isEmpty {
            emptySection(title: "Chefs Using My Recipes", message: "No one has used your recipes yet.")
        } else {
            KitchenTableSection(title: "Chefs Using My Recipes") {
                ForEach(resolved.chefsUsingMyRecipes) { row in
                    chefRow(
                        chef: NativeChefRef(id: row.chefID, username: row.username, photoURL: row.photoURL),
                        subtitle: row.interactionSummary
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func activitySection(_ resolved: ChefsSurfaceContent) -> some View {
        if resolved.activity.isEmpty {
            emptySection(
                title: "No chef activity yet",
                message: "Cook, fork, or save another chef's recipe to start building your kitchen graph."
            )
        } else {
            KitchenTableSection(title: "Activity") {
                ForEach(resolved.activity) { row in
                    Button {
                        openRoute(row.recipeRoute ?? row.otherChef.profileRoute)
                    } label: {
                        KitchenTableObjectRow(title: row.label, subtitle: row.directionLabel) {
                            Image(systemName: "text.bubble")
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
                    .accessibilityIdentifier("chefs.activity.row")
                }
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
        .accessibilityHint("Opens chef profile")
    }

    private func emptySection(title: String, message: String) -> some View {
        KitchenTableSection(title: title) {
            Text(message)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .background(KitchenTableTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
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
                leadCover

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
        .accessibilityHint("Opens recipe detail")
        .accessibilityIdentifier("recipes.row")
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
        } else {
            RecipeCoverImage(
                url: nil,
                title: row.title,
                subtitle: "Photo not added",
                showsFallbackLabel: true
            )
            .frame(maxWidth: .infinity, minHeight: 126, maxHeight: 126)
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
    /// The pixel size a 56-point row thumbnail decodes at on a 3x screen. A 2x screen decodes smaller,
    /// and both download the same stored variant.
    static let rowThumbnailPixelSize = ImageDownsampleBucket.pixelSize(points: 56, scale: 3)

    /// Downloads the first rows' covers, at the size the rows show them, into the disk cache so they open
    /// without waiting on the network.
    static func prefetch(_ urls: [URL]) async {
        var seen = Set<URL>()
        let uniqueURLs = urls.filter { seen.insert($0).inserted }.prefix(12)
        AppImagePipeline.shared.prefetch(Array(uniqueURLs), maxPixelSize: rowThumbnailPixelSize)
    }
}
