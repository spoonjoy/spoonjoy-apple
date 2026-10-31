import Foundation
import Testing
@testable import SpoonjoyCore

/// A stored access token the server no longer accepts: requests get a 401 before the token's own expiry. Every test
/// sends through `URLSessionNativeSyncTransport.refreshing`, the transport the app's sync engine uses.
@Suite("Sync requests answered with 401")
struct NativeLaunchSyncUnauthorizedTests {
    private static let now = Date(timeIntervalSince1970: 1_780_010_000)

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

    private enum RefreshAnswer: Sendable {
        case tokens
        case invalidGrant
        case offline
        case serverError
        case htmlForbidden
    }

    /// The refresh endpoint, scripted: every call records the refresh token it was sent.
    private actor RefreshEndpoint {
        let answer: RefreshAnswer
        private(set) var refreshTokens: [String] = []

        init(_ answer: RefreshAnswer) {
            self.answer = answer
        }

        func refresh(refreshToken: String) throws -> OAuthTokenResponse {
            refreshTokens.append(refreshToken)
            switch answer {
            case .tokens:
                return OAuthTokenResponse(
                    accessToken: "sj_access_refreshed",
                    refreshToken: "sj_refresh_refreshed",
                    tokenType: "Bearer",
                    expiresIn: 3_600,
                    scope: NativeAuthSession.defaultScope
                )
            case .invalidGrant:
                throw OAuthErrorResponse.transportError(
                    statusCode: 400,
                    isJSON: true,
                    data: Data(#"{"error":"invalid_grant","error_description":"unknown refresh token"}"#.utf8),
                    requestID: "req_refusal",
                    retryAfterSeconds: nil
                )!
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
            case .htmlForbidden:
                throw APITransportError(
                    kind: .nonJSONResponse,
                    requestID: "req_proxy",
                    statusCode: 403,
                    apiError: APIError(
                        requestID: "req_proxy",
                        code: "oauth_http_status_403",
                        message: "OAuth request failed with HTTP 403.",
                        status: 403
                    ),
                    retryDecision: .doNotRetry
                )
            }
        }
    }

    private static let invalidToken = (
        status: 401,
        body: #"{"ok":false,"requestId":"req_unknown_token","error":{"code":"invalid_token","message":"Unknown token","status":401}}"#
    )

    private static func syncPage(nextCursor: String?) -> (status: Int, body: String) {
        let cursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return (
            status: 200,
            body: #"{"ok":true,"requestId":"req_sync","data":{"freshness":{"accountId":"chef_ari","environment":"production","schemaVersion":1,"sourceEndpoint":"/api/v1/me/sync","generatedAt":"2026-06-16T12:00:00.000Z","lastValidatedAt":"2026-06-16T12:00:00.000Z"},"entries":[],"nextCursor":"#
                + cursor + #","hasMore":"# + (nextCursor == nil ? "false" : "true") + "}}"
        )
    }

    private static let editAccepted = (
        status: 200,
        body: #"{"ok":true,"requestId":"req_edit","data":{}}"#
    )

    private struct Fixture {
        let store: NativeLiveAppStore
        let vault: InMemoryTokenVault
        let transport: URLSessionNativeSyncTransport
    }

    @MainActor
    private static func fixture(session: ScriptedURLSession, endpoint: RefreshEndpoint) async throws -> Fixture {
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
            refresh: { _, refreshToken in try await endpoint.refresh(refreshToken: refreshToken) },
            revoke: { _, _ in },
            now: clock
        )
        let configuration = APIClientConfiguration.spoonjoyProduction
        let syncStore = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .production,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: []),
            cachedRecords: []
        )
        let transport = URLSessionNativeSyncTransport.refreshing(repository, baseURL: configuration.baseURL, session: session)
        let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: clock)
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
        return Fixture(store: store, vault: vault, transport: transport)
    }

    // MARK: Launch sync

    @Test("a 401 whose refresh the server refuses signs the app out instead of showing a failed sync")
    @MainActor
    func refusedRefreshSignsOut() async throws {
        let session = ScriptedURLSession([Self.invalidToken])
        let endpoint = RefreshEndpoint(.invalidGrant)
        let fixture = try await Self.fixture(session: session, endpoint: endpoint)

        await fixture.store.bootstrap()

        guard case .signedOut(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the sign-in screen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(content.isSessionExpired)
        #expect(await session.authorizations == ["Bearer sj_access_unknown"])
        #expect(await endpoint.refreshTokens == ["sj_refresh_unknown"])
    }

    @Test("a 401 whose refresh succeeds replays the page, and later pages go out with the new token")
    @MainActor
    func successfulRefreshReplaysTheSync() async throws {
        let session = ScriptedURLSession([
            Self.invalidToken,
            Self.syncPage(nextCursor: "cursor_page_2"),
            Self.syncPage(nextCursor: nil)
        ])
        let endpoint = RefreshEndpoint(.tokens)
        let fixture = try await Self.fixture(session: session, endpoint: endpoint)

        await fixture.store.bootstrap()

        guard case .liveSynced(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the synced kitchen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(!content.isSessionExpired)
        #expect(await session.authorizations == [
            "Bearer sj_access_unknown",
            "Bearer sj_access_refreshed",
            "Bearer sj_access_refreshed"
        ])
        #expect(await endpoint.refreshTokens == ["sj_refresh_unknown"])
        #expect(try await fixture.vault.loadSession()?.accessToken == "sj_access_refreshed")
    }

    @Test("a refresh that cannot reach the server keeps the chef signed in, offline")
    @MainActor
    func offlineRefreshKeepsTheSession() async throws {
        let session = ScriptedURLSession([Self.invalidToken])
        let endpoint = RefreshEndpoint(.offline)
        let fixture = try await Self.fixture(session: session, endpoint: endpoint)

        await fixture.store.bootstrap()

        guard case .offlineStale(let content) = fixture.store.bootstrapState else {
            Issue.record("Expected the offline kitchen, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(!content.isSessionExpired)
        #expect(try await fixture.vault.loadSession()?.accessToken == "sj_access_unknown")
        #expect(try await fixture.vault.loadSession()?.refreshToken == "sj_refresh_unknown")
        #expect(await endpoint.refreshTokens == ["sj_refresh_unknown"])
    }

    @Test("a refresh the server fails with a 503 keeps the chef signed in and shows the failed sync")
    @MainActor
    func serverErrorRefreshKeepsTheSession() async throws {
        let session = ScriptedURLSession([Self.invalidToken])
        let endpoint = RefreshEndpoint(.serverError)
        let fixture = try await Self.fixture(session: session, endpoint: endpoint)

        await fixture.store.bootstrap()

        guard case .syncFailed(let content, _) = fixture.store.bootstrapState else {
            Issue.record("Expected the failed sync, got \(fixture.store.bootstrapState)")
            return
        }
        #expect(!content.isSessionExpired)
        #expect(try await fixture.vault.loadSession()?.accessToken == "sj_access_unknown")
        #expect(try await fixture.vault.loadSession()?.refreshToken == "sj_refresh_unknown")
        #expect(await endpoint.refreshTokens == ["sj_refresh_unknown"])
    }

    // MARK: Queued edits

    private static let checkMilk = NativeQueuedMutation.shoppingCheckItem(
        itemID: "item_milk",
        checked: true,
        clientMutationID: "cm_check_milk",
        createdAt: "2026-10-09T08:00:00.000Z"
    )

    @Test("a queued edit answered 401 is sent again with the refreshed token")
    @MainActor
    func editRefreshesAndReplays() async throws {
        let session = ScriptedURLSession([Self.invalidToken, Self.editAccepted])
        let endpoint = RefreshEndpoint(.tokens)
        let fixture = try await Self.fixture(session: session, endpoint: endpoint)

        let result = try await fixture.transport.send(
            Self.checkMilk,
            configuration: APIClientConfiguration(baseURL: APIClientConfiguration.spoonjoyProduction.baseURL, bearerToken: "sj_access_unknown")
        )

        #expect(result == .success(serverRevision: nil))
        #expect(await session.authorizations == ["Bearer sj_access_unknown", "Bearer sj_access_refreshed"])
    }

    @Test("a queued edit whose refresh hits a proxy's HTML 403 waits as an auth failure, not a rejected edit")
    @MainActor
    func editWithBrokenRefreshWaitsAsAuthFailure() async throws {
        let session = ScriptedURLSession([Self.invalidToken])
        let endpoint = RefreshEndpoint(.htmlForbidden)
        let fixture = try await Self.fixture(session: session, endpoint: endpoint)

        let result = try await fixture.transport.send(
            Self.checkMilk,
            configuration: APIClientConfiguration(baseURL: APIClientConfiguration.spoonjoyProduction.baseURL, bearerToken: "sj_access_unknown")
        )

        #expect(result == .authFailure(message: "Unknown token"))
        #expect(await session.authorizations == ["Bearer sj_access_unknown"])
        #expect(try await fixture.vault.loadSession()?.accessToken == "sj_access_unknown")
    }
}
