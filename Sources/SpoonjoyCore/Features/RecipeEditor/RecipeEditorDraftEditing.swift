import Foundation

// The editor's small edits, as its fields and sheets make them. `RecipeEditorView` and `IngredientPasteSheet` call
// these, and so does Ouro Reins.

extension RecipeEditorIngredientDraft {
    /// The rows a pasted block of ingredient text becomes, one per line, each with a fresh local ID.
    public static func pasted(_ text: String, makeID: () -> String) -> [RecipeEditorIngredientDraft] {
        IngredientTextParser.parse(text).map { RecipeEditorIngredientDraft(id: makeID(), parsed: $0) }
    }

    /// The pasted rows Add puts on the step: those with a name.
    public static func addable(_ rows: [RecipeEditorIngredientDraft]) -> [RecipeEditorIngredientDraft] {
        rows.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The name field changed to `newValue`. Return (a newline) ends the line: "2 cups rice" fills the quantity and
    /// unit. Returns true when Return was pressed, and the field lets go of the keyboard.
    @discardableResult
    public mutating func typeName(_ newValue: String) -> Bool {
        guard newValue.contains("\n") else {
            name = newValue
            return false
        }
        name = newValue.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        applyTypedLine()
        return true
    }
}

extension RecipeEditorDraft {
    /// Where Cancel and Discard go: the recipe, or Recipes for a new one.
    public var exitRoute: AppRoute {
        recipeID.map { .recipeDetail(id: $0, presentation: .detail) } ?? .recipes
    }

    /// Adds the rows to the step's ingredients.
    public mutating func addIngredients(_ ingredients: [RecipeEditorIngredientDraft], toStep stepID: String) {
        guard let index = steps.firstIndex(where: { $0.id == stepID }) else {
            return
        }
        steps[index].ingredients.append(contentsOf: ingredients)
    }

    /// Adds a blank ingredient row (one, no unit) to the step, for the cook to type into.
    public mutating func addIngredient(id: String, toStep stepID: String) {
        addIngredients([RecipeEditorIngredientDraft(id: id, name: "", quantity: 1, unit: nil)], toStep: stepID)
    }
}
