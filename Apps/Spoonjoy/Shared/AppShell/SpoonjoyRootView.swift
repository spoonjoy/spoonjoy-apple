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
                navigation.applyDeepLink(url, router: router)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    navigation.applyDeepLink(url, router: router)
                }
            }
    }
}
