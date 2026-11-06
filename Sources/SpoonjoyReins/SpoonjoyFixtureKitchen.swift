import Foundation
import SpoonjoyCore

/// The screenshot fixture kitchen (account `chef_kitchen_capture`, cache only), as `scripts/check-motion.sh` seeds it into
/// a simulator for the motion and navigation UI tests. The three files in `Fixtures/kitchen` were written by the same
/// seeding functions (`write_app_state`, `write_cache_state`, `write_sync_store` in scripts/capture-native-screenshots.sh),
/// so a headless journey and its XCUITest twin start from the same kitchen.
///
/// Every outside dependency comes in through `NativeLiveAppStoreDependencies`' constructor. The sync and cook-session
/// clients are the production URLSession ones on purpose: under `ReinsNetworkGuard` any request they make is caught,
/// so a journey proves it needs no network instead of assuming it.
public enum SpoonjoyFixtureKitchen {
    public static let accountID = "chef_kitchen_capture"

    /// Copies the fixture kitchen into a fresh folder, so each journey starts from the same bytes.
    public static func copy(to directory: URL) throws {
        guard let source = Bundle.module.url(forResource: "kitchen", withExtension: nil, subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Fixtures/kitchen is missing from the bundle"])
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["native-app-state.json", "native-durable-cache.json", "native-sync-store.json"] {
            try FileManager.default.copyItem(at: source.appendingPathComponent(name), to: directory.appendingPathComponent(name))
        }
    }

    /// A live store over the fixture kitchen in `directory`, as the app builds it with SPOONJOY_SCREENSHOT_AUTH=1 and
    /// SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 (SpoonjoyRootView.defaultDependencies). `bootstrapMode` defaults to the
    /// cache-only restore the UI tests use; `.liveFirst` is the negative control that shows the guard sees real traffic.
    @MainActor
    public static func store(
        in directory: URL,
        bootstrapMode: NativeLiveAppBootstrapMode = .restoreCacheOnly,
        fixtures: SpoonjoyReinsFixtures = SpoonjoyReinsFixtures()
    ) throws -> NativeLiveAppStore {
        let now = fixtures.now
        let configuration = APIClientConfiguration.spoonjoyProduction
        let vault = FixtureTokenVault(session: try AuthSession(
            clientID: "cm_screenshot_validation",
            accessToken: "screenshot_access_token",
            refreshToken: "screenshot_refresh_token",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000),
            scope: NativeAuthSession.defaultScope,
            accountID: accountID
        ))
        let auth = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Reins",
            registerClient: { _, _ in throw FixtureKitchenError.notInFixture("client registration") },
            exchangeCode: { _, _, _, _ in throw FixtureKitchenError.notInFixture("sign-in") },
            refresh: { _, _ in throw FixtureKitchenError.notInFixture("token refresh") },
            revoke: { _, _ in },
            now: now
        )
        let syncStore = try FileBackedNativeSyncStore(fileURL: directory.appendingPathComponent("native-sync-store.json"))
        let engine = NativeSyncEngine(store: syncStore, transport: URLSessionNativeSyncTransport(), clock: now)
        let appState = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
        return NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
            authSessionRepository: auth,
            cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("native-durable-cache.json")),
            syncStore: syncStore,
            syncEngine: engine,
            syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
            appStateStoreProvider: { appState },
            configuration: configuration,
            cacheEnvironment: .production,
            recipeEditorAPITransport: fixtures.apiTransport ?? { URLSessionAPITransport(authenticationRefresher: $0) },
            settingsSurfaceFetch: fixtures.settingsSurfaceFetch,
            bootstrapMode: bootstrapMode,
            now: now
        ))
    }
}

public enum FixtureKitchenError: Error, CustomStringConvertible {
    case notInFixture(String)
    public var description: String {
        switch self {
        case .notInFixture(let what): "\(what) isn't part of the fixture kitchen; inject a fixture for it"
        }
    }
}

/// The signed-in session the screenshot builds use (SpoonjoyRootView's SpoonjoyScreenshotValidationTokenVault).
actor FixtureTokenVault: TokenVault {
    private var clientID: String? = "cm_screenshot_validation"
    private var session: AuthSession?

    init(session: AuthSession) { self.session = session }

    func loadClientID() async throws -> String? { clientID }
    func saveClientID(_ clientID: String) async throws { self.clientID = clientID }
    func clearClientID() async throws { clientID = nil }
    func loadSession() async throws -> AuthSession? { session }
    func saveSession(_ session: AuthSession) async throws { self.session = session }
    func clearSession() async throws { session = nil }
}
