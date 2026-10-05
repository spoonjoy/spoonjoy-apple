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

    /// Reorder controls: a step's move buttons, and an ingredient's reorder menu with its Move Up and Move Down items.
    static func editorStepMoveUp(_ step: Int) -> String { "editor.step.\(step).moveUp" }
    static func editorStepMoveDown(_ step: Int) -> String { "editor.step.\(step).moveDown" }
    static func editorIngredientReorder(step: Int, ingredient: Int) -> String { "editor.step.\(step).ingredient.\(ingredient).reorder" }
    static func editorIngredientMoveUp(step: Int, ingredient: Int) -> String { "editor.step.\(step).ingredient.\(ingredient).moveUp" }

    /// The create editor's photo row: the picker button and the "Photo ready" label that shows a photo is chosen.
    static let editorPhotoPick = "editor.photo.pick"
    static let editorPhotoReady = "editor.photo.ready"

    /// The "Paste Ingredients" button on a step, and its sheet: the text box, the add button and the preview rows.
    static func editorStepPasteIngredients(_ step: Int) -> String { "editor.step.\(step).pasteIngredients" }
    static let editorPasteText = "editor.paste.text"
    static let editorPasteAdd = "editor.paste.add"
    static func editorPasteRowName(_ row: Int) -> String { "editor.paste.row.\(row).name" }
    static func editorPasteRowQuantity(_ row: Int) -> String { "editor.paste.row.\(row).quantity" }
    static func editorPasteRowUnit(_ row: Int) -> String { "editor.paste.row.\(row).unit" }

    /// Every recipe row (lead and index) in My Recipes.
    static let recipesRow = "recipes.row"

    static let recipeDetailTitle = "recipeDetail.title"
    static func recipeDetailStep(_ step: Int) -> String { "recipeDetail.step.\(step)" }

    /// The recipe's cover image, shown once it has a real cover.
    static let recipeDetailCover = "recipeDetail.cover"
    /// The "Edit recipe" item in the detail page's actions menu.
    static let recipeDetailEdit = "recipeDetail.edit"

    /// The recipe detail page's actions menu ("Recipe actions" on a phone, "More" on a wide screen).
    static let recipeDetailActions = "recipeDetail.actions"
    static let recipeDetailRemindersSend = "recipeDetail.remindersSend"
    /// The success or error line under the recipe's actions.
    static let recipeDetailStatus = "recipeDetail.status"

    /// Every Reminders list in the "Send ingredients to" picker; the label is the list name.
    static let remindersList = "reminders.list"
    /// The picker's "Or make a new list" field and its "Create and use" button.
    static let remindersNewListName = "reminders.newListName"
    static let remindersCreateList = "reminders.createList"

    /// Every result row in Search.
    static let searchResult = "search.result"
}
