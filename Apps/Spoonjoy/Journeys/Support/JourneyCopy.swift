import SpoonjoyCore

/// User-visible copy that journeys assert. Anything else is found by `JourneyID`.
enum JourneyCopy {
    /// The confirmation dialog button that signs out.
    static let signOutConfirm = "Sign Out"
    /// The sign-in status after a rejected password (`SignedOutSetupView.passwordSignInFailureMessage`).
    static let wrongPasswordStatus = "Could not sign in. Check your username, password, and connection."

    // Tab bar items cannot carry accessibility identifiers, so tabs are found by their titles.
    static let kitchenTab = "Kitchen"
    static let recipesTab = "Recipes"
    static let cookbooksTab = "Cookbooks"
    static let shoppingTab = "Shopping"
    static let searchTab = "Search"
    static let mineScope = "Mine"
    static let everyoneScope = "Everyone"

    /// The not-found page's message for a recipe link that matches no recipe.
    static let recipeNotFound = "We couldn't find this recipe."
    /// The App Shortcut phrase the Add a recipe sheet teaches (`SpoonjoyAppShortcuts`, CaptureRecipeIntent).
    static let addRecipeSiriPhrase = AddRecipeCopy.siriPhrase
    /// The editor's confirmation for leaving with unsaved changes.
    static let discardChanges = "Discard Changes"
}
