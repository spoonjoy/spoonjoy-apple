import Foundation

/// The page a window was asked to open on: the value `openWindow(value:)` hands a new window, which the system also
/// keeps with the window for state restoration.
public struct WindowRoute: Codable, Hashable, Sendable {
    public let stateIdentifier: String

    public init(_ route: AppRoute) {
        stateIdentifier = route.stateIdentifier
    }

    public var route: AppRoute? {
        AppRoute(stateIdentifier: stateIdentifier)
    }
}

/// Where each window of the app last was, by the system's identifier for that window, so every window reopens on its
/// own recipe, mode and step after the app is closed or killed. The step itself lives with the recipe's cook progress;
/// the book keeps the page (`recipe-cook:<id>` reopens cook mode on the saved step).
public struct SceneRouteBook: Codable, Equatable, Sendable {
    public struct Page: Codable, Equatable, Sendable {
        public let route: String
        public let savedAt: Date

        public init(route: String, savedAt: Date) {
            self.route = route
            self.savedAt = savedAt
        }
    }

    /// The most windows the book remembers; the oldest page goes first. The system discards closed windows, and
    /// `forget(scenes:)` drops them, so this only bounds a book whose discards were missed.
    public static let capacity = 12

    public private(set) var pages: [String: Page]

    public init(pages: [String: Page] = [:]) {
        self.pages = pages
    }

    public func route(forScene scene: String) -> AppRoute? {
        pages[scene].flatMap { AppRoute(stateIdentifier: $0.route) }
    }

    public mutating func record(_ route: AppRoute, scene: String, at date: Date) {
        pages[scene] = Page(route: route.stateIdentifier, savedAt: date)
        let overflow = pages.count - Self.capacity
        guard overflow > 0 else {
            return
        }
        let oldest = pages.sorted { lhs, rhs in
            lhs.value.savedAt == rhs.value.savedAt ? lhs.key < rhs.key : lhs.value.savedAt < rhs.value.savedAt
        }
        for (key, _) in oldest.prefix(overflow) {
            pages[key] = nil
        }
    }

    public mutating func forget<Scenes: Sequence>(scenes: Scenes) where Scenes.Element == String {
        for scene in scenes {
            pages[scene] = nil
        }
    }
}

/// Picks the page a window opens on at launch.
public enum SceneRestoration {
    /// The window's own last page wins, then the page it was opened for, and only a lone window falls back to the
    /// app's last page: a second window someone opens fresh starts on the kitchen instead of copying the first.
    public static func route(
        scenePage: AppRoute?,
        windowValue: AppRoute?,
        appLastRoute: AppRoute?,
        isOnlyWindow: Bool
    ) -> AppRoute? {
        scenePage ?? windowValue ?? (isOnlyWindow ? appLastRoute : nil)
    }

    /// The pages worth reopening on: places to read or cook. A search, an editor, capture or settings is a task the
    /// chef finishes in one sitting, so a relaunch goes back to the page they came from instead.
    public static func remembers(_ route: AppRoute) -> Bool {
        switch route {
        case .kitchen, .recipes, .savedRecipes, .everyoneRecipes, .recipeDetail, .cookbooks, .cookbookDetail, .chefs,
             .profile, .shoppingList:
            true
        case .recipeEditor, .recipeCoverControls, .profileGraph, .search, .capture, .settings, .unknownLink:
            false
        }
    }
}

/// Keeps the book in the app's state directory, next to the cache, so the journey launch reset clears it too.
public struct SceneRouteBookStore {
    public static let fileName = "scene-routes.json"
    private let store: JSONFileStore<SceneRouteBook>

    public init(directory: URL) {
        store = JSONFileStore(fileURL: directory.appendingPathComponent(Self.fileName))
    }

    /// The saved book, or an empty one when there is none or it cannot be read.
    public func load() -> SceneRouteBook {
        (try? store.load())?.value ?? SceneRouteBook()
    }

    public func update(_ change: (inout SceneRouteBook) -> Void) {
        var book = load()
        change(&book)
        try? store.save(book)
    }
}
