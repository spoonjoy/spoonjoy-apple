import SpoonjoyCore
import SwiftUI

struct SpoonjoyToolbar: ViewModifier {
    @Binding var navigation: AppNavigationState
    @Binding var search: SearchState
#if os(iOS)
    @Environment(\.editMode) private var editMode: Binding<EditMode>?
#endif

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Spoonjoy")
                            .font(.headline)
                        Text(routeTitle)
                            .font(.caption)
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Spoonjoy, \(routeTitle)")
                }
                ToolbarItem(placement: .primaryAction) {
                    routeActions
                }
            }
    }

    @ViewBuilder private var routeActions: some View {
        switch navigation.route {
        case .kitchen, .recipes, .savedRecipes, .cookbooks, .chefs:
            Button {
                search.apply(route: search.route)
                navigation.pushDesktop(search.route)
            } label: {
                Label(search.hasQuery ? "Open Search" : "Search", systemImage: "magnifyingglass")
            }
            .help("Search Spoonjoy")
        case .recipeDetail, .cookbookDetail, .profile:
            ShareActions(route: navigation.route)
        case .shoppingList:
            editControl
        case .recipeEditor, .recipeCoverControls, .profileGraph, .search, .capture, .settings, .unknownLink:
            EmptyView()
        }
    }

    private var routeTitle: String {
        switch navigation.route {
        case .kitchen:
            "Kitchen"
        case .recipes:
            "My Recipes"
        case .savedRecipes:
            "Saved Recipes"
        case .recipeDetail(_, .detail):
            "Recipe"
        case .recipeDetail(_, .cook):
            "Cook Mode"
        case .recipeEditor:
            "Recipe Editor"
        case .recipeCoverControls:
            "Recipe Covers"
        case .cookbooks:
            "Cookbooks"
        case .cookbookDetail:
            "Cookbook"
        case .chefs:
            "Chefs"
        case .profile:
            "Chef Profile"
        case .profileGraph(_, let direction, _):
            direction == .fellowChefs ? "Fellow Chefs" : "Kitchen Visitors"
        case .shoppingList:
            "Shopping List"
        case .search:
            "Kitchen Search"
        case .capture:
            "Imports"
        case .settings:
            "Settings"
        case .unknownLink:
            "Link Not Found"
        }
    }

#if os(iOS)
    private var editButtonTitle: String {
        editMode?.wrappedValue == .active ? "Done" : "Edit"
    }

    private func toggleEditMode() {
        editMode?.wrappedValue = editMode?.wrappedValue == .active ? .inactive : .active
    }
#endif

    @ViewBuilder private var editControl: some View {
#if os(iOS)
        Button(editButtonTitle) {
            toggleEditMode()
        }
#endif
    }
}

extension View {
    func spoonjoyToolbar(navigation: Binding<AppNavigationState>, search: Binding<SearchState>) -> some View {
        modifier(SpoonjoyToolbar(navigation: navigation, search: search))
    }
}
