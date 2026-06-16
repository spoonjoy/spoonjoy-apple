import Foundation
import SpoonjoyCore
import SwiftUI

struct SearchView: View {
    @Binding private var search: SearchState

    private let recipes: [Recipe]
    private let cookbooks: [Cookbook]
    private let shoppingList: ShoppingListState?
    private let openRecipe: (String) -> Void
    private let openCookbook: (String) -> Void
    private let openShoppingItem: (String) -> Void
    private let openChef: (String) -> Void

    init(
        search: Binding<SearchState>,
        recipes: [Recipe],
        cookbooks: [Cookbook],
        shoppingList: ShoppingListState?,
        openRecipe: @escaping (String) -> Void = { _ in },
        openCookbook: @escaping (String) -> Void = { _ in },
        openShoppingItem: @escaping (String) -> Void = { _ in },
        openChef: @escaping (String) -> Void = { _ in }
    ) {
        _search = search
        self.recipes = recipes
        self.cookbooks = cookbooks
        self.shoppingList = shoppingList
        self.openRecipe = openRecipe
        self.openCookbook = openCookbook
        self.openShoppingItem = openShoppingItem
        self.openChef = openChef
    }

    var body: some View {
        List {
            if resultSections.isEmpty {
                Section {
                    emptyState
                }
            } else {
                ForEach(resultSections) { section in
                    Section(section.title) {
                        ForEach(section.rows) { row in
                            Button {
                                open(row)
                            } label: {
                                SearchResultRowView(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .searchable(text: searchText, prompt: "Search Spoonjoy")
        .searchScopes(searchScope) {
            ForEach(SearchScope.allCases, id: \.rawValue) { scope in
                Text(scope.searchLabel).tag(scope)
            }
        }
        .tint(KitchenTableTheme.herb)
        .accessibilityIdentifier(SearchSurfaceContract.typedRows)
        .accessibilityHint(SearchSurfaceContract.searchableScopes)
    }

    private var searchText: Binding<String> {
        Binding(
            get: { search.query },
            set: { query in
                search.update(query: query, scope: search.scope)
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

    private var resultSections: [SearchResultSection] {
        SearchResultKind.allCases.compactMap { kind in
            let rows = typedRows.filter { row in
                row.kind == kind &&
                    row.isVisible(in: search.scope) &&
                    row.matches(search.query)
            }

            guard !rows.isEmpty else {
                return nil
            }

            return SearchResultSection(kind: kind, title: kind.title, rows: rows)
        }
    }

    private var typedRows: [SearchResultRow] {
        let recipeRows = recipes.map { recipe in
            SearchResultRow.recipe(RecipeSearchSummary(recipe: recipe))
        }
        let cookbookRows = cookbooks.map { cookbook in
            SearchResultRow.cookbook(CookbookSearchSummary(cookbook: cookbook))
        }
        let chefRows = chefResults.map(SearchResultRow.chef)
        let shoppingRows = (shoppingList?.activeItems ?? []).map(SearchResultRow.shoppingItem)

        return recipeRows + cookbookRows + chefRows + shoppingRows
    }

    private var chefResults: [ChefSearchResult] {
        let allChefs = recipes.map(\.chef) + cookbooks.map(\.chef)
        var seenChefIDs = Set<String>()

        return allChefs.compactMap { chef in
            guard seenChefIDs.insert(chef.id).inserted else {
                return nil
            }

            return ChefSearchResult(
                chef: chef,
                recipeCount: recipes.filter { $0.chef.id == chef.id }.count,
                cookbookCount: cookbooks.filter { $0.chef.id == chef.id }.count
            )
        }
    }

    private var emptyState: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(search.hasQuery ? "No matches" : "No searchable table notes")
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text(emptyStateDetail)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KitchenTableTheme.brass)
        }
        .padding(.vertical, 8)
    }

    private var emptyStateDetail: String {
        if search.hasQuery {
            return "Try another recipe, cookbook, chef, or shopping item."
        }

        return "Recipes, cookbooks, chefs, and shopping list items will gather here."
    }

    private func open(_ row: SearchResultRow) {
        switch row {
        case .recipe(let recipe):
            openRecipe(recipe.id)
        case .cookbook(let cookbook):
            openCookbook(cookbook.id)
        case .chef(let chef):
            openChef(chef.id)
        case .shoppingItem(let item):
            openShoppingItem(item.id)
        }
    }
}

private enum SearchSurfaceContract {
    static let searchableScopes = "searchable scopes"
    static let typedRows = "typed rows"
}

private struct SearchResultSection: Identifiable {
    let kind: SearchResultKind
    let title: String
    let rows: [SearchResultRow]

    var id: SearchResultKind {
        kind
    }
}

private enum SearchResultKind: CaseIterable {
    case recipes
    case cookbooks
    case chefs
    case shoppingList

    var title: String {
        switch self {
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
}

private enum SearchResultRow: Identifiable, Equatable {
    case recipe(RecipeSearchSummary)
    case cookbook(CookbookSearchSummary)
    case chef(ChefSearchResult)
    case shoppingItem(ShoppingListItem)

    var id: String {
        switch self {
        case .recipe(let recipe):
            "recipe-\(recipe.id)"
        case .cookbook(let cookbook):
            "cookbook-\(cookbook.id)"
        case .chef(let chef):
            "chef-\(chef.id)"
        case .shoppingItem(let item):
            "shopping-\(item.id)"
        }
    }

    var kind: SearchResultKind {
        switch self {
        case .recipe:
            .recipes
        case .cookbook:
            .cookbooks
        case .chef:
            .chefs
        case .shoppingItem:
            .shoppingList
        }
    }

    var title: String {
        switch self {
        case .recipe(let recipe):
            recipe.title
        case .cookbook(let cookbook):
            cookbook.title
        case .chef(let chef):
            chef.username
        case .shoppingItem(let item):
            item.name
        }
    }

    var subtitle: String {
        switch self {
        case .recipe(let recipe):
            recipe.subtitle
        case .cookbook(let cookbook):
            cookbook.subtitle
        case .chef(let chef):
            chef.subtitle
        case .shoppingItem(let item):
            item.displayQuantity.isEmpty ? "Shopping list" : item.displayQuantity
        }
    }

    var imageURL: URL? {
        switch self {
        case .recipe(let recipe):
            recipe.imageURL
        case .cookbook(let cookbook):
            cookbook.imageURL
        case .chef, .shoppingItem:
            nil
        }
    }

    var systemImage: String {
        switch self {
        case .recipe:
            "book.closed"
        case .cookbook:
            "books.vertical"
        case .chef:
            "person.crop.circle"
        case .shoppingItem(let item):
            Self.shoppingSymbol(for: item)
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .recipe(let recipe):
            recipe.accessibilityLabel
        case .cookbook(let cookbook):
            cookbook.accessibilityLabel
        case .chef(let chef):
            "Chef, \(chef.username), \(chef.subtitle)"
        case .shoppingItem(let item):
            item.displayQuantity.isEmpty
                ? "Shopping item, \(item.name)"
                : "Shopping item, \(item.name), \(item.displayQuantity)"
        }
    }

    private var searchableText: String {
        switch self {
        case .recipe(let recipe):
            [recipe.title, recipe.subtitle, recipe.accessibilityLabel].joined(separator: " ")
        case .cookbook(let cookbook):
            [cookbook.title, cookbook.subtitle, cookbook.accessibilityLabel].joined(separator: " ")
        case .chef(let chef):
            [chef.username, chef.subtitle].joined(separator: " ")
        case .shoppingItem(let item):
            [item.name, item.displayQuantity, item.categoryKey, item.iconKey]
                .compactMap { $0 }
                .joined(separator: " ")
        }
    }

    func isVisible(in scope: SearchScope) -> Bool {
        switch (scope, self) {
        case (.all, _), (.recipes, .recipe), (.cookbooks, .cookbook), (.chefs, .chef), (.shoppingList, .shoppingItem):
            true
        default:
            false
        }
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else {
            return true
        }

        return searchableText.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func shoppingSymbol(for item: ShoppingListItem) -> String {
        switch item.iconKey {
        case "lemon":
            "circle.lefthalf.filled"
        case "pasta":
            "fork.knife"
        case "cheese":
            "square.stack.3d.down.forward"
        case "herb":
            "leaf"
        default:
            "cart"
        }
    }
}

private struct ChefSearchResult: Identifiable, Equatable {
    let id: String
    let username: String
    let recipeCount: Int
    let cookbookCount: Int

    init(chef: ChefSummary, recipeCount: Int, cookbookCount: Int) {
        id = chef.id
        username = chef.username
        self.recipeCount = recipeCount
        self.cookbookCount = cookbookCount
    }

    var subtitle: String {
        let recipeLabel = recipeCount == 1 ? "recipe" : "recipes"
        let cookbookLabel = cookbookCount == 1 ? "cookbook" : "cookbooks"
        return "\(recipeCount) \(recipeLabel), \(cookbookCount) \(cookbookLabel)"
    }
}

private struct SearchResultRowView: View {
    let row: SearchResultRow

    var body: some View {
        HStack(spacing: 12) {
            SearchResultThumbnail(row: row)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text(row.subtitle)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

private struct SearchResultThumbnail: View {
    let row: SearchResultRow

    var body: some View {
        ZStack {
            if let imageURL = row.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    thumbnailFill
                }
            } else {
                thumbnailFill
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
    }

    private var thumbnailFill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                .fill(accent.opacity(0.14))
            Image(systemName: row.systemImage)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
        }
    }

    private var accent: Color {
        switch row.kind {
        case .recipes:
            KitchenTableTheme.tomato
        case .cookbooks:
            KitchenTableTheme.brass
        case .chefs:
            KitchenTableTheme.herb
        case .shoppingList:
            KitchenTableTheme.charcoal
        }
    }
}

private extension SearchScope {
    var searchLabel: String {
        switch self {
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
}
