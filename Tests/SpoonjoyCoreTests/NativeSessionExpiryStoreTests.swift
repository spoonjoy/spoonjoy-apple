import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native live store session expiry")
struct NativeSessionExpiryStoreTests {
    private static let now = Date(timeIntervalSince1970: 1_780_010_000)

    private enum RefreshOutcome: Sendable {
        case invalidGrant
        case offline
        case serverError
        case success
    }

    private actor RefreshScript {
        private var outcomes: [RefreshOutcome]
        private(set) var clientIDs: [String] = []

        init(_ outcomes: [RefreshOutcome]) {
            self.outcomes = outcomes
        }

        func next(clientID: String) throws -> OAuthTokenResponse {
            clientIDs.append(clientID)
            let outcome = outcomes.count > 1 ? outcomes.removeFirst() : (outcomes.first ?? .success)
            switch outcome {
            case .invalidGrant:
                throw APITransportError(
                    kind: .apiError,
                    requestID: nil,
                    statusCode: 400,
                    apiError: APIError(
                        requestID: "unknown",
                        code: "oauth_http_status_400",
                        message: "Refresh token was issued to a different client",
                        status: 400
                    ),
                    retryDecision: .doNotRetry
                )
            case .offline:
                throw APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
            case .serverError:
                throw APITransportError(
                    kind: .apiError,
                    requestID: "req_503",
                    statusCode: 503,
                    apiError: APIError(requestID: "req_503", code: "unavailable", message: "Try later", status: 503),
                    retryDecision: .doNotRetry
                )
            case .success:
                return OAuthTokenResponse(
                    accessToken: "sj_access_refreshed",
                    refreshToken: "sj_refresh_refreshed",
                    tokenType: "Bearer",
                    expiresIn: 3_600,
                    scope: NativeAuthSession.defaultScope
                )
            }
        }
    }

    private struct EmptyTransport: NativeSyncTransport {
        func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
            .success(cursor: nil, tombstones: [])
        }

        func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
            .success(serverRevision: .updatedAt(mutation.createdAt))
        }
    }

    private static func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-session-expiry-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func recipe(id: String) -> Recipe {
        let url = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        let stamp = ISO8601DateFormatter().string(from: now)
        return Recipe(
            id: id,
            title: "Cached \(id)",
            description: "Cached for the test.",
            servings: "2",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: url,
            attribution: RecipeAttribution(
                creditText: "By ari",
                canonicalURL: url,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: stamp,
            updatedAt: stamp,
            steps: [RecipeStep(id: "step_\(id)", stepNum: 1, stepTitle: "Cook", description: "Cook.", duration: 5, ingredients: [])],
            cookbooks: [],
            recentSpoons: []
        )
    }

    private struct Fixture {
        let directory: URL
        let vault: InMemoryTokenVault
        let script: RefreshScript
        let store: NativeLiveAppStore
        let appStateStore: NativeAppStateStore
    }

    @MainActor
    private static func fixture(
        outcomes: [RefreshOutcome],
        cachedRecipeIDs: [String] = ["recipe_cached"],
        lastOpenedRoute: AppRoute? = nil,
        checkpointUpdatedAt: String? = nil,
        wallClockNow: Bool = false,
        bootstrapMode: NativeLiveAppBootstrapMode = .liveFirst
    ) async throws -> Fixture {
        let directory = try directory()
        let vault = InMemoryTokenVault()
        try await vault.saveClientID(NativeAuthSession.nativeAppClientID)
        try await vault.saveSession(try AuthSession(
            clientID: NativeAuthSession.nativeAppClientID,
            accessToken: "sj_access_expired",
            refreshToken: "sj_refresh_dead",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(-60),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        ))
        let script = RefreshScript(outcomes)
        let fixedNow = Self.now
        let clock: @Sendable () -> Date
        if wallClockNow {
            clock = { Date() }
        } else {
            clock = { fixedNow }
        }
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple Tests",
            registerClient: { _, _ in "client_live" },
            exchangeCode: { _, _, _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            refresh: { clientID, _ in try await script.next(clientID: clientID) },
            revoke: { _, _ in },
            now: clock
        )
        let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
        if let lastOpenedRoute {
            try appStateStore.save(
                NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "chef_ari",
                    environment: .production,
                    savedAt: ISO8601DateFormatter().string(from: now)
                ).recordingOpenedRoute(lastOpenedRoute, savedAt: ISO8601DateFormatter().string(from: now))
            )
        }
        let checkpoint = try checkpointUpdatedAt.map {
            try NativeSyncCheckpoint(globalCursor: nil, shoppingCursor: nil, updatedAt: $0)
        }
        let syncStore = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .production,
            checkpoint: checkpoint,
            queue: NativeMutationQueue(),
            cachedRecords: try cachedRecipeIDs.map { id in
                let recipe = recipe(id: id)
                return NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: id,
                    payload: try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(recipe)),
                    serverRevision: .updatedAt(recipe.updatedAt)
                )
            }
        )
        let engine = NativeSyncEngine(store: syncStore, transport: EmptyTransport(), clock: clock)
        let configuration = APIClientConfiguration.spoonjoyProduction
        let store = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
            authSessionRepository: repository,
            cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
            syncStore: syncStore,
            syncEngine: engine,
            syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
            appStateStoreProvider: { appStateStore },
            configuration: configuration,
            cacheEnvironment: .production,
            bootstrapMode: bootstrapMode,
            now: clock
        ))
        return Fixture(directory: directory, vault: vault, script: script, store: store, appStateStore: appStateStore)
    }

    // MARK: Permanent failure

    @MainActor
    @Test("invalid_grant shows the cached kitchen, signed out everywhere, and offers sign-in")
    func invalidGrantShowsCachedKitchenSignedOut() async throws {
        let fixture = try await Self.fixture(outcomes: [.invalidGrant])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .offlineStale(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the cached kitchen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.recipes.map(\.id) == ["recipe_cached"])
        #expect(content.authSessionState == .signedOut)
        #expect(content.configuration.bearerToken == nil)
        #expect(content.settingsSurfaceViewModel.primaryAuthAction != nil)
        #expect(content.offlineIndicatorState.display == .stale(domain: .accountBootstrap))
        // The expired session stays stored, so nothing the chef cached is orphaned.
        #expect(try await fixture.vault.loadSession()?.accountID == "chef_ari")

        // A second launch does not hit the network again for the same dead token.
        await fixture.store.bootstrap()
        #expect(await fixture.script.clientIDs.count == 1)
        guard case .offlineStale(let again) = fixture.store.bootstrapState else {
            Issue.record("Expected the cached kitchen on the second launch")
            return
        }
        #expect(again.authSessionState == .signedOut)
    }

    @MainActor
    @Test("invalid_grant with nothing cached falls back to the sign-in screen, not an error")
    func invalidGrantWithoutCacheShowsSignIn() async throws {
        let fixture = try await Self.fixture(outcomes: [.invalidGrant], cachedRecipeIDs: [])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .signedOut(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the sign-in state, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.authSessionState == .signedOut)
        #expect(content.recipes.isEmpty)
    }

    // MARK: Transient failure

    @MainActor
    @Test("a server error keeps the session and the cached kitchen, and a retry recovers")
    func serverErrorKeepsSessionAndRetries() async throws {
        let fixture = try await Self.fixture(outcomes: [.serverError, .success])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .syncFailed(let content, _) = fixture.store.bootstrapState else {
            Issue.record("Expected a retryable failure, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.recipes.map(\.id) == ["recipe_cached"])
        #expect(content.authSessionState != .signedOut)
        #expect(try await fixture.vault.loadSession()?.refreshToken == "sj_refresh_dead")

        await fixture.store.bootstrap()
        guard case .liveSynced(let synced) = fixture.store.bootstrapState else {
            Issue.record("Expected the retry to sync, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(synced.authSessionState != .signedOut)
        #expect(try await fixture.vault.loadSession()?.refreshToken == "sj_refresh_refreshed")
    }

    @MainActor
    @Test("a relaunch with no network shows the cached kitchen under the stored account")
    func offlineRelaunchShowsCachedKitchen() async throws {
        let fixture = try await Self.fixture(outcomes: [.offline])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .offlineStale(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the offline kitchen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.recipes.map(\.id) == ["recipe_cached"])
        #expect(content.authSessionState != .signedOut)
        #expect(try await fixture.vault.loadSession() != nil)
    }

    // MARK: Restored routes

    @MainActor
    @Test("a restored editor route is dropped, and a restored recipe that is cached is kept")
    func restoredRoutesAreValidated() async throws {
        let editor = try await Self.fixture(outcomes: [.success], lastOpenedRoute: .recipeEditor(id: nil))
        defer { try? FileManager.default.removeItem(at: editor.directory) }
        await editor.store.bootstrap()
        #expect(editor.store.restoredRoute == nil)

        let detail = try await Self.fixture(
            outcomes: [.success],
            lastOpenedRoute: .recipeDetail(id: "recipe_cached", presentation: .detail)
        )
        defer { try? FileManager.default.removeItem(at: detail.directory) }
        await detail.store.bootstrap()
        #expect(detail.store.restoredRoute == .recipeDetail(id: "recipe_cached", presentation: .detail))

        let missing = try await Self.fixture(
            outcomes: [.success],
            lastOpenedRoute: .recipeDetail(id: "recipe_deleted", presentation: .detail)
        )
        defer { try? FileManager.default.removeItem(at: missing.directory) }
        await missing.store.bootstrap()
        #expect(missing.store.restoredRoute == nil)
    }

    // MARK: Sync age

    @MainActor
    @Test("Settings is not called out of date right after a live sync")
    func settingsFreshAfterLiveSync() async throws {
        let fixture = try await Self.fixture(outcomes: [.success], wallClockNow: true)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .liveSynced(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected a live sync, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.lastSyncedAt != nil)
        #expect(content.settingsSurfaceViewModel.offlineIndicator.display == .synced)
    }

    @MainActor
    @Test("a saved kitchen is out of date only by its real sync age")
    func savedKitchenAgeComesFromTheCheckpoint() async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Both launches are online (the server answers, with an error), so Settings judges the saved
        // kitchen by the age of its last sync alone.
        let recent = try await Self.fixture(
            outcomes: [.serverError],
            checkpointUpdatedAt: formatter.string(from: Date().addingTimeInterval(-60)),
            wallClockNow: true
        )
        defer { try? FileManager.default.removeItem(at: recent.directory) }
        await recent.store.bootstrap()
        let recentContent = recent.store.bootstrapState.contentState
        #expect(recentContent.lastSyncedAt != nil)
        #expect(recentContent.settingsSurfaceViewModel.offlineIndicator.display == .synced)

        let old = try await Self.fixture(
            outcomes: [.serverError],
            checkpointUpdatedAt: formatter.string(from: Date().addingTimeInterval(-3_600)),
            wallClockNow: true
        )
        defer { try? FileManager.default.removeItem(at: old.directory) }
        await old.store.bootstrap()
        #expect(old.store.bootstrapState.contentState.settingsSurfaceViewModel.offlineIndicator.display == .stale(domain: .settings))
    }
}
