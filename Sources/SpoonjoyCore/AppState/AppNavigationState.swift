import Foundation

public struct AppNavigationState: Equatable {
    public private(set) var route: AppRoute
    public private(set) var sidebarSelection: AppSection
    /// How many times the app has opened each recipe editor from some other page, by route identifier.
    private var editorSessions: [String: Int] = [:]

    public init(route: AppRoute = .kitchen) {
        self.route = route
        self.sidebarSelection = route.section ?? .kitchen
    }

    public var selectedRecipeID: String? {
        route.selectedRecipeID
    }

    public var isCookModeActive: Bool {
        route.isCookModeActive
    }

    /// Names one visit to a recipe editor. Each time the app opens an editor from another page (New Recipe
    /// while another editor is open, New Recipe a second time, or an editor for a different recipe) that
    /// editor's identity changes, so the shell gives it a fresh draft instead of reusing the one the page
    /// showed before. Editors for other routes keep their identity, so an editor left open on another tab
    /// keeps what the chef typed.
    public func editorIdentity(for route: AppRoute) -> String {
        "\(route.stateIdentifier)#\(editorSessions[route.stateIdentifier] ?? 0)"
    }

    public var editorIdentity: String {
        editorIdentity(for: route)
    }

    public mutating func navigate(to route: AppRoute) {
        if case .recipeEditor = route, route != self.route {
            editorSessions[route.stateIdentifier, default: 0] += 1
        }
        self.route = route

        if let section = route.section {
            sidebarSelection = section
        }
    }

    public mutating func applyDeepLink(_ url: URL, router: DeepLinkRouter = .spoonjoy) {
        navigate(to: router.route(for: url))
    }
}
