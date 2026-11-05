import SwiftUI

private struct SpoonjoyGoBackFocusedKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    /// Goes back a page in the focused window, when it has one to go back to; ⌘[ calls it.
    var spoonjoyGoBack: (() -> Void)? {
        get { self[SpoonjoyGoBackFocusedKey.self] }
        set { self[SpoonjoyGoBackFocusedKey.self] = newValue }
    }
}

/// ⌘[ goes back a page, on the Mac and on an iPad with a keyboard, as in Apple's own apps.
struct SpoonjoyGoBackCommands: Commands {
    @FocusedValue(\.spoonjoyGoBack) private var goBack

    var body: some Commands {
        // A Go menu, where Apple's apps keep Back.
        CommandMenu("Go") {
            Button("Back") {
                goBack?()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(goBack == nil)
        }
    }
}
