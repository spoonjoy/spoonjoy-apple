import SwiftUI

/// An ingredient's check, as web draws it: an open brass circle, and once checked a brass disc with a bone tick. Herb
/// stays for cooked and finished, so a checked ingredient never takes it. The caller sets the size; the mark is
/// decoration, so VoiceOver reads the row's value instead.
struct KitchenCheckMark: View {
    let isChecked: Bool

    var body: some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .symbolRenderingMode(.palette)
            // Palette layers: the tick (or the open circle's only layer), then the disc.
            .foregroundStyle(isChecked ? KitchenTableTheme.onInk : KitchenTableTheme.brass, KitchenTableTheme.brass)
            .accessibilityHidden(true)
    }
}
