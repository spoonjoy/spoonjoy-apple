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
                ToolbarItem(placement: .primaryAction) {
                    ShareActions(route: navigation.route)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Kitchen") { navigation.navigate(to: .kitchen) }
                        Button("Capture Draft") { navigation.navigate(to: .capture) }
                        Button("Settings") { navigation.navigate(to: .settings) }
                        Button(search.hasQuery ? "Open Search" : "Search All") {
                            navigation.navigate(to: search.route)
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    editControl
                }
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
#else
        Button("Select") {}
            .disabled(true)
#endif
    }
}

extension View {
    func spoonjoyToolbar(navigation: Binding<AppNavigationState>, search: Binding<SearchState>) -> some View {
        modifier(SpoonjoyToolbar(navigation: navigation, search: search))
    }
}
