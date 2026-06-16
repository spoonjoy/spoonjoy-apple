import Foundation

public struct AppNavigationState: Equatable {
    public private(set) var route: AppRoute
    public private(set) var sidebarSelection: AppSection

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

    public mutating func navigate(to route: AppRoute) {
        self.route = route

        if let section = route.section {
            sidebarSelection = section
        }
    }

    public mutating func applyDeepLink(_ url: URL, router: DeepLinkRouter = .spoonjoy) {
        navigate(to: router.route(for: url))
    }
}
