import OuroHX
import SwiftUI

/// An ingredient's check, as web draws it: Ouro's checkbox box (`OuroCheckboxMark`), a squircle that fills with brass
/// and then draws its paper tick along its path, from the cookbook theme's primary and its foreground. Unchecking takes
/// the tick back; under Reduce Motion it fades. Herb stays for cooked and finished, so a checked ingredient never takes
/// it. The row's button style is `OuroCheckboxPressStyle`, so the box presses in under the finger. The mark is
/// decoration, so VoiceOver reads the row's value instead.
struct KitchenCheckMark: View {
    let isChecked: Bool

    /// Half the body's cap height: the box is centred on the label's first line, as web's `mt-0.5` sits it.
    @ScaledMetric(relativeTo: .body) private var capHalf: CGFloat = 6

    var body: some View {
        OuroCheckboxMark(isOn: isChecked)
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + capHalf }
            .accessibilityHidden(true)
    }
}
