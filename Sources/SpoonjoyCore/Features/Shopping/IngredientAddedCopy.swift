/// What the recipe page says after one ingredient goes onto the shopping list from its row.
public enum IngredientAddedCopy {
    public static func status(name: String, queuedForSync: Bool) -> String {
        queuedForSync ? "\(name) saved for sync" : "\(name) added to your list"
    }
}
