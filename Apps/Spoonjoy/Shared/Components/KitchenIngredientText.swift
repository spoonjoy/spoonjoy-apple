import SwiftUI

/// An ingredient's words, as web sets them: the name in serif, and its aisle under it in a smaller muted serif, in
/// sentence case. Checked, the name is struck through in the muted ink. The row places the amount.
struct KitchenIngredientText: View {
    let name: String
    let note: String?
    var isChecked = false
    /// Lines the name may take at the default text sizes; the accessibility sizes always wrap in full.
    var nameLineLimit: Int?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(isChecked ? KitchenTableTheme.ink2 : KitchenTableTheme.ink)
                .strikethrough(isChecked, color: KitchenTableTheme.ink2)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : nameLineLimit)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let note, !note.isEmpty {
                Text(note)
                    .font(KitchenTableTheme.ingredientNote)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
