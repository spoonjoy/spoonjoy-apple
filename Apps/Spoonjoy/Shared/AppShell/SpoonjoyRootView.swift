import SpoonjoyCore
import SwiftUI

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

struct SpoonjoyRootView: View {
    @State private var navigation = AppNavigationState()
    @State private var search = SearchState()
    @State private var appSnapshot: NativeAppSnapshot

    private let router: DeepLinkRouter
    private let stateStore: NativeAppStateStore

    init(
        router: DeepLinkRouter = .spoonjoy,
        stateStore: NativeAppStateStore = Self.defaultStateStore()
    ) {
        self.router = router
        self.stateStore = stateStore
        let fallback = Self.bootstrapSnapshot()
        _appSnapshot = State(initialValue: (try? stateStore.loadOrCreate(fallback: fallback).value) ?? fallback)
    }

    var body: some View {
        rootContent
            .onOpenURL { url in
                applyURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    applyURL(url)
                }
            }
#if canImport(CoreSpotlight)
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    applySpotlightIdentifier(uniqueIdentifier)
                }
            }
#endif
    }

    @ViewBuilder private var rootContent: some View {
        if appSnapshot.hasCompletedFirstRun {
            PlatformNavigationView(
                navigation: $navigation,
                search: $search,
                appSnapshot: $appSnapshot,
                persistSnapshot: persistSnapshot
            )
        } else {
            SignedOutSetupView(
                openKitchen: { completeFirstRun(opening: .kitchen) },
                openCapture: { completeFirstRun(opening: .capture) },
                openSettings: { completeFirstRun(opening: .settings) }
            )
        }
    }

    private func applyURL(_ url: URL) {
        let route = router.route(for: url)
        persistOpening(route)
        search.apply(route: route)
        navigation.navigate(to: route)
    }

    private func applySpotlightIdentifier(_ uniqueIdentifier: String) {
        let route = SpotlightIndexPlan.route(uniqueIdentifier: uniqueIdentifier)
        persistOpening(route)
        search.apply(route: route)
        navigation.navigate(to: route)
    }

    private func completeFirstRun(opening route: AppRoute) {
        persistOpening(route)
        navigation.navigate(to: route)
    }

    private func persistOpening(_ route: AppRoute) {
        let savedAt = Self.timestamp()
        var nextSnapshot = appSnapshot
        if !nextSnapshot.hasCompletedFirstRun {
            nextSnapshot = nextSnapshot.completingFirstRun(savedAt: savedAt)
        }
        persistSnapshot(nextSnapshot.recordingOpenedRoute(route, savedAt: savedAt))
    }

    private func persistSnapshot(_ snapshot: NativeAppSnapshot) {
        appSnapshot = snapshot
        try? stateStore.save(snapshot)
    }

    private static func bootstrapSnapshot() -> NativeAppSnapshot {
        NativeAppSnapshot.bootstrap(
            shoppingList: try? ShoppingListState.decodeFromBundle(),
            savedAt: timestamp()
        )
    }

    private static func defaultStateStore() -> NativeAppStateStore {
        NativeAppStateStore(fileURL: NativeAppStateLocation.defaultFileURL())
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
