/// The order a step's ingredients are shown in once the cook starts checking them off, on the recipe page and
/// in cook mode alike. It matches the web's `IngredientList` (`app/components/recipe/IngredientList.tsx`):
/// unchecked ingredients first, then checked ones, each group in the step's own order. When an ingredient was
/// checked plays no part, so unchecking one puts it straight back where it was.
public enum CheckedIngredientOrder {
    /// The items with every unchecked one first and every checked one last, each group keeping its order.
    public static func ordered<Item>(_ items: [Item], isChecked: (Item) -> Bool) -> [Item] {
        var unchecked: [Item] = []
        var checked: [Item] = []
        for item in items {
            if isChecked(item) {
                checked.append(item)
            } else {
                unchecked.append(item)
            }
        }
        return unchecked + checked
    }

    /// The items ordered by whether their ID is in `checkedIDs`.
    public static func ordered<Item: Identifiable>(_ items: [Item], checkedIDs: Set<Item.ID>) -> [Item] {
        ordered(items) { checkedIDs.contains($0.id) }
    }
}
