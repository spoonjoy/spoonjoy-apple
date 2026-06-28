import SpoonjoyCore
import SwiftUI

struct ProfileRouteView: View {
    let identifier: String
    let viewModel: ProfileChefGraphSurfaceViewModel
    let openRoute: (AppRoute) -> Void

    @State private var profile: ProfileViewModel?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let profile {
                ProfileView(viewModel: profile, openRoute: openRoute)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "person.crop.circle")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .background(KitchenTableTheme.bone)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KitchenTableTheme.bone)
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
                errorMessage = "Profile unavailable."
            }
        }
    }
}

struct ProfileView: View {
    let viewModel: ProfileViewModel
    let openRoute: (AppRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ProfileHero(viewModel: viewModel, openRoute: openRoute)
                statusBanner
                ProfileRecipeShelf(recipes: viewModel.recipes, openRoute: openRoute)
                ProfileCookbookShelf(cookbooks: viewModel.cookbooks, openRoute: openRoute)
                RecentSpoonsSection(spoons: viewModel.recentSpoons, openRoute: openRoute)
                FellowChefsSection(link: graphLink(.fellowChefs), openRoute: openRoute)
                KitchenVisitorsSection(link: graphLink(.kitchenVisitors), openRoute: openRoute)
            }
            .padding()
        }
        .background(KitchenTableTheme.bone)
    }

    @ViewBuilder private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.offlineIndicator.display != .synced {
                OfflineStatusView(display: viewModel.offlineIndicator.display)
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
        HStack(alignment: .top, spacing: 16) {
            ProfileAvatar(url: viewModel.header.photoURL)
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.header.username)
                    .font(KitchenTableTheme.displayTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text(viewModel.header.joinedLabel)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
                graphSummary
                if viewModel.ownerActions.isVisible, let editRoute = viewModel.ownerActions.editProfileRoute {
                    Button {
                        openRoute(editRoute)
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var graphSummary: some View {
        HStack(spacing: 10) {
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Recipes")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)
            if recipes.isEmpty {
                ContentUnavailableView("No recipes yet", systemImage: "book.closed")
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(recipes, id: \.id) { recipe in
                            Button {
                                openRoute(recipe.openRoute)
                            } label: {
                                ProfileRecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct ProfileRecipeCard: View {
    let recipe: ProfileRecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecipeCoverImage(url: recipe.coverImageURL)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Cookbooks")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)
            if cookbooks.isEmpty {
                ContentUnavailableView("No cookbooks yet", systemImage: "books.vertical")
            } else {
                ForEach(cookbooks, id: \.id) { cookbook in
                    Button {
                        openRoute(cookbook.openRoute)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cookbook.title)
                                .font(KitchenTableTheme.bodyNote)
                            Text(cookbook.recipeCountLabel)
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Spoons")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)
            if spoons.isEmpty {
                ContentUnavailableView("No spoons yet", systemImage: "fork.knife")
            } else {
                ForEach(spoons, id: \.id) { spoon in
                    Button {
                        openRoute(spoon.recipe.openRoute)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(spoon.recipe.title)
                                .font(KitchenTableTheme.bodyNote)
                            if let note = spoon.note {
                                Text(note)
                                    .font(KitchenTableTheme.uiLabel)
                                    .foregroundStyle(.secondary)
                            }
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

    @State private var graph: ProfileGraphViewModel?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let graph {
                ProfileGraphList(viewModel: graph, openRoute: openRoute)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "person.2")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .background(KitchenTableTheme.bone)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KitchenTableTheme.bone)
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
                errorMessage = "Chef graph unavailable."
            }
        }
    }
}

private struct ProfileGraphList: View {
    let viewModel: ProfileGraphViewModel
    let openRoute: (AppRoute) -> Void

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
                                .foregroundStyle(.secondary)
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
                OfflineStatusView(display: viewModel.offlineIndicator.display)
                    .padding()
            }
        }
    }
}
