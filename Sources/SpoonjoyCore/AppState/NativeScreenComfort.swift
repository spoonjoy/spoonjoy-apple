import Foundation

/// Whether the iPhone should be kept from auto-locking while someone cooks.
public enum CookModeScreenAwakePolicy {
    /// The idle timer is disabled only while cook mode is on screen and the app is in the foreground.
    /// Leaving cook mode, backgrounding the app, or the view disappearing all restore normal auto-lock.
    public static func shouldKeepScreenAwake(isCookModeVisible: Bool, isAppActive: Bool) -> Bool {
        isCookModeVisible && isAppActive
    }
}

/// Which routes refresh when the chef pulls down.
public enum PullToRefreshPolicy {
    public static func supportsPullToRefresh(_ route: AppRoute) -> Bool {
        switch route {
        case .kitchen, .recipes, .savedRecipes, .everyoneRecipes, .recipeDetail(_, .detail), .cookbooks, .shoppingList:
            true
        default:
            false
        }
    }
}
