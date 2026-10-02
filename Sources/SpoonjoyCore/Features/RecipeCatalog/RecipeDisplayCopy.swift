import Foundation

/// Display rules for the short line shown under a recipe title.
///
/// Recipes that have no written description fall back to a generated credit such as
/// "Lemon Pantry Pasta by ari on Spoonjoy". That line only restates the title and the chef,
/// both of which the screen already shows, so it must not appear as a subtitle.
public enum RecipeDisplayCopy {
    /// The subtitle to show under the title, or nil when there is nothing worth saying.
    public static func subtitle(description: String?, creditText: String, title: String, chefUsername: String) -> String? {
        for candidate in [description, creditText] {
            guard let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                continue
            }
            if restatesTitleAndChef(text, title: title, chefUsername: chefUsername) {
                continue
            }
            return text
        }
        return nil
    }

    static func restatesTitleAndChef(_ text: String, title: String, chefUsername: String) -> Bool {
        let normalized = text.lowercased()
        let generated = "\(title) by \(chefUsername) on Spoonjoy".lowercased()
        if normalized == generated {
            return true
        }
        return normalized.hasSuffix(" on spoonjoy")
            && normalized.contains(title.lowercased())
            && normalized.contains(chefUsername.lowercased())
    }
}

public extension Recipe {
    /// The subtitle to show under this recipe's title. Nil when the only text available restates the title and chef.
    var displaySubtitle: String? {
        RecipeDisplayCopy.subtitle(
            description: description,
            creditText: attribution.creditText,
            title: title,
            chefUsername: chef.username
        )
    }
}
