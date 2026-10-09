import Foundation

/// The name a byline shows for a chef's username.
///
/// When a chef deletes their account, recipes other cooks forked, saved or cooked stay up under the
/// `deleted-chef` placeholder account (spoonjoy-v2 docs/account-deletion.md). Bylines show it as
/// "Deleted chef", as the web does; every other username shows as itself.
public enum ChefDisplayName {
    public static let deletedChefUsername = "deleted-chef"
    public static let deletedChef = "Deleted chef"

    public static func forUsername(_ username: String) -> String {
        username.lowercased() == deletedChefUsername ? deletedChef : username
    }
}

public extension ChefSummary {
    /// The chef's name for a byline. See ``ChefDisplayName``.
    var displayName: String {
        ChefDisplayName.forUsername(username)
    }
}

public extension NativeChefRef {
    /// The chef's name for a chef list. See ``ChefDisplayName``.
    var displayName: String {
        ChefDisplayName.forUsername(username)
    }
}
