import SpoonjoyCore
import SwiftUI

struct ProfileRouteView: View {
    let identifier: String
    let viewModel: ProfileChefGraphSurfaceViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var profile: ProfileViewModel?
    @State private var errorMessage: String?
    @Environment(\.moderation) private var moderation

    var body: some View {
        Group {
            if let profile {
                ProfileView(viewModel: profile, openRoute: openRoute, onDismissOfflineIndicator: onDismissOfflineIndicator)
            } else if let chef = moderation.ledger.blockedChefs.first(where: { $0.id == identifier || $0.username == identifier }) {
                // The server stops returning a blocked chef's kitchen.
                ModerationHiddenView(message: "You blocked \(chef.name), so their kitchen is hidden.", unblockChef: chef)
            } else if let errorMessage {
                KitchenTableRouteErrorView(message: errorMessage, systemImage: "person.crop.circle")
            } else {
                KitchenTableLoadingStateView(title: "Loading profile", subtitle: "Opening this kitchen.", systemImage: "person.crop.circle")
            }
        }
        .task(id: identifier) {
            await loadProfile()
        }
    }

    @MainActor private func loadProfile() async {
        do {
            try await viewModel.loadProfile(identifier: identifier)
            profile = viewModel.profile
            errorMessage = nil
        } catch {
            if profile == nil {
                errorMessage = "We couldn't load this profile."
            }
        }
    }
}

struct ProfileView: View {
    let viewModel: ProfileViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void
    @Environment(\.moderation) private var moderation
    @Environment(\.dismiss) private var dismiss
    @State private var moderationPrompt: ModerationPrompt?

    var body: some View {
        Group {
            if let hiddenMessage {
                ModerationHiddenView(message: hiddenMessage, unblockChef: moderation.ledger.blockedChefs.first { $0.id == viewModel.header.id })
            } else {
                KitchenTablePage {
                    ProfileHero(viewModel: viewModel, openRoute: openRoute, moderationChef: moderationChef, moderationPrompt: $moderationPrompt)
                    statusBanner
                    if isEmptyKitchen {
                        KitchenTableEmptyTile(
                            systemImage: "fork.knife",
                            title: "Nothing on the shelf yet",
                            message: "Recipes, cookbooks and cooks from this kitchen will gather here."
                        ) {
                            Button {
                                openRoute(.everyoneRecipes)
                            } label: {
                                Label("Browse everyone's recipes", systemImage: "fork.knife")
                            }
                            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                            .accessibilityIdentifier("profile.empty.browse")
                        }
                    } else {
                        // What this kitchen cooked leads; its recipes and cookbooks follow. Empty shelves stay out.
                        RecentSpoonsSection(spoons: viewModel.recentSpoons, openRoute: openRoute)
                        ProfileRecipeShelf(recipes: viewModel.recipes, openRoute: openRoute)
                        ProfileCookbookShelf(cookbooks: viewModel.cookbooks, openRoute: openRoute)
                    }
                }
            }
        }
        .moderationPrompts($moderationPrompt) { dismiss() }
    }

    /// Someone else's kitchen, once signed in, offers Report and Block (App Review guideline 1.2).
    private var moderationChef: BlockedChef? {
        guard let accountID = moderation.accountID, !viewModel.ownerActions.isVisible, viewModel.header.id != accountID else {
            return nil
        }
        return BlockedChef(id: viewModel.header.id, username: viewModel.header.username)
    }

    private var hiddenMessage: String? {
        if moderation.ledger.isBlocked(chefID: viewModel.header.id) {
            return "You blocked @\(viewModel.header.username), so their kitchen is hidden."
        }
        if moderation.ledger.isHidden(ContentReportTarget(type: .chef, id: viewModel.header.id)) {
            return "You reported @\(viewModel.header.username), so their kitchen is hidden for you."
        }
        return nil
    }

    @ViewBuilder private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.offlineIndicator.display != .synced {
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
            }
            if let conflictBanner = viewModel.conflictBanner {
                Label(conflictBanner.message, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
                    .accessibilityHint(conflictBanner.actionTitle)
            }
        }
    }

    private var isEmptyKitchen: Bool {
        viewModel.recipes.isEmpty && viewModel.cookbooks.isEmpty && viewModel.recentSpoons.isEmpty
    }
}

private struct ProfileHero: View {
    let viewModel: ProfileViewModel
    let openRoute: (AppRoute) -> Void
    let moderationChef: BlockedChef?
    @Binding var moderationPrompt: ModerationPrompt?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProfileAvatar(url: viewModel.header.photoURL, name: viewModel.header.username)

            KitchenTableHeader(
                title: "@\(viewModel.header.username)",
                subtitle: viewModel.header.joinedLabel
            ) {
                ownerActions
            }

            ProfileFigures(
                recipeCount: viewModel.recipes.count,
                fellowChefs: graphLink(.fellowChefs),
                kitchenVisitors: graphLink(.kitchenVisitors),
                openRoute: openRoute
            )
        }
    }

    @ViewBuilder private var ownerActions: some View {
        if viewModel.ownerActions.isVisible, let editRoute = viewModel.ownerActions.editProfileRoute {
            Button {
                openRoute(editRoute)
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        }
        if let moderationChef {
            Menu {
                ModerationMenuItems(
                    reportTarget: ContentReportTarget(type: .chef, id: moderationChef.id),
                    reportSubject: moderationChef.name,
                    chef: moderationChef,
                    prompt: $moderationPrompt
                )
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            .accessibilityLabel("More for \(moderationChef.name)")
            .accessibilityIdentifier("profile.moderationMenu")
        }
    }

    private func graphLink(_ direction: ProfileGraphDirection) -> ProfileSurfaceGraphLink? {
        viewModel.graphLinks.first { $0.direction == direction }
    }
}

/// The kitchen at a glance: three numbers in the serif, each with its label under it. The chef counts open their
/// lists; nothing else on the page repeats them.
private struct ProfileFigures: View {
    let recipeCount: Int
    let fellowChefs: ProfileSurfaceGraphLink?
    let kitchenVisitors: ProfileSurfaceGraphLink?
    let openRoute: (AppRoute) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 28))
        layout {
            ProfileFigure(count: recipeCount, label: recipeCount == 1 ? "recipe" : "recipes")
            FellowChefsSection(link: fellowChefs, openRoute: openRoute)
            KitchenVisitorsSection(link: kitchenVisitors, openRoute: openRoute)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }
}

private struct ProfileFigure: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .font(.system(.title, design: .serif).weight(.bold).monospacedDigit())
                .foregroundStyle(KitchenTableTheme.ink)
            Text(label)
                .font(KitchenTableTheme.meta)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileAvatar: View {
    let url: URL?
    let name: String

    var body: some View {
        Group {
            if let url {
                RecipeCoverImage(url: url)
            } else {
                RecipeInitialTile(title: name)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

private struct ProfileRecipeShelf: View {
    let recipes: [ProfileRecipeSummary]
    let openRoute: (AppRoute) -> Void
    @Environment(\.recipeZoomNamespace) private var tabRecipeTransition
    @Namespace private var localRecipeTransition

    var body: some View {
        if !recipes.isEmpty {
            KitchenTableSection(title: "Recipes") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(recipes, id: \.id) { recipe in
                        if recipe.id != recipes.first?.id {
                            RecipeIndexRowSeparator()
                        }
                        RecipeIndexRow(
                            id: recipe.id,
                            title: recipe.title,
                            detail: recipeSubtitle(recipe),
                            coverURL: recipe.coverImageURL,
                            shareURL: recipe.canonicalURL,
                            namespace: tabRecipeTransition ?? localRecipeTransition
                        ) {
                            openRoute(recipe.openRoute)
                        }
                    }
                }
            }
        }
    }

    private func recipeSubtitle(_ recipe: ProfileRecipeSummary) -> String? {
        [recipe.description, recipe.servings]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct ProfileCookbookShelf: View {
    let cookbooks: [ProfileCookbookSummary]
    let openRoute: (AppRoute) -> Void

    var body: some View {
        if !cookbooks.isEmpty {
            KitchenTableSection(title: "Cookbooks") {
                ForEach(cookbooks, id: \.id) { cookbook in
                    Button {
                        openRoute(cookbook.openRoute)
                    } label: {
                        KitchenTableObjectRow(title: cookbook.title, subtitle: cookbook.recipeCountLabel, titleFont: KitchenTableTheme.indexTitle) {
                            RecipeInitialTile(title: cookbook.title)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the cookbook")
                }
            }
        }
    }
}

/// The kitchen's cook log: each cook as the recipe it made, with the note under it.
private struct RecentSpoonsSection: View {
    let spoons: [ProfileRecentSpoon]
    let openRoute: (AppRoute) -> Void
    @Environment(\.recipeZoomNamespace) private var tabRecipeTransition
    @Namespace private var localRecipeTransition

    var body: some View {
        if !spoons.isEmpty {
            KitchenTableSection(title: "Cooked") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(spoons, id: \.id) { spoon in
                        if spoon.id != spoons.first?.id {
                            RecipeIndexRowSeparator()
                        }
                        RecipeIndexRow(
                            id: spoon.recipe.id,
                            title: spoon.recipe.title,
                            detail: spoonLine(spoon),
                            coverURL: spoon.photoURL ?? spoon.coverImageURL,
                            namespace: tabRecipeTransition ?? localRecipeTransition
                        ) {
                            openRoute(spoon.recipe.openRoute)
                        }
                    }
                }
            }
        }
    }

    private func spoonLine(_ spoon: ProfileRecentSpoon) -> String? {
        if let note = spoon.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return note
        }
        return spoon.nextTime.map { "Next time: \($0)" }
    }
}

private struct FellowChefsSection: View {
    let link: ProfileSurfaceGraphLink?
    let openRoute: (AppRoute) -> Void

    var body: some View {
        ProfileGraphLinkSection(
            title: "Fellow chefs",
            systemImage: "person.2",
            link: link,
            openRoute: openRoute
        )
    }
}

private struct KitchenVisitorsSection: View {
    let link: ProfileSurfaceGraphLink?
    let openRoute: (AppRoute) -> Void

    var body: some View {
        ProfileGraphLinkSection(
            title: "Kitchen visitors",
            systemImage: "person.crop.circle.badge.clock",
            link: link,
            openRoute: openRoute
        )
    }
}

/// One chef count as a figure; it opens the list of those chefs, and reads as plain text when there is none.
private struct ProfileGraphLinkSection: View {
    let title: String
    let systemImage: String
    let link: ProfileSurfaceGraphLink?
    let openRoute: (AppRoute) -> Void

    var body: some View {
        if let link {
            Button {
                openRoute(link.route)
            } label: {
                ProfileFigure(count: link.count, label: link.title.lowercased())
                    .frame(minHeight: KitchenTableTheme.minimumTouchTarget, alignment: .topLeading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(link.count) \(link.title)")
            .accessibilityHint("Opens the list")
        } else {
            ProfileFigure(count: 0, label: title.lowercased())
        }
    }
}

struct ProfileGraphRouteView: View {
    let identifier: String
    let direction: ProfileGraphDirection
    let page: Int
    let viewModel: ProfileChefGraphSurfaceViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var graph: ProfileGraphViewModel?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let graph {
                ProfileGraphList(viewModel: graph, openRoute: openRoute, onDismissOfflineIndicator: onDismissOfflineIndicator)
            } else if let errorMessage {
                KitchenTableRouteErrorView(message: errorMessage, systemImage: "person.2")
            } else {
                KitchenTableLoadingStateView(title: "Loading chefs", subtitle: "Opening this kitchen graph.", systemImage: "person.2")
            }
        }
        .task(id: "\(identifier)-\(direction.rawValue)-\(page)") {
            await loadGraph()
        }
    }

    @MainActor private func loadGraph() async {
        do {
            try await viewModel.loadGraph(identifier: identifier, direction: direction, page: page)
            graph = viewModel.graph
            errorMessage = nil
        } catch {
            if graph == nil {
                errorMessage = "We couldn't load these chefs."
            }
        }
    }
}

private struct ProfileGraphList: View {
    let viewModel: ProfileGraphViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    var body: some View {
        List {
            if let emptyState = viewModel.emptyState {
                ContentUnavailableView(
                    emptyState.title,
                    systemImage: emptyState.systemImage,
                    description: Text(emptyState.message)
                )
            } else {
                ForEach(viewModel.rows) { row in
                    Button {
                        openRoute(row.openRoute)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ChefDisplayName.forUsername(row.username))
                                .font(KitchenTableTheme.bodyNote)
                            Text(row.interactionSummary)
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.ink2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.page)
        .overlay(alignment: .bottomLeading) {
            if viewModel.offlineIndicator.display != .synced {
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
                    .padding()
            }
        }
    }
}
