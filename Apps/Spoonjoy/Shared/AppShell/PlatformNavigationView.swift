import SpoonjoyCore
import SwiftUI

struct PlatformNavigationView: View {
    @Binding var navigation: AppNavigationState
    @Binding var search: SearchState

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
        List {
            sidebarButton(section: .kitchen, title: "Kitchen", systemImage: "house", route: .kitchen)
            sidebarButton(section: .recipes, title: "Recipes", systemImage: "book.closed", route: .recipes)
            sidebarButton(section: .cookbooks, title: "Cookbooks", systemImage: "books.vertical", route: .cookbooks)
            sidebarButton(section: .shoppingList, title: "Shopping", systemImage: "checklist", route: .shoppingList)
            sidebarButton(section: .search, title: "Search", systemImage: "magnifyingglass", route: search.route)
            sidebarButton(section: .capture, title: "Capture", systemImage: "camera", route: .capture)
            sidebarButton(section: .settings, title: "Settings", systemImage: "gearshape", route: .settings)
        }
    }

    @ViewBuilder private var detailContent: some View {
        switch navigation.route {
        case .kitchen:
            SignedOutSetupView(
                openCapture: { navigation.navigate(to: .capture) },
                openSettings: { navigation.navigate(to: .settings) }
            )
        case .recipes:
            ShellPlaceholderView(title: "Recipes", systemImage: "book.closed", detail: "Recipe index is next.")
        case .recipeDetail(let id, .detail):
            ShellPlaceholderView(title: "Recipe", systemImage: "text.book.closed", detail: id)
        case .recipeDetail(let id, .cook):
            ShellPlaceholderView(title: "Cook Mode", systemImage: "flame", detail: id)
        case .cookbooks:
            ShellPlaceholderView(title: "Cookbooks", systemImage: "books.vertical", detail: "Cookbook shelf is next.")
        case .cookbookDetail(let id):
            ShellPlaceholderView(title: "Cookbook", systemImage: "book", detail: id)
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

    private func sidebarButton(section: AppSection, title: String, systemImage: String, route: AppRoute) -> some View {
        Button {
            navigation.navigate(to: route)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(navigation.sidebarSelection == section ? .primary : .secondary)
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
