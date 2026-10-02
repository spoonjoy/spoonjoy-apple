/// Accessibility identifiers the journeys query, named `<screen>.<element>`.
enum JourneyID {
    // Sign-in identifiers predate the naming scheme; renaming them would churn existing scripts.
    static let signInIdentifier = "native sign-in email or username"
    static let signInPassword = "native sign-in password"
    static let passwordSignIn = "native password sign-in"
    static let signInStatus = "native sign-in status"
    static let signInSettings = "signin.settings"

    static let settingsEnvironmentValue = "settings.environment.value"
    static let settingsClose = "settings.close"
    static let settingsSignOut = "settings.signout"

    /// The Kitchen root's account button, which opens Settings.
    static let kitchenAccount = "kitchen.account"

    static let kitchenRoot = "kitchen.root"
    /// The lead recipe and every Recipe Index row in the Kitchen; the label is the recipe title.
    static let kitchenRecipe = "kitchen.recipe"
    /// The lead recipe's "Open Recipe" button.
    static let kitchenRecipeOpen = "kitchen.recipe.open"

    /// "Create a recipe" (and the accessibility-layout "New recipe") on the Shopping List.
    static let shoppingCreateRecipe = "shopping.createRecipe"

    static let editorTitle = "editor.title"
    static let editorServings = "editor.servings"
    static let editorAddStep = "editor.addStep"
    static let editorSave = "editor.save"
    /// The editor's message when a save is blocked or fails.
    static let editorStatus = "editor.status"

    /// Editor step fields. `step` and `ingredient` are 1-based positions in the draft, not server ids.
    static func editorStepTitle(_ step: Int) -> String { "editor.step.\(step).title" }
    static func editorStepDescription(_ step: Int) -> String { "editor.step.\(step).description" }
    static func editorStepAddIngredient(_ step: Int) -> String { "editor.step.\(step).addIngredient" }
    static func editorIngredientName(step: Int, ingredient: Int) -> String { "editor.step.\(step).ingredient.\(ingredient).name" }
    static func editorIngredientQuantity(step: Int, ingredient: Int) -> String { "editor.step.\(step).ingredient.\(ingredient).quantity" }
    static func editorIngredientUnit(step: Int, ingredient: Int) -> String { "editor.step.\(step).ingredient.\(ingredient).unit" }

    /// Every recipe row (lead and index) in My Recipes.
    static let recipesRow = "recipes.row"

    static let recipeDetailTitle = "recipeDetail.title"
    static func recipeDetailStep(_ step: Int) -> String { "recipeDetail.step.\(step)" }

    /// The recipe detail page's actions menu ("Recipe actions" on a phone, "More" on a wide screen).
    static let recipeDetailActions = "recipeDetail.actions"
    static let recipeDetailRemindersSend = "recipeDetail.remindersSend"
    /// The success or error line under the recipe's actions.
    static let recipeDetailStatus = "recipeDetail.status"

    /// Every Reminders list in the "Send ingredients to" picker; the label is the list name.
    static let remindersList = "reminders.list"

    /// Every result row in Search.
    static let searchResult = "search.result"
}
