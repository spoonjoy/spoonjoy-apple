import SpoonjoyCore
import SwiftUI

struct ProfileRouteView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let identifier: String
    let viewModel: ProfileChefGraphSurfaceViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var profile: ProfileViewModel?
    @State private var errorMessage: String?

    init(
        identifier: String,
        viewModel: ProfileChefGraphSurfaceViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void
    ) {
        self.identifier = identifier
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _profile = State(initialValue: viewModel.profile.map { profile in
            profile.header.id == identifier || profile.header.username == identifier ? profile : nil
        } ?? nil)
    }

    var body: some View {
        Group {
            if let profile {
                ProfileView(viewModel: profile, openRoute: openRoute, onDismissOfflineIndicator: onDismissOfflineIndicator)
                    .transition(.opacity)
            } else if let errorMessage {
                KitchenTableRouteErrorView(message: errorMessage, systemImage: "person.crop.circle")
                    .transition(.opacity)
            } else {
                KitchenTableLoadingStateView(title: "Loading profile", subtitle: "Opening this kitchen.", systemImage: "person.crop.circle")
                    .transition(.opacity)
            }
        }
        .task(id: identifier) {
            await loadProfile()
        }
    }

    @MainActor private func loadProfile() async {
        do {
            try await viewModel.loadProfile(identifier: identifier)
            withAnimation(contentAnimation) {
                profile = viewModel.profile
                errorMessage = nil
            }
        } catch {
            if profile == nil {
                withAnimation(contentAnimation) {
                    errorMessage = "We couldn't load this profile."
                }
            }
        }
    }

    private var contentAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

struct ProfileView: View {
    let viewModel: ProfileViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        KitchenTablePage {
            ProfileHero(viewModel: viewModel, openRoute: openRoute)
            statusBanner
            ProfileRecipeShelf(recipes: viewModel.recipes, openRoute: openRoute)
            ProfileCookbookShelf(cookbooks: viewModel.cookbooks, openRoute: openRoute)
            RecentSpoonsSection(spoons: viewModel.recentSpoons, openRoute: openRoute)
            FellowChefsSection(link: graphLink(.fellowChefs), openRoute: openRoute)
            KitchenVisitorsSection(link: graphLink(.kitchenVisitors), openRoute: openRoute)
        }
        .accessibilityIdentifier("profile.scroll")
        .task(id: viewModel.header.username) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "profile",
                source: "ProfileView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
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

    private func graphLink(_ direction: ProfileGraphDirection) -> ProfileSurfaceGraphLink? {
        viewModel.graphLinks.first { $0.direction == direction }
    }
}

private struct ProfileHero: View {
    let viewModel: ProfileViewModel
    let openRoute: (AppRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProfileAvatar(url: viewModel.header.photoURL)

            KitchenTableHeader(
                eyebrow: "Chef",
                title: "@\(viewModel.header.username)",
                subtitle: viewModel.header.joinedLabel
            ) {
                graphSummary
                if viewModel.ownerActions.isVisible, let editRoute = viewModel.ownerActions.editProfileRoute {
                    NavigationLink(value: editRoute) {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                    .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                }
            }
        }
        .accessibilityIdentifier("profile.header")
    }

    private var graphSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.graphLinks, id: \.direction) { link in
                NavigationLink(value: link.route) {
                    Label("\(link.count) \(link.title)", systemImage: link.direction == .fellowChefs ? "person.2" : "person.crop.circle.badge.clock")
                }
                .font(KitchenTableTheme.uiLabel)
            }
        }
    }
}

private struct ProfileAvatar: View {
    let url: URL?

    var body: some View {
        ZStack {
            Circle()
                .fill(KitchenTableTheme.brass.opacity(0.18))
            if let url {
                RecipeCoverImage(url: url)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 54))
                    .foregroundStyle(KitchenTableTheme.brass)
            }
        }
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }
}

private struct ProfileRecipeShelf: View {
    let recipes: [ProfileRecipeSummary]
    let openRoute: (AppRoute) -> Void

    var body: some View {
        KitchenTableSection(title: "Recipes") {
            if recipes.isEmpty {
                KitchenEmptySection(title: "No recipes yet", systemImage: "book.closed", tint: KitchenTableTheme.brass)
            } else {
                ForEach(recipes, id: \.id) { recipe in
                    NavigationLink(value: recipe.openRoute) {
                        KitchenTableObjectRow(
                            title: recipe.title,
                            subtitle: recipeSubtitle(recipe),
                            showsLeading: recipe.coverImageURL != nil
                        ) {
                            RecipeCoverImage(
                                url: recipe.coverImageURL,
                                title: recipe.title,
                                subtitle: "Photo not added"
                            )
                        } trailing: {
                            Image(systemName: "chevron.forward")
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.brass)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens recipe detail")
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

private struct ProfileRecipeCard: View {
    let recipe: ProfileRecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let coverImageURL = recipe.coverImageURL {
                RecipeCoverImage(
                    url: coverImageURL,
                    title: recipe.title,
                    subtitle: nil,
                    showsFallbackLabel: false
                )
                .frame(width: 132, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
            }
            Text(recipe.title)
                .font(.headline)
                .foregroundStyle(KitchenTableTheme.charcoal)
            if let subtitle = recipeSubtitle {
                Text(subtitle)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
        }
        .frame(width: 144, alignment: .leading)
    }

    private var recipeSubtitle: String? {
        [recipe.description, recipe.servings]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct ProfileCookbookShelf: View {
    let cookbooks: [ProfileCookbookSummary]
    let openRoute: (AppRoute) -> Void

    var body: some View {
        KitchenTableSection(title: "Cookbooks") {
            if cookbooks.isEmpty {
                KitchenEmptySection(title: "No cookbooks yet", systemImage: "books.vertical", tint: KitchenTableTheme.brass)
            } else {
                ForEach(cookbooks, id: \.id) { cookbook in
                    NavigationLink(value: cookbook.openRoute) {
                        KitchenTableObjectRow(title: cookbook.title, subtitle: cookbook.recipeCountLabel) {
                            ZStack {
                                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                                    .fill(KitchenTableTheme.brass.opacity(0.16))
                                Image(systemName: "books.vertical")
                                    .foregroundStyle(KitchenTableTheme.brass)
                            }
                        } trailing: {
                            Image(systemName: "chevron.forward")
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.brass)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RecentSpoonsSection: View {
    let spoons: [ProfileRecentSpoon]
    let openRoute: (AppRoute) -> Void

    var body: some View {
        KitchenTableSection(title: "Recent Spoons") {
            if spoons.isEmpty {
                KitchenEmptySection(title: "No spoons yet", systemImage: "fork.knife", tint: KitchenTableTheme.brass)
            } else {
                ForEach(spoons, id: \.id) { spoon in
                    NavigationLink(value: spoon.recipe.openRoute) {
                        KitchenTableObjectRow(
                            title: spoon.recipe.title,
                            subtitle: spoon.note,
                            showsLeading: false
                        ) {
                            EmptyView()
                        } trailing: {
                            Image(systemName: "fork.knife")
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.brass)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        .accessibilityIdentifier("profile.graph.fellow-chefs")
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
        .accessibilityIdentifier("profile.graph.kitchen-visitors")
    }
}

private struct ProfileGraphLinkSection: View {
    let title: String
    let systemImage: String
    let link: ProfileSurfaceGraphLink?
    let openRoute: (AppRoute) -> Void

    var body: some View {
        Group {
            if let link {
                NavigationLink(value: link.route) {
                    Label("\(link.count) \(link.title)", systemImage: systemImage)
                }
            } else {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
    }
}

struct ProfileGraphRouteView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let identifier: String
    let direction: ProfileGraphDirection
    let page: Int
    let viewModel: ProfileChefGraphSurfaceViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var graph: ProfileGraphViewModel?
    @State private var errorMessage: String?

    init(
        identifier: String,
        direction: ProfileGraphDirection,
        page: Int,
        viewModel: ProfileChefGraphSurfaceViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void
    ) {
        self.identifier = identifier
        self.direction = direction
        self.page = page
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _graph = State(initialValue: viewModel.graph.flatMap { graph in
            let matchesIdentifier = graph.page.profile.id == identifier || graph.page.profile.username == identifier
            return matchesIdentifier && graph.page.direction == direction && graph.page.page == page ? graph : nil
        })
    }

    var body: some View {
        Group {
            if let graph {
                ProfileGraphList(viewModel: graph, openRoute: openRoute, onDismissOfflineIndicator: onDismissOfflineIndicator)
                    .transition(.opacity)
            } else if let errorMessage {
                KitchenTableRouteErrorView(message: errorMessage, systemImage: "person.2")
                    .transition(.opacity)
            } else {
                KitchenTableLoadingStateView(title: "Loading chefs", subtitle: "Opening this kitchen graph.", systemImage: "person.2")
                    .transition(.opacity)
            }
        }
        .task(id: "\(identifier)-\(direction.rawValue)-\(page)") {
            await loadGraph()
        }
    }

    @MainActor private func loadGraph() async {
        do {
            try await viewModel.loadGraph(identifier: identifier, direction: direction, page: page)
            withAnimation(contentAnimation) {
                graph = viewModel.graph
                errorMessage = nil
            }
        } catch {
            if graph == nil {
                withAnimation(contentAnimation) {
                    errorMessage = "We couldn't load these chefs."
                }
            }
        }
    }

    private var contentAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

private struct ProfileGraphList: View {
    let viewModel: ProfileGraphViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

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
                    NavigationLink(value: row.openRoute) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.username)
                                .font(KitchenTableTheme.bodyNote)
                            Text(row.interactionSummary)
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.inkMuted)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile-graph.row.\(row.id)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.offlineIndicator.display != .synced {
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KitchenTableTheme.paper)
            }
        }
        .task(id: viewModel.title) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "profile-graph",
                source: "ProfileGraphList",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
    }
}
