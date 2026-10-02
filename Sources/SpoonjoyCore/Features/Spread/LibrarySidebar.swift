import Foundation

/// A row in the regular-width library sidebar.
public enum LibrarySidebarDestination: Hashable, Sendable {
    /// One of the kitchen's sections: Kitchen, My Recipes, Cookbooks, Shopping List and the rest.
    case section(AppSection)
    /// One of the current chef's cookbooks, listed under Cookbooks like a table of contents.
    case cookbook(id: String)
}

/// A cookbook listed in the sidebar's table of contents.
public struct LibrarySidebarCookbookEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let recipeCount: Int

    public init(id: String, title: String, recipeCount: Int) {
        self.id = id
        self.title = title
        self.recipeCount = recipeCount
    }

    public var recipeCountLabel: String {
        switch recipeCount {
        case 0:
            "Empty"
        case 1:
            "1 recipe"
        default:
            "\(recipeCount) recipes"
        }
    }
}

/// The regular-width library sidebar: the kitchen's sections, then the chef's own cookbooks as a table of contents.
public enum LibrarySidebar {
    /// The current chef's cookbooks, in the order the server returned them. Cookbooks by other chefs stay on the
    /// Cookbooks page; the sidebar lists only the shelf the chef owns.
    public static func cookbookEntries(cookbooks: [Cookbook], currentChefID: String?) -> [LibrarySidebarCookbookEntry] {
        guard let currentChefID else {
            return []
        }
        return cookbooks
            .filter { $0.chef.id == currentChefID }
            .map { LibrarySidebarCookbookEntry(id: $0.id, title: $0.title, recipeCount: $0.recipeCount) }
    }

    /// The sidebar row to highlight for the current route.
    public static func selection(
        route: AppRoute,
        sidebarSection: AppSection,
        cookbookEntries: [LibrarySidebarCookbookEntry]
    ) -> LibrarySidebarDestination {
        if case .cookbookDetail(let id) = route, cookbookEntries.contains(where: { $0.id == id }) {
            return .cookbook(id: id)
        }
        return .section(sidebarSection)
    }
}
