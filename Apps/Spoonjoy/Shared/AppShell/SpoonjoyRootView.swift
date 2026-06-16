import SpoonjoyCore
import SwiftUI

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
        if !appSnapshot.hasCompletedFirstRun {
            persistSnapshot(appSnapshot.completingFirstRun(savedAt: Self.timestamp()))
        }
        search.apply(route: route)
        navigation.navigate(to: route)
    }

    private func completeFirstRun(opening route: AppRoute) {
        persistSnapshot(appSnapshot.completingFirstRun(savedAt: Self.timestamp()))
        navigation.navigate(to: route)
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
        NativeAppStateStore(fileURL: defaultStateURL())
    }

    private static func defaultStateURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("Spoonjoy", isDirectory: true)
            .appendingPathComponent("native-app-state.json")
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
