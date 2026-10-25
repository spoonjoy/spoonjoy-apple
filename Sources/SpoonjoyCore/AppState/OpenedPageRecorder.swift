import Foundation

/// Decides when a window may save the page it moved to, whatever order launch events arrive in.
///
/// A link that launches the app arrives before either save is safe. The app's saved state belongs to the
/// signed-in chef, so it waits for the saved snapshot: saved earlier, it lands under "signed-out" and replaces
/// the chef's cook progress. The window's own page waits for the system to name the window: saved earlier, it
/// has no window to belong to, and the window reopens on its older page after a kill. Each save waits for its
/// own event and then saves the latest page.
public struct OpenedPageRecorder: Equatable, Sendable {
    public enum Save: Equatable, Sendable {
        /// The app's last page, kept with the chef's saved state.
        case appPage(AppRoute)
        /// This window's page, kept under the system's name for the window.
        case windowPage(AppRoute, sceneID: String)
    }

    private var sceneID: String?
    private var isSnapshotLoaded = false
    private var appPageWaiting: AppRoute?
    private var windowPageWaiting: AppRoute?

    public init() {}

    /// The window moved to `route`, by a link or by the chef.
    public mutating func opened(_ route: AppRoute) -> [Save] {
        var saves: [Save] = []
        if isSnapshotLoaded {
            saves.append(.appPage(route))
        } else {
            appPageWaiting = route
        }
        if SceneRestoration.remembers(route) {
            if let sceneID {
                saves.append(.windowPage(route, sceneID: sceneID))
            } else {
                windowPageWaiting = route
            }
        }
        return saves
    }

    /// The system named the window.
    public mutating func sceneIdentified(_ id: String) -> [Save] {
        sceneID = id
        guard let route = windowPageWaiting else {
            return []
        }
        windowPageWaiting = nil
        return [.windowPage(route, sceneID: id)]
    }

    /// The store has shown the state saved for the signed-in chef.
    public mutating func snapshotLoaded() -> [Save] {
        isSnapshotLoaded = true
        guard let route = appPageWaiting else {
            return []
        }
        appPageWaiting = nil
        return [.appPage(route)]
    }
}
