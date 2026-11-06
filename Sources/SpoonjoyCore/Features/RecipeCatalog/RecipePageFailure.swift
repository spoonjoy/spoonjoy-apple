import Foundation

/// What a recipe page says when its recipe doesn't load: missing for a recipe the server doesn't have (a stale or
/// mistyped link), otherwise a failure to load. The page offers Back to recipes either way.
public enum RecipePageFailure {
    public static let notFound = "We couldn't find this recipe."
    public static let unavailable = "We couldn't load this recipe."

    /// The message for `error`, and whether the recipe is missing rather than failing.
    public static func message(for error: Error) -> (message: String, isMissing: Bool) {
        if let catalogError = error as? RecipeCatalogRepositoryError, case .recipeNotFound = catalogError {
            return (notFound, true)
        }
        return (unavailable, false)
    }
}
