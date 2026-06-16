import SpoonjoyCore
import SwiftUI

struct SpoonjoyRootView: View {
    @State private var navigation = AppNavigationState()
    @State private var search = SearchState()

    private let router: DeepLinkRouter

    init(router: DeepLinkRouter = .spoonjoy) {
        self.router = router
    }

    var body: some View {
        PlatformNavigationView(navigation: $navigation, search: $search)
            .onOpenURL { url in
                applyURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    applyURL(url)
                }
            }
    }

    private func applyURL(_ url: URL) {
        let route = router.route(for: url)
        search.apply(route: route)
        navigation.navigate(to: route)
    }
}
