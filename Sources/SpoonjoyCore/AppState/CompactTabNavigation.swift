import Foundation

/// The tabs of the compact (iPhone) shell, in tab bar order. Search is the separate search tab.
public enum CompactTab: String, CaseIterable, Hashable, Sendable {
    case kitchen
    case recipes
    case cookbooks
    case shopping
    case search
}

/// Where a route appears in the compact shell.
public enum CompactRoutePlacement: Equatable, Sendable {
    /// The root page of a tab. Opening it selects the tab and pops that tab back to its root.
    case root(CompactTab)
    /// A page that always belongs to one tab, pushed onto that tab's stack.
    case pushed(onto: CompactTab)
    /// A detail page pushed onto the selected tab's stack, so it opens where the user tapped it.
    case pushedOnSelectedTab
    /// A page that covers the tabs entirely (cook mode).
    case fullScreen
}

/// Per-tab navigation stacks for the compact shell, kept in step with `AppNavigationState.route`.
///
/// `AppNavigationState` stays the single source of truth for where the app is: deep links, Spotlight,
/// App Intents and in-app taps all call `navigate(to:)`. The compact shell feeds every route change into
/// `apply(_:)`, which turns it into a tab selection and a push or pop on that tab's stack. When the user
/// switches tabs or pops a page, the shell calls `select(_:)` or `setPath(_:for:)` and writes the returned
/// `route` back to `AppNavigationState`. That write comes back through `apply(_:)` as the route this state
/// already shows, so it changes nothing and cannot loop.
public struct CompactTabNavigation: Equatable, Sendable {
    public private(set) var selectedTab: CompactTab
    /// The Recipes tab root: `.recipes` (Mine) or `.savedRecipes` (Saved).
    public private(set) var recipesRoot: AppRoute
    /// The Search tab root: the current search query and scope.
    public private(set) var searchRoot: AppRoute
    /// The route covering the tabs, if any.
    public private(set) var fullScreenRoute: AppRoute?
    private var paths: [CompactTab: [AppRoute]]

    public init(route: AppRoute = .kitchen) {
        selectedTab = .kitchen
        recipesRoot = .recipes
        searchRoot = .search(query: "", scope: .all)
        fullScreenRoute = nil
        paths = [:]
        apply(route)
    }

    public static func placement(for route: AppRoute) -> CompactRoutePlacement {
        switch route {
        case .kitchen:
            .root(.kitchen)
        case .recipes, .savedRecipes:
            .root(.recipes)
        case .cookbooks:
            .root(.cookbooks)
        case .shoppingList:
            .root(.shopping)
        case .search:
            .root(.search)
        case .recipeDetail(_, .cook):
            .fullScreen
        case .recipeDetail(_, .detail), .recipeEditor, .recipeCoverControls, .cookbookDetail, .profile, .profileGraph:
            .pushedOnSelectedTab
        case .chefs, .capture, .settings, .unknownLink:
            .pushed(onto: .kitchen)
        }
    }

    public func root(for tab: CompactTab) -> AppRoute {
        switch tab {
        case .kitchen:
            .kitchen
        case .recipes:
            recipesRoot
        case .cookbooks:
            .cookbooks
        case .shopping:
            .shoppingList
        case .search:
            searchRoot
        }
    }

    public func path(for tab: CompactTab) -> [AppRoute] {
        paths[tab] ?? []
    }

    /// The page on top of the selected tab.
    public var visibleRoute: AppRoute {
        path(for: selectedTab).last ?? root(for: selectedTab)
    }

    /// The route the shell shows, which `AppNavigationState.route` should match.
    public var route: AppRoute {
        fullScreenRoute ?? visibleRoute
    }

    /// Moves the shell to a route that `AppNavigationState` was sent to.
    public mutating func apply(_ route: AppRoute) {
        guard route != self.route else {
            return
        }
        let placement = Self.placement(for: route)
        if placement == .fullScreen {
            fullScreenRoute = route
            return
        }
        fullScreenRoute = nil
        // An editor the app navigates away from has finished (saved, deleted or abandoned a conflict), so it
        // leaves the stack instead of waiting underneath for the user to come back to it.
        if path(for: selectedTab).last?.isTransientCompactPage == true, route != visibleRoute {
            var path = path(for: selectedTab)
            while path.last?.isTransientCompactPage == true {
                path.removeLast()
            }
            paths[selectedTab] = path
        }
        switch placement {
        case .root(let tab):
            selectedTab = tab
            if tab == .recipes {
                recipesRoot = route
            } else if tab == .search {
                searchRoot = route
            }
            paths[tab] = []
        case .pushed(let tab):
            selectedTab = tab
            push(route, onto: tab)
        case .pushedOnSelectedTab, .fullScreen:
            push(route, onto: selectedTab)
        }
    }

    /// Selects a tab the user tapped and returns the route it shows, keeping that tab's stack.
    @discardableResult
    public mutating func select(_ tab: CompactTab) -> AppRoute {
        selectedTab = tab
        fullScreenRoute = nil
        return route
    }

    /// Records a stack the user changed (back button, swipe back, re-tapping the tab) and returns the route
    /// the shell now shows.
    @discardableResult
    public mutating func setPath(_ path: [AppRoute], for tab: CompactTab) -> AppRoute {
        paths[tab] = path
        return route
    }

    /// Closes the full-screen route the user dismissed and returns the route underneath it.
    @discardableResult
    public mutating func dismissFullScreen() -> AppRoute {
        fullScreenRoute = nil
        return route
    }

    private mutating func push(_ route: AppRoute, onto tab: CompactTab) {
        var path = path(for: tab)
        if let index = path.lastIndex(of: route) {
            path.removeSubrange(path.index(after: index)...)
        } else {
            path.append(route)
        }
        paths[tab] = path
    }
}

private extension AppRoute {
    var isTransientCompactPage: Bool {
        switch self {
        case .recipeEditor, .recipeCoverControls:
            true
        default:
            false
        }
    }
}
