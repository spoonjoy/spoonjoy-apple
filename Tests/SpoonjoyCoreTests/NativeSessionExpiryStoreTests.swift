import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native live store session expiry")
struct NativeSessionExpiryStoreTests {
    private static let now = Date(timeIntervalSince1970: 1_780_010_000)

    private enum RefreshOutcome: Sendable {
        case invalidGrant
        case revoked
        case htmlForbidden
        case notFound
        case payloadTooLarge
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

        /// What the app builds from a JSON RFC 6749 body.
        static func oauthRefusal(status: Int, code: String, reason: String?) -> APITransportError {
            OAuthErrorResponse.transportError(
                statusCode: status,
                isJSON: true,
                data: Data(
                    ("{\"error\":\"\(code)\",\"error_description\":\"refused\""
                        + (reason.map { ",\"reason\":\"\($0)\"" } ?? "") + "}").utf8
                ),
                requestID: "req_refusal",
                retryAfterSeconds: nil
            )!
        }

        /// What the app builds from a proxy's HTML or an empty error page.
        static func genericRefusal(status: Int) -> APITransportError {
            APITransportError(
                kind: .nonJSONResponse,
                requestID: "req_generic",
                statusCode: status,
                apiError: APIError(
                    requestID: "req_generic",
                    code: "oauth_http_status_\(status)",
                    message: "OAuth request failed with HTTP \(status).",
                    status: status
                ),
                retryDecision: .doNotRetry
            )
        }

        func next(clientID: String) throws -> OAuthTokenResponse {
            clientIDs.append(clientID)
            let outcome = outcomes.count > 1 ? outcomes.removeFirst() : (outcomes.first ?? .success)
            switch outcome {
            case .invalidGrant:
                throw Self.oauthRefusal(status: 400, code: "invalid_grant", reason: nil)
            case .revoked:
                throw Self.oauthRefusal(status: 400, code: "invalid_grant", reason: OAuthErrorResponse.userRevokedReason)
            case .htmlForbidden:
                throw Self.genericRefusal(status: 403)
            case .notFound:
                throw Self.genericRefusal(status: 404)
            case .payloadTooLarge:
                throw Self.genericRefusal(status: 413)
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

    /// Lets a test make the sync itself fail the way the API refresher does when the session dies mid-sync.
    private final class FailureSwitch: @unchecked Sendable {
        private let lock = NSLock()
        private var error: Error?

        func set(_ error: Error?) {
            lock.lock()
            defer { lock.unlock() }
            self.error = error
        }

        func current() -> Error? {
            lock.lock()
            defer { lock.unlock() }
            return error
        }
    }

    private struct EmptyTransport: NativeSyncTransport {
        let failure: FailureSwitch

        func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
            if let error = failure.current() {
                throw error
            }
            return .success(cursor: nil, tombstones: [])
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
        let syncStore: any NativeSyncStore
        let failure: FailureSwitch
        let cacheStore: NativeDurableCacheStore
    }

    @MainActor
    private static func fixture(
        outcomes: [RefreshOutcome],
        cachedRecipeIDs: [String] = ["recipe_cached"],
        lastOpenedRoute: AppRoute? = nil,
        checkpointUpdatedAt: String? = nil,
        wallClockNow: Bool = false,
        bootstrapMode: NativeLiveAppBootstrapMode = .liveFirst,
        queuedMutations: [NativeQueuedMutation] = [],
        fileBackedSync: Bool = false,
        unreadableCache: Bool = false,
        unreadableSync: Bool = false
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
        let seededRecords = try cachedRecipeIDs.map { id in
            let recipe = recipe(id: id)
            return NativeSyncCachedRecord(
                kind: .recipe,
                resourceID: id,
                payload: try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(recipe)),
                serverRevision: .updatedAt(recipe.updatedAt)
            )
        }
        let seededQueue = try NativeMutationQueue(mutations: queuedMutations)
        var syncStore: any NativeSyncStore
        if fileBackedSync {
            syncStore = try FileBackedNativeSyncStore(
                fileURL: directory.appendingPathComponent("sync.json"),
                fallback: NativeSyncSnapshot(
                    accountID: "chef_ari",
                    environment: .production,
                    checkpoint: checkpoint,
                    queue: seededQueue,
                    cachedRecords: seededRecords
                )
            )
        } else {
            syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: checkpoint,
                queue: seededQueue,
                cachedRecords: seededRecords
            )
        }
        if unreadableSync {
            syncStore = UnreadableSnapshotSyncStore()
        }
        let failure = FailureSwitch()
        let engine = NativeSyncEngine(store: syncStore, transport: EmptyTransport(failure: failure), clock: clock)
        let configuration = APIClientConfiguration.spoonjoyProduction
        // An unreadable cache sits under a regular file, so every read and write of it fails.
        let cacheDirectory: URL
        if unreadableCache {
            cacheDirectory = directory.appendingPathComponent("not-a-directory")
            try Data("blocked".utf8).write(to: cacheDirectory)
        } else {
            cacheDirectory = directory
        }
        let cacheStore = NativeDurableCacheStore(fileURL: cacheDirectory.appendingPathComponent("cache.json"))
        let store = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
            authSessionRepository: repository,
            cacheStore: cacheStore,
            syncStore: syncStore,
            syncEngine: engine,
            syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
            appStateStoreProvider: { appStateStore },
            configuration: configuration,
            cacheEnvironment: .production,
            bootstrapMode: bootstrapMode,
            now: clock
        ))
        return Fixture(
            directory: directory,
            vault: vault,
            script: script,
            store: store,
            appStateStore: appStateStore,
            syncStore: syncStore,
            failure: failure,
            cacheStore: cacheStore
        )
    }

    /// A second app process over the same files and Keychain: new store objects, nothing shared in memory.
    @MainActor
    private static func relaunched(from fixture: Fixture) async throws -> (store: NativeLiveAppStore, syncStore: FileBackedNativeSyncStore) {
        let fixedNow = Self.now
        let clock: @Sendable () -> Date = { fixedNow }
        let script = RefreshScript([.success])
        let repository = NativeAuthSessionRepository(
            vault: fixture.vault,
            clientName: "Spoonjoy Apple Tests",
            registerClient: { _, _ in "client_live" },
            exchangeCode: { _, _, _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            refresh: { clientID, _ in try await script.next(clientID: clientID) },
            revoke: { _, _ in },
            now: clock
        )
        let syncStore = try FileBackedNativeSyncStore(fileURL: fixture.directory.appendingPathComponent("sync.json"))
        let appStateStore = NativeAppStateStore(fileURL: fixture.directory.appendingPathComponent("native-app-state.json"))
        let engine = NativeSyncEngine(store: syncStore, transport: EmptyTransport(failure: FailureSwitch()), clock: clock)
        let configuration = APIClientConfiguration.spoonjoyProduction
        let store = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
            authSessionRepository: repository,
            cacheStore: NativeDurableCacheStore(fileURL: fixture.directory.appendingPathComponent("cache.json")),
            syncStore: syncStore,
            syncEngine: engine,
            syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
            appStateStoreProvider: { appStateStore },
            configuration: configuration,
            cacheEnvironment: .production,
            now: clock
        ))
        return (store, syncStore)
    }

    // MARK: Permanent failure

    private static func assertKeepsAccountScope(_ content: NativeShellContentState) {
        guard case .refreshRequired(let session) = content.authSessionState else {
            Issue.record("Expected the stored session to keep its scope, got \(content.authSessionState)")
            return
        }
        #expect(session.accountID == "chef_ari")
        #expect(content.isSessionExpired)
        #expect(content.configuration.bearerToken == nil)
    }

    @MainActor
    @Test("invalid_grant shows the cached kitchen under the stored account and offers sign-in")
    func invalidGrantShowsCachedKitchenUnderStoredAccount() async throws {
        let fixture = try await Self.fixture(outcomes: [.invalidGrant])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .offlineStale(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the cached kitchen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.recipes.map(\.id) == ["recipe_cached"])
        Self.assertKeepsAccountScope(content)
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
        Self.assertKeepsAccountScope(again)
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
        Self.assertKeepsAccountScope(content)
        #expect(content.recipes.isEmpty)
    }

    @MainActor
    @Test("invalid_grant with an unreadable cache still lands on sign-in under the stored account")
    func invalidGrantWithUnreadableCacheShowsSignIn() async throws {
        // Launch also shows recipes saved in the sync store, so that store is unreadable too: this launch can
        // find no saved kitchen anywhere.
        let fixture = try await Self.fixture(outcomes: [.invalidGrant], cachedRecipeIDs: [], unreadableCache: true, unreadableSync: true)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .signedOut(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the sign-in state, got \(fixture.store.bootstrapState)")
            return
        }
        Self.assertKeepsAccountScope(content)
        #expect(content.recipes.isEmpty)
    }

    @MainActor
    @Test("a revocation with an unreadable cache still signs out with an empty kitchen")
    func revocationWithUnreadableCacheSignsOut() async throws {
        let fixture = try await Self.fixture(outcomes: [.revoked], unreadableCache: true, unreadableSync: true)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .signedOut(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the sign-in state, got \(fixture.store.bootstrapState)")
            return
        }
        guard case .signedOut = content.authSessionState else {
            Issue.record("Expected a revoked session to leave no account scope, got \(content.authSessionState)")
            return
        }
        #expect(!content.isSessionExpired)
        #expect(content.recipes.isEmpty)
    }

    @MainActor
    @Test("editing while the session is expired keeps the chef's snapshot, queue and drafts")
    func editingWhileExpiredKeepsTheChefsData() async throws {
        let existing = NativeQueuedMutation.shoppingAddItem(
            name: "limes",
            quantity: 1,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_before_expiry",
            createdAt: "2026-06-16T11:00:00.000Z"
        )
        let fixture = try await Self.fixture(
            outcomes: [.invalidGrant],
            queuedMutations: [existing]
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        await fixture.store.bootstrap()
        Self.assertKeepsAccountScope(fixture.store.bootstrapState.contentState)

        // Edits made after the session expired: a queued shopping edit, an opened route, a draft.
        let added = NativeQueuedMutation.shoppingAddItem(
            name: "lemons",
            quantity: 2,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_after_expiry",
            createdAt: "2026-06-16T12:00:00.000Z"
        )
        try await fixture.store.queueMutation(added)
        fixture.store.recordingOpenedRoute(.recipeDetail(id: "recipe_cached", presentation: .detail))
        let draft = CaptureDraft(
            id: "draft_while_expired",
            source: .text,
            rawText: "two eggs, a cup of flour",
            imageAssetIdentifier: nil,
            createdAt: "2026-06-16T12:01:00.000Z"
        )
        fixture.store.recordCaptureDraft(draft)

        // The chef's snapshot is still the chef's, and the queue holds both edits.
        let snapshot = try await fixture.syncStore.loadSnapshot()
        #expect(snapshot.accountID == "chef_ari")
        let queue = try await fixture.syncStore.loadQueue()
        #expect(queue.mutations.map(\.clientMutationID) == ["cm_before_expiry", "cm_after_expiry"])
        let appSnapshot = try fixture.appStateStore.loadOrCreate(fallback: NativeAppSnapshot.bootstrap(
            shoppingList: nil,
            accountID: "signed-out",
            environment: .production,
            savedAt: "2026-06-16T12:02:00.000Z"
        )).value
        #expect(appSnapshot.accountID == "chef_ari")
        #expect(appSnapshot.captureDraft?.id == "draft_while_expired")
        #expect(appSnapshot.lastOpenedRoute != nil)

        // Nothing was saved under the signed-out scope, and the screen still shows the chef's work.
        let content = fixture.store.bootstrapState.contentState
        Self.assertKeepsAccountScope(content)
        #expect(content.recipes.map(\.id) == ["recipe_cached"])
        #expect(content.queuedMutations.map(\.clientMutationID).contains("cm_after_expiry"))
        #expect(content.captureDraft?.id == "draft_while_expired")

        // A relaunch while still expired restores the same work.
        await fixture.store.bootstrap()
        let relaunched = fixture.store.bootstrapState.contentState
        Self.assertKeepsAccountScope(relaunched)
        #expect(relaunched.queuedMutations.count == 2)
        #expect(relaunched.captureDraft?.id == "draft_while_expired")
        #expect(try await fixture.syncStore.loadQueue().mutations.count == 2)
    }

    @MainActor
    @Test("an expiry raised by the sync itself, after the refresh, is handled the same way")
    func expiryRaisedDuringSyncKeepsTheKitchen() async throws {
        let fixture = try await Self.fixture(outcomes: [.success])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        fixture.failure.set(TokenRefreshError.sessionExpired)

        await fixture.store.bootstrap()

        guard case .offlineStale(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the cached kitchen with the sign-in banner, got \(fixture.store.bootstrapState)")
            return
        }
        Self.assertKeepsAccountScope(content)
        #expect(content.recipes.map(\.id) == ["recipe_cached"])
    }

    @MainActor
    @Test("an expiry found while switching environment shows the sign-in banner")
    func expiryDuringEnvironmentSwitchShowsTheBanner() async throws {
        let fixture = try await Self.fixture(outcomes: [.success])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        await fixture.store.bootstrap()
        guard case .liveSynced(let synced) = fixture.store.bootstrapState else {
            Issue.record("Expected the first sync to work, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(!synced.isSessionExpired)

        fixture.failure.set(TokenRefreshError.sessionExpired)
        await fixture.store.switchEnvironment(.production)

        let content = fixture.store.bootstrapState.contentState
        #expect(content.isSessionExpired)
        guard case .refreshRequired(let session) = content.authSessionState else {
            Issue.record("Expected the stored scope, got \(content.authSessionState)")
            return
        }
        #expect(session.accountID == "chef_ari")
    }

    @MainActor
    @Test("a revocation found while switching environment wipes the device")
    func revocationDuringEnvironmentSwitchWipesTheDevice() async throws {
        let fixture = try await Self.fixture(outcomes: [.success])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        await fixture.store.bootstrap()

        fixture.failure.set(TokenRefreshError.sessionRevoked)
        await fixture.store.switchEnvironment(.production)

        guard case .signedOut(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the sign-in screen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.recipes.isEmpty)
        #expect(try await fixture.vault.loadSession() == nil)
    }

    @MainActor
    @Test("a sign-in after an expiry clears the banner")
    func signInAfterExpiryClearsTheBanner() async throws {
        let fixture = try await Self.fixture(outcomes: [.invalidGrant, .success])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        await fixture.store.bootstrap()
        #expect(fixture.store.bootstrapState.contentState.isSessionExpired)

        // A new sign-in is a new refresh token in the vault.
        try await fixture.vault.saveSession(try AuthSession(
            clientID: NativeAuthSession.nativeAppClientID,
            accessToken: "sj_access_signed_in",
            refreshToken: "sj_refresh_signed_in",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(3_600),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        ))
        await fixture.store.bootstrap()

        guard case .liveSynced(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected a live sync after signing in, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(!content.isSessionExpired)
    }

    // MARK: Revoked on purpose

    @MainActor
    @Test("a session the chef revoked on purpose empties every store on the device, and a relaunch finds nothing")
    func revokedSessionWipesTheDevice() async throws {
        let queued = NativeQueuedMutation.shoppingAddItem(
            name: "limes",
            quantity: 1,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_revoked",
            createdAt: "2026-06-16T11:00:00.000Z"
        )
        let fixture = try await Self.fixture(outcomes: [.success], queuedMutations: [queued], fileBackedSync: true)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        // A signed-in chef with a synced kitchen, a queued edit, a draft and a restored route on disk.
        try fixture.cacheStore.save(try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: "chef_ari",
            environment: .production,
            createdAt: Self.now,
            records: [],
            dismissedIndicators: []
        ))
        await fixture.store.bootstrap()
        fixture.store.recordCaptureDraft(CaptureDraft(
            id: "draft_before_revoke",
            source: .text,
            rawText: "two eggs",
            imageAssetIdentifier: nil,
            createdAt: "2026-06-16T12:01:00.000Z"
        ))
        fixture.store.recordingOpenedRoute(.recipeDetail(id: "recipe_cached", presentation: .detail))
        let cacheFile = fixture.directory.appendingPathComponent("cache.json")
        let appStateFile = fixture.directory.appendingPathComponent("native-app-state.json")
        let syncFile = fixture.directory.appendingPathComponent("sync.json")
        #expect(try String(contentsOf: cacheFile, encoding: .utf8).contains("chef_ari"))
        #expect(try String(contentsOf: appStateFile, encoding: .utf8).contains("draft_before_revoke"))
        #expect(try String(contentsOf: syncFile, encoding: .utf8).contains("cm_revoked"))

        // The server now says the chef revoked this session on purpose.
        fixture.failure.set(TokenRefreshError.sessionRevoked)
        await fixture.store.bootstrap()

        guard case .signedOut(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the sign-in screen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.authSessionState == .signedOut)
        #expect(!content.isSessionExpired)
        #expect(content.recipes.isEmpty)
        #expect(content.queuedMutations.isEmpty)
        #expect(content.captureDraft == nil)
        #expect(try await fixture.vault.loadSession() == nil)
        #expect(try await fixture.vault.loadClientID() == nil)

        // The stores themselves are empty, not just filtered from view.
        #expect(try await fixture.syncStore.loadQueue().mutations.isEmpty)
        let snapshot = try await fixture.syncStore.loadSnapshot()
        #expect(snapshot.accountID == nil)
        #expect(snapshot.cachedRecords.isEmpty)
        #expect(snapshot.checkpoint == nil)
        let files = try [cacheFile, appStateFile, syncFile].map { try String(contentsOf: $0, encoding: .utf8) }
        for text in files {
            #expect(!text.contains("recipe_cached"))
            #expect(!text.contains("chef_ari"))
            #expect(!text.contains("cm_revoked"))
            #expect(!text.contains("draft_before_revoke"))
        }

        // A fresh app process over the same files has nothing to restore.
        let relaunch = try await Self.relaunched(from: fixture)
        await relaunch.store.bootstrap()
        guard case .signedOut(let again) = relaunch.store.bootstrapState else {
            Issue.record("Expected the sign-in screen on relaunch, got \(relaunch.store.bootstrapState)")
            return
        }
        #expect(again.recipes.isEmpty)
        #expect(again.queuedMutations.isEmpty)
        #expect(again.captureDraft == nil)
        #expect(try await relaunch.syncStore.loadQueue().mutations.isEmpty)

        // The same chef signing back in does not get the old edits back, and nothing drains to the server.
        try await fixture.vault.saveSession(try AuthSession(
            clientID: NativeAuthSession.nativeAppClientID,
            accessToken: "sj_access_new_sign_in",
            refreshToken: "sj_refresh_new_sign_in",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(3_600),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        ))
        let signedBackIn = try await Self.relaunched(from: fixture)
        await signedBackIn.store.bootstrap()
        let restored = signedBackIn.store.bootstrapState.contentState
        #expect(restored.queuedMutations.isEmpty)
        #expect(!restored.recipes.map(\.id).contains("recipe_cached"))
        #expect(try await signedBackIn.syncStore.loadQueue().mutations.isEmpty)
    }

    @MainActor
    @Test("an expired chef with queued edits but no cached recipes keeps the kitchen, not the sign-in screen")
    func expiredChefWithOnlyQueuedWorkKeepsTheWork() async throws {
        let queued = NativeQueuedMutation.shoppingAddItem(
            name: "limes",
            quantity: 1,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_only_queued",
            createdAt: "2026-06-16T11:00:00.000Z"
        )
        let fixture = try await Self.fixture(outcomes: [.invalidGrant], cachedRecipeIDs: [], queuedMutations: [queued])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.bootstrap()

        guard case .offlineStale(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the kitchen with the sign-in banner, got \(fixture.store.bootstrapState)")
            return
        }
        Self.assertKeepsAccountScope(content)
        #expect(content.queuedMutations.map(\.clientMutationID) == ["cm_only_queued"])
    }

    @MainActor
    @Test("an expired chef with only a capture draft keeps the kitchen, not the sign-in screen")
    func expiredChefWithOnlyADraftKeepsTheWork() async throws {
        let fixture = try await Self.fixture(outcomes: [.invalidGrant], cachedRecipeIDs: [])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.appStateStore.save(
            NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: "2026-06-16T11:00:00.000Z"
            ).recordingCaptureDraft(
                CaptureDraft(id: "draft_only", source: .text, rawText: "a cup of flour", imageAssetIdentifier: nil, createdAt: "2026-06-16T11:00:00.000Z"),
                savedAt: "2026-06-16T11:00:00.000Z"
            )
        )

        await fixture.store.bootstrap()

        guard case .offlineStale(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the kitchen with the sign-in banner, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.captureDraft?.id == "draft_only")
    }

    // MARK: Refusals that are not the token's

    @MainActor
    @Test("an HTML 403, a 404 and a 413 are transient: the session and the cached kitchen stay")
    func nonOAuthFourHundredsDoNotSignTheChefOut() async throws {
        for outcome in [RefreshOutcome.htmlForbidden, .notFound, .payloadTooLarge] {
            let fixture = try await Self.fixture(outcomes: [outcome, .success])
            defer { try? FileManager.default.removeItem(at: fixture.directory) }

            await fixture.store.bootstrap()

            guard case .syncFailed(let content, _) = fixture.store.bootstrapState else {
                Issue.record("Expected a retryable failure for \(outcome), got \(fixture.store.bootstrapState)")
                return
            }
            #expect(!content.isSessionExpired)
            #expect(content.recipes.map(\.id) == ["recipe_cached"])
            #expect(try await fixture.vault.loadSession()?.refreshToken == "sj_refresh_dead")

            await fixture.store.bootstrap()
            guard case .liveSynced = fixture.store.bootstrapState else {
                Issue.record("Expected the retry to sync for \(outcome), got \(fixture.store.bootstrapState)")
                return
            }
        }
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

/// A sync store whose saved snapshot cannot be read, as when its file is damaged. It holds no queue or
/// checkpoint, and writes go nowhere.
private actor UnreadableSnapshotSyncStore: NativeSyncStore {
    func loadSnapshot() throws -> NativeSyncSnapshot {
        throw NativeSyncStoreError.unavailable("saved sync snapshot unreadable")
    }

    func loadQueue() throws -> NativeMutationQueue {
        NativeMutationQueue()
    }

    func saveQueue(_: NativeMutationQueue) throws {}

    func saveQueue(_: NativeMutationQueue, accountID _: String?, environment _: NativeCacheEnvironment?) throws {}

    func saveQueue(
        _: NativeMutationQueue,
        accountID _: String?,
        environment _: NativeCacheEnvironment?,
        upsertingCachedRecords _: [NativeSyncCachedRecord],
        deletingCachedRecordKeys _: Set<String>
    ) throws {}

    func loadCheckpoint() throws -> NativeSyncCheckpoint {
        throw NativeSyncStoreError.missingCheckpoint
    }

    func saveCheckpoint(_: NativeSyncCheckpoint) throws {}

    func clearCheckpoint() throws {}

    func appendTombstone(_: NativeSyncTombstone) throws {}

    func cachedRecord(kind _: NativeSyncEntryKind, resourceID _: String) throws -> NativeSyncCachedRecord? {
        nil
    }

    func apply(syncData _: NativeSyncData, validatedAt _: Date) throws -> NativeSyncApplyResult {
        NativeSyncApplyResult(upsertedCacheKeys: [], removedCacheKeys: [], tombstones: [])
    }

    func updateQueue(
        accountID _: String?,
        environment _: NativeCacheEnvironment?,
        _ transform: @Sendable (NativeSyncSnapshot) throws -> NativeQueueUpdate
    ) throws -> NativeQueueUpdate {
        try transform(.empty)
    }

    func queuedClientMutationIDs() throws -> Set<String> {
        []
    }
}
