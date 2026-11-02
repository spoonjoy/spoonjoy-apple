import Foundation

/// Decides when a window may save the page it moved to as its own, whatever order launch events arrive in.
///
/// A link that launches the app can arrive before the system names the window. Saved then, the page has no window
/// to belong to, and after a kill the window reopens on its older page. So the page waits for the window's name and
/// is saved the moment the name arrives. (The app's own last page needs no wait here: the store holds a page opened
/// before the launch restore until it knows whose kitchen it is, so a link never saves over the chef's state.)
public struct OpenedPageRecorder: Equatable, Sendable {
    /// A page to save as the window's own, under the system's name for the window.
    public struct WindowPage: Equatable, Sendable {
        public let route: AppRoute
        public let sceneID: String

        public init(route: AppRoute, sceneID: String) {
            self.route = route
            self.sceneID = sceneID
        }
    }

    private var sceneID: String?
    private var waiting: AppRoute?

    public init() {}

    /// The window moved to `route`, by a link or by the chef. Pages a window never reopens on are not saved.
    public mutating func opened(_ route: AppRoute) -> WindowPage? {
        guard SceneRestoration.remembers(route) else {
            return nil
        }
        guard let sceneID else {
            waiting = route
            return nil
        }
        return WindowPage(route: route, sceneID: sceneID)
    }

    /// The system named the window: the latest page opened before then is saved now.
    public mutating func sceneIdentified(_ id: String) -> WindowPage? {
        sceneID = id
        guard let route = waiting else {
            return nil
        }
        waiting = nil
        return WindowPage(route: route, sceneID: id)
    }
}
