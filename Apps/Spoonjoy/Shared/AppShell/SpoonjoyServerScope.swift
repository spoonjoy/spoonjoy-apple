import SpoonjoyCore
import SwiftUI

/// The iPhone and iPad app's one live store, made again when the cook chooses another server: the store's sign-in,
/// API calls, sync and caches are all built for one server (`SpoonjoyRootView.defaultDependencies()`).
@MainActor
final class SpoonjoyServerScopedStore: ObservableObject {
    @Published private(set) var liveStore: NativeLiveAppStore
    /// The server `liveStore` talks to; the windows' shells are keyed by it, so each starts over on a new one.
    @Published private(set) var serverBaseURL: URL
    private var observer: NSObjectProtocol?

    init() {
        liveStore = NativeLiveAppStore(dependencies: SpoonjoyRootView.defaultDependencies())
        serverBaseURL = SpoonjoyAppServer.configuration().baseURL
        observer = NotificationCenter.default.addObserver(forName: SpoonjoyAppServer.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reconnect()
            }
        }
    }

    private func reconnect() {
        liveStore = NativeLiveAppStore(dependencies: SpoonjoyRootView.defaultDependencies())
        serverBaseURL = SpoonjoyAppServer.configuration().baseURL
    }
}

/// A Mac window's shell, made again when the cook chooses another server; each Mac window builds its own store.
struct SpoonjoyServerScopedRoot<Content: View>: View {
    @State private var serverBaseURL = SpoonjoyAppServer.configuration().baseURL
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .id(serverBaseURL)
            .onReceive(NotificationCenter.default.publisher(for: SpoonjoyAppServer.didChange)) { _ in
                serverBaseURL = SpoonjoyAppServer.configuration().baseURL
            }
    }
}
