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
                if showsNewRecipe {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Recipe", systemImage: "plus") {
                            navigation.navigate(to: .recipeEditor(id: nil))
                        }
                        .accessibilityIdentifier("recipes.new")
                    }
                }
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

    /// The kitchen and the recipe drawers carry a create button, like the website's Create Recipe.
    private var showsNewRecipe: Bool {
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
    func spoonjoyToolbar(navigation: Binding<AppNavigationState>, search: Binding<SearchState>) -> some View {
        modifier(SpoonjoyToolbar(navigation: navigation, search: search))
    }
}
