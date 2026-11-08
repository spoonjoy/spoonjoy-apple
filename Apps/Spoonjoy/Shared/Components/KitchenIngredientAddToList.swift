import SwiftUI

/// Add to list on one ingredient row, now that the row draws no cart: a long press opens it in the row's context menu,
/// and VoiceOver and Voice Control reach it by the same name as the recipe's own Add to list.
private struct KitchenIngredientAddToList: ViewModifier {
    let isAvailable: Bool
    let add: () -> Void

    func body(content: Content) -> some View {
        if isAvailable {
            content
                .contextMenu {
                    Button(action: add) {
                        Label("Add to list", systemImage: "cart.badge.plus")
                    }
                    .accessibilityIdentifier("ingredient.addToList")
                }
                .accessibilityAction(named: "Add to list", add)
        } else {
            content
        }
    }
}

extension View {
    /// Offers Add to list for this one ingredient, when the recipe can add to the shopping list at all.
    func kitchenIngredientAddToList(isAvailable: Bool, add: @escaping () -> Void) -> some View {
        modifier(KitchenIngredientAddToList(isAvailable: isAvailable, add: add))
    }
}
