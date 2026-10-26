import Foundation

/// What the Add a recipe sheet says and accepts.
public enum AddRecipeCopy {
    /// The App Shortcut phrase for `CaptureRecipeIntent`, exactly as `SpoonjoyAppShortcuts` declares it.
    /// App Shortcut phrases must be literals in the intent itself, so a test pins that file to this template.
    public static let siriPhraseTemplate = "Save a recipe to \\(.applicationName)"

    /// The phrase as people say it, with the app's name in place.
    public static let siriPhrase = siriPhraseTemplate.replacingOccurrences(of: "\\(.applicationName)", with: "Spoonjoy")

    /// A web link worth importing: http or https with a host. Anything else keeps Import disabled.
    public static func recipeLink(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty else {
            return nil
        }
        return url
    }
}

/// The message after a recipe row's Add to list, with whether it went wrong.
public struct RecipeListAddNotice: Equatable, Sendable {
    public let message: String
    public let isFailure: Bool

    /// The ingredients reached the list, or are saved to reach it when the app is back online.
    public static func added(recipeTitle: String, outcome: ShoppingSurfaceMutationOutcome) -> RecipeListAddNotice {
        switch outcome {
        case .synced, .recovering:
            RecipeListAddNotice(message: "Added \(recipeTitle) to your list", isFailure: false)
        case .queuedForSync:
            RecipeListAddNotice(message: "\(recipeTitle) will reach your list when you're back online", isFailure: false)
        }
    }

    public static func failed(recipeTitle: String) -> RecipeListAddNotice {
        RecipeListAddNotice(message: "Couldn't add \(recipeTitle) to your list. Try again.", isFailure: true)
    }
}
