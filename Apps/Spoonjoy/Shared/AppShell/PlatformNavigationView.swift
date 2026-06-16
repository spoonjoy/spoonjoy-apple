import SpoonjoyCore
import SwiftUI

struct PlatformNavigationView: View {
    @Binding var navigation: AppNavigationState
    @Binding var search: SearchState
    private let recipes: [Recipe]
    private let cookbooks: [Cookbook]
    private let kitchen: KitchenFixtureState

    init(navigation: Binding<AppNavigationState>, search: Binding<SearchState>) {
        _navigation = navigation
        _search = search
        recipes = (try? RecipeFixtureCatalog.decodeFromBundle().recipes) ?? []
        cookbooks = (try? CookbookFixtureCatalog.decodeFromBundle().cookbooks) ?? []
        kitchen = (try? KitchenFixtureState.decodeFromBundle()) ?? KitchenFixtureState.bootstrapFallback
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Spoonjoy")
        } detail: {
            NavigationStack {
                detailContent
                    .navigationTitle(title(for: navigation.route))
#if os(iOS)
                    .navigationBarTitleDisplayMode(.large)
#endif
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationContent(for: route)
            }
            .searchable(text: searchText, prompt: "Search Spoonjoy")
            .searchScopes(searchScope) {
                ForEach(SearchScope.allCases, id: \.rawValue) { scope in
                    Text(label(for: scope)).tag(scope)
                }
            }
            .onSubmit(of: .search) {
                navigation.navigate(to: search.route)
            }
            .spoonjoyToolbar(navigation: $navigation, search: $search)
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
#endif
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            sidebarLink(section: .kitchen, title: "Kitchen", systemImage: "house")
            sidebarLink(section: .recipes, title: "Recipes", systemImage: "book.closed")
            sidebarLink(section: .cookbooks, title: "Cookbooks", systemImage: "books.vertical")
            sidebarLink(section: .shoppingList, title: "Shopping", systemImage: "checklist")
            sidebarLink(section: .search, title: "Search", systemImage: "magnifyingglass")
            sidebarLink(section: .capture, title: "Capture", systemImage: "camera")
            sidebarLink(section: .settings, title: "Settings", systemImage: "gearshape")
        }
    }

    @ViewBuilder private var detailContent: some View {
        destinationContent(for: navigation.route)
    }

    @ViewBuilder private func destinationContent(for route: AppRoute) -> some View {
        switch route {
        case .kitchen:
            KitchenView(
                kitchen: kitchen,
                recipes: recipes,
                cookbooks: cookbooks,
                openRecipe: openRecipe,
                startCooking: startCooking,
                openCookbook: openCookbook
            )
        case .recipes:
            RecipesView(recipes: recipes, openRecipe: openRecipe)
        case .recipeDetail(let id, .detail):
            if let recipe = recipe(id: id) {
                RecipeDetailView(viewModel: RecipeDetailViewModel(recipe: recipe), startCooking: startCooking)
            } else {
                ShellPlaceholderView(title: "Recipe", systemImage: "text.book.closed", detail: id)
            }
        case .recipeDetail(let id, .cook):
            ShellPlaceholderView(title: "Cook Mode", systemImage: "flame", detail: id)
        case .cookbooks:
            CookbooksView(cookbooks: cookbooks, openCookbook: openCookbook)
        case .cookbookDetail(let id):
            if let cookbook = cookbook(id: id) {
                CookbookDetailPlaceholder(cookbook: cookbook)
            } else {
                ShellPlaceholderView(title: "Cookbook", systemImage: "book", detail: id)
            }
        case .shoppingList:
            ShellPlaceholderView(title: "Shopping", systemImage: "checklist", detail: "Receipt rows are next.")
        case .search(let query, let scope):
            ShellPlaceholderView(title: "Search", systemImage: "magnifyingglass", detail: "\(label(for: scope)): \(query)")
        case .capture:
            ShellPlaceholderView(title: "Capture", systemImage: "camera", detail: "Local draft capture is next.")
        case .settings:
            ShellPlaceholderView(title: "Settings", systemImage: "gearshape", detail: "Offline, auth, and environment state.")
        case .unknownLink:
            ShellPlaceholderView(title: "Link Not Found", systemImage: "link.badge.plus", detail: "Open Spoonjoy from a supported recipe, cookbook, shopping, search, capture, or settings link.")
        }
    }

    private var searchText: Binding<String> {
        Binding(
            get: { search.query },
            set: { value in
                search.update(query: value, scope: search.scope)
            }
        )
    }

    private var searchScope: Binding<SearchScope> {
        Binding(
            get: { search.scope },
            set: { scope in
                search.update(query: search.query, scope: scope)
            }
        )
    }

    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { navigation.sidebarSelection },
            set: { section in
                guard let section else { return }
                navigateToSidebar(section)
            }
        )
    }

    private func sidebarLink(section: AppSection, title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .tag(section)
    }

    private func navigateToSidebar(_ section: AppSection) {
        switch section {
        case .kitchen:
            navigation.navigate(to: .kitchen)
        case .recipes:
            navigation.navigate(to: .recipes)
        case .cookbooks:
            navigation.navigate(to: .cookbooks)
        case .shoppingList:
            navigation.navigate(to: .shoppingList)
        case .search:
            search.apply(route: search.route)
            navigation.navigate(to: search.route)
        case .capture:
            navigation.navigate(to: .capture)
        case .settings:
            navigation.navigate(to: .settings)
        }
    }

    private func title(for route: AppRoute) -> String {
        switch route {
        case .kitchen:
            "Kitchen"
        case .recipes, .recipeDetail:
            "Recipes"
        case .cookbooks, .cookbookDetail:
            "Cookbooks"
        case .shoppingList:
            "Shopping"
        case .search:
            "Search"
        case .capture:
            "Capture"
        case .settings:
            "Settings"
        case .unknownLink:
            "Unknown Link"
        }
    }

    private func label(for scope: SearchScope) -> String {
        switch scope {
        case .all:
            "All"
        case .recipes:
            "Recipes"
        case .cookbooks:
            "Cookbooks"
        case .chefs:
            "Chefs"
        case .shoppingList:
            "Shopping"
        }
    }

    private func recipe(id: String) -> Recipe? {
        recipes.first { $0.id == id }
    }

    private func cookbook(id: String) -> Cookbook? {
        cookbooks.first { $0.id == id }
    }

    private func openRecipe(_ id: String) {
        navigation.navigate(to: .recipeDetail(id: id, presentation: .detail))
    }

    private func startCooking(_ id: String) {
        navigation.navigate(to: .recipeDetail(id: id, presentation: .cook))
    }

    private func openCookbook(_ id: String) {
        navigation.navigate(to: .cookbookDetail(id: id))
    }
}

private struct ShellPlaceholderView: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

private struct CookbookDetailPlaceholder: View {
    let cookbook: Cookbook

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(cookbook.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(cookbook.attribution.creditText)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.secondary)
            CookbookShelf(cookbooks: [cookbook]) { _ in }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.bone)
    }
}

private extension KitchenFixtureState {
    static var bootstrapFallback: KitchenFixtureState {
        KitchenFixtureState(
            status: .bootstrap,
            leadObject: .recipe(id: "recipe_lemon_pantry_pasta", title: "Lemon Pantry Pasta"),
            primaryAction: .startCookMode(recipeID: "recipe_lemon_pantry_pasta"),
            counts: KitchenCounts(recipes: 0, cookbooks: 0, shoppingItems: 0),
            offlineRestore: OfflineRestoreMetadata(snapshotID: "bootstrap", includesShoppingList: false)
        )
    }
}
