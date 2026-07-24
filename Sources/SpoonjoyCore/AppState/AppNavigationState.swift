import Foundation

public enum AppNavigationShell: Equatable, Sendable {
    case compact
    case desktop
}

public struct AppNavigationState: Equatable {
    public private(set) var route: AppRoute
    public private(set) var sidebarSelection: AppSection
    public private(set) var compactTabSelection: AppSection
    public private(set) var desktopPath: [AppRoute]
    private var compactPaths: [AppSection: [AppRoute]]
    private var desktopCompactReturnTab: AppSection?

    public init(route: AppRoute = .kitchen) {
        self.route = route
        self.sidebarSelection = route.section ?? .kitchen
        let compactTab = Self.preferredCompactTab(for: route)
        self.compactTabSelection = compactTab
        self.desktopPath = Self.isDesktopRoot(route) ? [] : [route]
        self.compactPaths = [:]
        self.desktopCompactReturnTab = nil
        if route != Self.compactRootRoute(for: compactTab) {
            compactPaths[compactTab] = [route]
        }
    }

    public var selectedRecipeID: String? {
        route.selectedRecipeID
    }

    public var isCookModeActive: Bool {
        route.isCookModeActive
    }

    public mutating func navigate(to route: AppRoute) {
        desktopCompactReturnTab = nil
        let compactTab = Self.preferredCompactTab(for: route)
        compactTabSelection = compactTab
        if route == Self.compactRootRoute(for: compactTab) {
            compactPaths[compactTab] = []
        } else {
            compactPaths[compactTab] = [route]
        }
        desktopPath = Self.isDesktopRoot(route) ? [] : [route]
        updateSelection(for: route)
    }

    public var desktopRootRoute: AppRoute {
        Self.desktopRootRoute(for: sidebarSelection)
    }

    public mutating func setDesktopPath(_ path: [AppRoute]) {
        let poppedToRoot = !desktopPath.isEmpty && path.isEmpty
        desktopPath = path
        if poppedToRoot {
            desktopCompactReturnTab = nil
        }
        route = path.last ?? desktopRootRoute
    }

    public mutating func pushDesktop(_ route: AppRoute) {
        if Self.isDesktopRoot(route) {
            if let section = route.section {
                selectSidebar(section)
            }
            return
        }
        guard desktopPath.last != route else {
            return
        }
        desktopPath.append(route)
        self.route = route
    }

    public mutating func replaceDesktopTop(with route: AppRoute) {
        if desktopPath.isEmpty {
            desktopPath.append(route)
        } else {
            desktopPath[desktopPath.index(before: desktopPath.endIndex)] = route
        }
        self.route = route
    }

    public mutating func completeDesktopRoute(returningTo route: AppRoute) {
        if Self.isDesktopRoot(route) {
            if let section = route.section {
                selectSidebar(section)
            }
            return
        }
        desktopPath = Self.completing(desktopPath, returningTo: route)
        self.route = route
    }

    public mutating func selectSidebar(_ section: AppSection) {
        desktopCompactReturnTab = nil
        sidebarSelection = section
        desktopPath = []
        route = Self.desktopRootRoute(for: section)
    }

    public func compactPath(for section: AppSection) -> [AppRoute] {
        compactPaths[section] ?? []
    }

    public mutating func setCompactPath(_ path: [AppRoute], for section: AppSection) {
        guard Self.compactTabSections.contains(section) else {
            return
        }
        compactPaths[section] = path
        guard compactTabSelection == section else {
            return
        }
        updateSelection(for: path.last ?? Self.compactRootRoute(for: section))
    }

    public mutating func selectCompactTab(_ section: AppSection) {
        guard Self.compactTabSections.contains(section) else {
            return
        }
        compactTabSelection = section
        updateSelection(for: compactPath(for: section).last ?? Self.compactRootRoute(for: section))
    }

    public mutating func synchronizeForShellTransition(to shell: AppNavigationShell) {
        switch shell {
        case .compact:
            let activeRoute = desktopPath.last ?? desktopRootRoute
            let compactTab = desktopCompactReturnTab ?? Self.preferredCompactTab(for: activeRoute)
            let activePath = desktopPath.isEmpty && activeRoute != Self.compactRootRoute(for: compactTab)
                ? [activeRoute]
                : desktopPath
            compactTabSelection = compactTab
            compactPaths[compactTab] = activePath
            desktopCompactReturnTab = nil
            updateSelection(for: activeRoute)
        case .desktop:
            desktopCompactReturnTab = compactTabSelection
            let activePath = compactPath(for: compactTabSelection)
            let activeRoute = activePath.last ?? Self.compactRootRoute(for: compactTabSelection)
            updateSelection(for: activeRoute)
            desktopPath = activeRoute == desktopRootRoute ? [] : activePath
        }
    }

    public mutating func pushCompact(_ route: AppRoute) {
        if let rootTab = Self.compactRootTab(for: route) {
            selectCompactTab(rootTab)
            return
        }

        var path = compactPath(for: compactTabSelection)
        guard path.last != route else {
            return
        }
        path.append(route)
        compactPaths[compactTabSelection] = path
        updateSelection(for: route)
    }

    public mutating func replaceCompactTop(with route: AppRoute) {
        var path = compactPath(for: compactTabSelection)
        if path.isEmpty {
            path.append(route)
        } else {
            path[path.index(before: path.endIndex)] = route
        }
        compactPaths[compactTabSelection] = path
        updateSelection(for: route)
    }

    public mutating func completeCompactRoute(returningTo route: AppRoute) {
        if let rootTab = Self.compactRootTab(for: route) {
            compactPaths[compactTabSelection] = []
            compactTabSelection = rootTab
            compactPaths[rootTab] = []
            updateSelection(for: route)
            return
        }

        compactPaths[compactTabSelection] = Self.completing(
            compactPath(for: compactTabSelection),
            returningTo: route
        )
        updateSelection(for: route)
    }

    public mutating func applyDeepLink(_ url: URL, router: DeepLinkRouter = .spoonjoy) {
        navigate(to: router.route(for: url))
    }

    private mutating func updateSelection(for route: AppRoute) {
        self.route = route
        if let section = route.section {
            sidebarSelection = section
        }
    }

    private static func completing(_ path: [AppRoute], returningTo route: AppRoute) -> [AppRoute] {
        guard path.last != route else {
            return path
        }
        if path.dropLast().last == route {
            return Array(path.dropLast())
        }
        guard !path.isEmpty else {
            return [route]
        }
        var path = path
        path[path.index(before: path.endIndex)] = route
        return path
    }

    private static let compactTabSections: Set<AppSection> = [
        .kitchen,
        .recipes,
        .savedRecipes,
        .cookbooks,
        .shoppingList
    ]

    private static func compactRootTab(for route: AppRoute) -> AppSection? {
        switch route {
        case .kitchen:
            .kitchen
        case .recipes:
            .recipes
        case .savedRecipes:
            .savedRecipes
        case .cookbooks:
            .cookbooks
        case .shoppingList:
            .shoppingList
        default:
            nil
        }
    }

    private static func preferredCompactTab(for route: AppRoute) -> AppSection {
        switch route {
        case .recipes, .recipeDetail, .recipeEditor, .recipeCoverControls:
            .recipes
        case .savedRecipes:
            .savedRecipes
        case .cookbooks, .cookbookDetail:
            .cookbooks
        case .shoppingList:
            .shoppingList
        case .kitchen, .chefs, .profile, .profileGraph, .search, .capture, .settings, .unknownLink:
            .kitchen
        }
    }

    private static func compactRootRoute(for section: AppSection) -> AppRoute {
        switch section {
        case .recipes:
            .recipes
        case .savedRecipes:
            .savedRecipes
        case .cookbooks:
            .cookbooks
        case .shoppingList:
            .shoppingList
        case .kitchen, .chefs, .search, .capture, .settings:
            .kitchen
        }
    }

    private static func isDesktopRoot(_ route: AppRoute) -> Bool {
        switch route {
        case .kitchen, .recipes, .savedRecipes, .cookbooks, .shoppingList, .chefs, .search, .capture, .settings:
            true
        case .recipeDetail, .recipeEditor, .recipeCoverControls, .cookbookDetail, .profile, .profileGraph, .unknownLink:
            false
        }
    }

    private static func desktopRootRoute(for section: AppSection) -> AppRoute {
        switch section {
        case .kitchen:
            .kitchen
        case .recipes:
            .recipes
        case .savedRecipes:
            .savedRecipes
        case .cookbooks:
            .cookbooks
        case .shoppingList:
            .shoppingList
        case .chefs:
            .chefs
        case .search:
            .search(query: "", scope: .all)
        case .capture:
            .capture
        case .settings:
            .settings
        }
    }
}
