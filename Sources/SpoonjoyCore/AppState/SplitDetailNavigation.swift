import Foundation

/// The detail column's stack in the split shell (iPad, the open Duo, the Mac), kept in step with
/// `AppNavigationState.route`.
///
/// A sidebar destination is the column's root. Any other page (a recipe, a cookbook, a chef) is pushed on top of the
/// page it was opened from, so it comes with the system back button, the edge swipe and, on the Mac, the toolbar back
/// button. The column used to swap one page for the next, which left every page opened from another with no way back.
///
/// It follows the same loop as `CompactTabNavigation`: route changes come in through `apply(_:)`; a back tap or swipe
/// comes in through `setPath(_:)`, whose returned `route` the shell writes back, and that write then changes nothing.
public struct SplitDetailNavigation: Equatable, Sendable {
    public private(set) var root: AppRoute
    public private(set) var path: [AppRoute]

    public init(route: AppRoute = .kitchen) {
        root = .kitchen
        path = []
        apply(route)
    }

    /// Whether a route is a sidebar destination, which is the root of the column rather than pushed onto it.
    public static func isRoot(_ route: AppRoute) -> Bool {
        switch route {
        case .kitchen, .recipes, .savedRecipes, .everyoneRecipes, .cookbooks, .chefs, .shoppingList, .search,
             .capture, .settings:
            true
        case .recipeDetail, .recipeEditor, .recipeCoverControls, .cookbookDetail, .profile, .profileGraph, .unknownLink:
            false
        }
    }

    /// The page on top of the column, which `AppNavigationState.route` should match.
    public var route: AppRoute {
        path.last ?? root
    }

    /// Whether the column has a page to go back to.
    public var canGoBack: Bool {
        !path.isEmpty
    }

    /// Whether the page on top is an editor, which leaves only through its own Cancel or Save so a draft is never
    /// dropped by a back gesture or ⌘[.
    public var showsEditor: Bool {
        path.last?.isTransientSplitPage == true
    }

    /// The stack to show when the split view comes back (after a compact window, say): the same stack if it still
    /// ends on the route, or a fresh one for the route, so back never leads to pages the person did not come from.
    public func resumed(at route: AppRoute) -> SplitDetailNavigation {
        if route == self.route {
            return self
        }
        if case .recipeDetail(let id, .cook) = route, self.route == .recipeDetail(id: id, presentation: .detail) {
            return self
        }
        return SplitDetailNavigation(route: route)
    }

    /// Moves the column to a route that `AppNavigationState` was sent to.
    public mutating func apply(_ route: AppRoute) {
        guard route != self.route else {
            return
        }
        // Cook mode covers the whole window and hands back to the recipe, so the stack underneath stays as it was.
        if case .recipeDetail(_, .cook) = route {
            return
        }
        // An editor the app navigates away from has finished, so it leaves the stack, as on the phone.
        while path.last?.isTransientSplitPage == true {
            path.removeLast()
        }
        if Self.isRoot(route) {
            root = route
            path = []
            return
        }
        if route == root {
            path = []
        } else if let index = path.firstIndex(of: route) {
            path.removeSubrange(path.index(after: index)...)
        } else {
            path.append(route)
        }
    }

    /// Makes a page the column's root, as a sidebar destination is: a cookbook chosen in the sidebar's table of
    /// contents opens as its own root, the way the sidebar's sections do.
    public mutating func showRoot(_ route: AppRoute) {
        root = route
        path = []
    }

    /// The route the sidebar shows as selected: the column's root, never a page pushed on it. When the sidebar's
    /// selection changes, the split view resets the column to its root, so a selection that followed the pushed page
    /// popped every push the moment it landed.
    public var sidebarRoute: AppRoute {
        root
    }

    /// Records a stack the user changed (back button, edge swipe, ⌘[) and returns the route the column now shows.
    @discardableResult
    public mutating func setPath(_ path: [AppRoute]) -> AppRoute {
        self.path = path
        return route
    }

    /// Goes back one page and returns the route the column now shows.
    @discardableResult
    public mutating func goBack() -> AppRoute {
        if !path.isEmpty {
            path.removeLast()
        }
        return route
    }
}

private extension AppRoute {
    var isTransientSplitPage: Bool {
        switch self {
        case .recipeEditor, .recipeCoverControls:
            true
        default:
            false
        }
    }
}
