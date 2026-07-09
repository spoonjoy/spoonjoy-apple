import SpoonjoyCore
import SwiftUI

struct ProfileRouteView: View {
    let identifier: String
    let viewModel: ProfileChefGraphSurfaceViewModel
    let openRoute: (AppRoute) -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var profile: ProfileViewModel?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let profile {
                ProfileView(viewModel: profile, openRoute: openRoute, onDismissOfflineIndicator: onDismissOfflineIndicator)
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
                    Button {
                        openRoute(editRoute)
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                    .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                }
            }
        }
    }

    private var graphSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.graphLinks, id: \.direction) { link in
                Button {
                    openRoute(link.route)
                } label: {
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
                    Button {
                        openRoute(recipe.openRoute)
                    } label: {
                        KitchenTableObjectRow(title: recipe.title, subtitle: recipe.coverProvenanceLabel) {
                            RecipeCoverImage(
                                url: recipe.coverImageURL,
                                title: recipe.title,
                                subtitle: recipe.coverProvenanceLabel
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
}

private struct ProfileRecipeCard: View {
    let recipe: ProfileRecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecipeCoverImage(
                url: recipe.coverImageURL,
                title: recipe.title,
                subtitle: recipe.coverProvenanceLabel
            )
                .frame(width: 132, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
            Text(recipe.title)
                .font(.headline)
                .foregroundStyle(KitchenTableTheme.charcoal)
            if let coverProvenanceLabel = recipe.coverProvenanceLabel {
                Text(coverProvenanceLabel)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
            }
        }
        .frame(width: 144, alignment: .leading)
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
                    Button {
                        openRoute(cookbook.openRoute)
                    } label: {
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
                    Button {
                        openRoute(spoon.recipe.openRoute)
                    } label: {
                        KitchenTableObjectRow(title: spoon.recipe.title, subtitle: spoon.note) {
                            RecipeCoverImage(url: nil, title: spoon.recipe.title, subtitle: "Cook log")
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

private struct ProfileGraphLinkSection: View {
    let title: String
    let systemImage: String
    let link: ProfileSurfaceGraphLink?
    let openRoute: (AppRoute) -> Void

    var body: some View {
        Button {
            if let link {
                openRoute(link.route)
            }
        } label: {
            Label(link.map { "\($0.count) \($0.title)" } ?? title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .disabled(link == nil)
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
                            Text(row.username)
                                .font(KitchenTableTheme.bodyNote)
                            Text(row.interactionSummary)
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.inkMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .overlay(alignment: .bottomLeading) {
            if viewModel.offlineIndicator.display != .synced {
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
                    .padding()
            }
        }
    }
}
