import Foundation
import SpoonjoyCore

/// Links from outside the app, and the page the app reopens on.
extension SpoonjoyReinsShell {
    /// A link opened from outside the app (a tapped URL, Spotlight), as SpoonjoyRootView's `applyURL` handles it: the
    /// router's page wins over the page the window would reopen on and becomes the app's last page. Cook mode
    /// tells the store it opened, as CookModeView's `.onAppear` does.
    public func openLink(_ url: URL) {
        let route = DeepLinkRouter.spoonjoy.route(for: url)
        move { $0.navigate(to: route) }
        if fixtures.restoresPages {
            store.recordingOpenedRoute(route)
        }
        if case .recipeDetail(let id, .cook) = route, content.recipe(id: id) != nil {
            store.cookModeOpened(recipeID: id)
        }
    }

    /// Saves a page worth reopening on as the app's last page (SpoonjoyRootView's `rememberWindowPage`).
    func rememberPage() {
        guard fixtures.restoresPages, SceneRestoration.remembers(navigation.route) else {
            return
        }
        store.recordingOpenedRoute(navigation.route)
    }

    /// At launch, the app's only window reopens on the app's last page (SpoonjoyRootView's
    /// `applyRestoredRouteIfNeeded`); cook mode reopens on the saved step its progress keeps.
    func applyRestoredRoute() {
        guard fixtures.restoresPages,
              navigation.route == .kitchen,
              store.bootstrapState.shellPresentation(isShowingSettings: false) == .kitchen,
              let route = SceneRestoration.route(scenePage: nil, windowValue: nil, appLastRoute: store.restoredRoute, isOnlyWindow: true) else {
            return
        }
        move { $0.navigate(to: route) }
        if case .recipeDetail(let id, .cook) = route, content.recipe(id: id) != nil {
            store.cookModeOpened(recipeID: id)
        }
    }
}
