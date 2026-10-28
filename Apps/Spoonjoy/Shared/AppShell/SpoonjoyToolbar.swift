import SpoonjoyCore
import SwiftUI

struct SpoonjoyToolbar: ViewModifier {
    @Binding var navigation: AppNavigationState
    @Binding var search: SearchState
    let addRecipe: () -> Void
#if os(iOS)
    @Environment(\.editMode) private var editMode: Binding<EditMode>?
#endif

    func body(content: Content) -> some View {
        content
            .toolbar {
                if showsAddRecipe {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add a recipe", systemImage: "plus", action: addRecipe)
                            .accessibilityIdentifier("kitchen.addRecipe")
                    }
                }
                if showsActionsMenu {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                search.apply(route: search.route)
                                navigation.navigate(to: search.route)
                            } label: {
                                Label(search.hasQuery ? "Open Search" : "Search All", systemImage: "magnifyingglass")
                            }
                            ShareActions(route: navigation.route)
                            editControl
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
    }

    /// The recipe page carries its own Share and More, so the shell's Actions would be a second of each.
    private var showsActionsMenu: Bool {
        if case .recipeDetail(_, .detail) = navigation.route {
            return false
        }
        return true
    }

    /// The kitchen and the recipe drawers carry Add a recipe, where the website has Create Recipe.
    private var showsAddRecipe: Bool {
        switch navigation.route {
        case .kitchen, .recipes, .savedRecipes, .everyoneRecipes:
            true
        default:
            false
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
    func spoonjoyToolbar(navigation: Binding<AppNavigationState>, search: Binding<SearchState>, addRecipe: @escaping () -> Void) -> some View {
        modifier(SpoonjoyToolbar(navigation: navigation, search: search, addRecipe: addRecipe))
    }
}
