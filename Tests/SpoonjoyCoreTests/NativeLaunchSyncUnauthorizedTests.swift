import Foundation
import Testing
@testable import SpoonjoyCore

/// A stored access token the server no longer accepts: the launch sync gets a 401 before the token's own expiry.
@Suite("Launch sync answered with 401")
struct NativeLaunchSyncUnauthorizedTests {
    private static let now = Date(timeIntervalSince1970: 1_780_010_000)
    private static let rootViewPath = "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"

    private actor ScriptedURLSession: URLSessionPerforming {
        private var responses: [(status: Int, body: String)]
        private(set) var authorizations: [String?] = []

        init(_ responses: [(status: Int, body: String)]) {
            self.responses = responses
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            authorizations.append(request.value(forHTTPHeaderField: "Authorization"))
            let next = responses.removeFirst()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: next.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Data(next.body.utf8), response)
        }
    }

    private static let invalidToken = (
        status: 401,
        body: #"{"ok":false,"requestId":"req_unknown_token","error":{"code":"invalid_token","message":"Unknown token","status":401}}"#
    )

    private static let emptySync = (
        status: 200,
        body: #"{"ok":true,"requestId":"req_sync","data":{"freshness":{"accountId":"chef_ari","environment":"production","schemaVersion":1,"sourceEndpoint":"/api/v1/me/sync","generatedAt":"2026-06-16T12:00:00.000Z","lastValidatedAt":"2026-06-16T12:00:00.000Z"},"entries":[],"nextCursor":null,"hasMore":false}}"#
    )

    @MainActor
    private static func store(
        session: ScriptedURLSession,
        refresh: @escaping OAuthRefreshOperation
    ) async throws -> (store: NativeLiveAppStore, vault: InMemoryTokenVault) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-launch-401-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let vault = InMemoryTokenVault()
        try await vault.saveClientID(NativeAuthSession.nativeAppClientID)
        // Still valid by its own expiry, so the app sends it without refreshing first.
        try await vault.saveSession(try AuthSession(
            clientID: NativeAuthSession.nativeAppClientID,
            accessToken: "sj_access_unknown",
            refreshToken: "sj_refresh_unknown",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(3_600),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        ))
        let fixedNow = Self.now
        let clock: @Sendable () -> Date = { fixedNow }
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple Tests",
            registerClient: { _, _ in "client_live" },
            exchangeCode: { _, _, _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            refresh: refresh,
            revoke: { _, _ in },
            now: clock
        )
        let configuration = APIClientConfiguration.spoonjoyProduction
        let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: try NativeMutationQueue(mutations: []), cachedRecords: [])
        let refresher = NativeAuthSessionAPIRefresher(authSessionRepository: repository, baseURL: configuration.baseURL)
        let engine = NativeSyncEngine(
            store: syncStore,
            transport: URLSessionNativeSyncTransport(
                apiTransport: URLSessionAPITransport(session: session, authenticationRefresher: refresher)
            ),
            clock: clock
        )
        let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
        let store = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
            authSessionRepository: repository,
            cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
            syncStore: syncStore,
            syncEngine: engine,
            syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
            appStateStoreProvider: { appStateStore },
            configuration: configuration,
            cacheEnvironment: .production,
            now: clock
        ))
        return (store, vault)
    }

    @Test("a 401 whose refresh the server refuses signs the app out instead of showing a failed sync")
    @MainActor
    func refusedRefreshSignsOut() async throws {
        let session = ScriptedURLSession([Self.invalidToken])
        let fixture = try await Self.store(session: session) { _, _ in
            throw OAuthErrorResponse.transportError(
                statusCode: 400,
                isJSON: true,
                data: Data(#"{"error":"invalid_grant","error_description":"unknown refresh token"}"#.utf8),
                requestID: "req_refusal",
                retryAfterSeconds: nil
            )!
        }

        await fixture.store.bootstrap()

        guard case .signedOut = fixture.store.bootstrapState else {
            Issue.record("Expected the sign-in screen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(await session.authorizations == ["Bearer sj_access_unknown"])
    }

    @Test("a 401 whose refresh succeeds replays the sync with the new token")
    @MainActor
    func successfulRefreshReplaysTheSync() async throws {
        let session = ScriptedURLSession([Self.invalidToken, Self.emptySync])
        let fixture = try await Self.store(session: session) { _, _ in
            OAuthTokenResponse(
                accessToken: "sj_access_refreshed",
                refreshToken: "sj_refresh_refreshed",
                tokenType: "Bearer",
                expiresIn: 3_600,
                scope: NativeAuthSession.defaultScope
            )
        }

        await fixture.store.bootstrap()

        if case .syncFailed = fixture.store.bootstrapState {
            Issue.record("Expected the refreshed sync to finish, got \(fixture.store.bootstrapState)")
        }
        if case .signedOut = fixture.store.bootstrapState {
            Issue.record("Expected the refreshed sync to keep the account, got \(fixture.store.bootstrapState)")
        }
        #expect(await session.authorizations == ["Bearer sj_access_unknown", "Bearer sj_access_refreshed"])
        #expect(try await fixture.vault.loadSession()?.accessToken == "sj_access_refreshed")
    }

    @Test("the app's sync engine sends through a transport that refreshes on 401")
    func appSyncTransportRefreshes() throws {
        var root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while root.path != "/",
              !FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            root.deleteLastPathComponent()
        }
        let source = try String(contentsOf: root.appendingPathComponent(Self.rootViewPath), encoding: .utf8)
        #expect(source.contains(
            "NativeAuthSessionAPIRefresher(authSessionRepository: authRepository, baseURL: configuration.baseURL)"
        ))
        #expect(source.contains(
            "URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(authenticationRefresher: syncRefresher))"
        ))
        #expect(!source.contains("transport: URLSessionNativeSyncTransport())"))
    }
}
