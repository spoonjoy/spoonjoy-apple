import Foundation
import Testing
@testable import SpoonjoyCore

/// An Apple sign-in that found no account leaves a pending link (spoonjoy-v2 #679). The app keeps its token in
/// memory, sends it once with the next password or browser sign-in, and never logs or reports it.
@Suite("Pending Apple link")
struct PendingAppleLinkTests {
    static let token = "pal_" + String(repeating: "Zq9", count: 14) + "x"
    static let receivedAt = Date(timeIntervalSince1970: 1_800_000_000)

    /// The server's answer, byte for byte in shape: `apiV1SamePartyErrorResponse` for `NativeAppleAuthError`.
    static func serverRefusal(
        token: String? = Self.token,
        expiresAt: String? = "2027-01-15T08:20:00.000Z",
        message: String = PendingAppleLink.defaultMessage
    ) throws -> APITransportError {
        var details: [String: Any] = ["providerCode": "apple_email_unavailable"]
        if let token { details["pendingAppleLinkToken"] = token }
        if let expiresAt { details["pendingAppleLinkExpiresAt"] = expiresAt }
        let body: [String: Any] = [
            "ok": false,
            "requestId": "req_pending_apple",
            "error": ["code": "validation_error", "message": message, "status": 400, "details": details]
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        guard case .failure(let apiError) = try APIEnvelope<JSONValue>.decodeResult(data) else {
            throw PendingAppleLinkTestError.expectedFailureEnvelope
        }
        return APITransportError(
            kind: .apiError,
            requestID: apiError.requestID,
            statusCode: 400,
            apiError: apiError,
            retryDecision: .doNotRetry
        )
    }

    @Test("decodes the server's apple_email_unavailable answer and its token")
    func decodesRefusal() throws {
        let refusal = try Self.serverRefusal(expiresAt: nil)
        let link = try #require(PendingAppleLink.from(refusal, receivedAt: Self.receivedAt))
        #expect(link.token == Self.token)
        #expect(link.expiresAt == Self.receivedAt.addingTimeInterval(30 * 60))
        #expect(PendingAppleLink.isAppleEmailUnavailable(refusal))
        #expect(PendingAppleLink.userMessage(for: refusal) == PendingAppleLink.defaultMessage)

        // The server's expiry is server time, so the device counts its own thirty minutes from receipt: a fast
        // device clock must not expire the link early.
        let iso = ISO8601DateFormatter()
        let receipt = try #require(iso.date(from: "2027-01-15T08:00:00Z"))
        for serverExpiry in ["2027-01-15T08:20:00.000Z", "2027-01-15T09:00:00Z", "not a date"] {
            let link = try #require(PendingAppleLink.from(try Self.serverRefusal(expiresAt: serverExpiry), receivedAt: receipt))
            #expect(link.expiresAt == receipt.addingTimeInterval(30 * 60))
        }

        // The same answer without a token (the server could not save one) still gets the guidance, but no link.
        let tokenless = try Self.serverRefusal(token: nil, expiresAt: nil)
        #expect(PendingAppleLink.from(tokenless, receivedAt: Self.receivedAt) == nil)
        // Nothing will be connected then, so the words don't promise it.
        #expect(PendingAppleLink.userMessage(for: tokenless) == PendingAppleLink.noLinkMessage)

        // A blank server message falls back to the same copy; another failure gets no guidance at all.
        #expect(PendingAppleLink.userMessage(for: try Self.serverRefusal(message: " ")) == PendingAppleLink.defaultMessage)
        let other = APITransportError(
            kind: .apiError, requestID: "r", statusCode: 401,
            apiError: APIError(requestID: "r", code: "invalid_token", message: "nope", status: 401,
                               details: ["providerCode": .string("apple_token_invalid")]),
            retryDecision: .doNotRetry
        )
        #expect(PendingAppleLink.from(other, receivedAt: Self.receivedAt) == nil)
        #expect(PendingAppleLink.userMessage(for: other) == nil)
        #expect(PendingAppleLink.userMessage(for: URLError(.timedOut)) == nil)
    }

    @Test("redaction strips the token from a transport error and a bare API error, and keeps the guidance")
    func redaction() throws {
        let refusal = try Self.serverRefusal()
        let bare = try #require(refusal.apiError)
        for error in [refusal, bare] as [Error] {
            let redacted = PendingAppleLink.redacting(error)
            #expect(PendingAppleLink.from(redacted, receivedAt: Self.receivedAt) == nil)
            #expect(PendingAppleLink.userMessage(for: redacted) == PendingAppleLink.defaultMessage)
            var dumped = ""
            dump(redacted, to: &dumped)
            #expect(!dumped.contains("pal_"))
            #expect(!String(describing: redacted).contains("pal_"))
        }
        let unrelated = URLError(.timedOut)
        #expect((PendingAppleLink.redacting(unrelated) as? URLError) == unrelated)

        // Errors that carry no link pass through untouched, wrapped or bare.
        let tokenless = try Self.serverRefusal(token: nil, expiresAt: nil)
        #expect((PendingAppleLink.redacting(tokenless) as? APITransportError) == tokenless)
        let bareTokenless = try #require(tokenless.apiError)
        #expect((PendingAppleLink.redacting(bareTokenless) as? APIError) == bareTokenless)

        // A blank or overlong token is no link at all.
        #expect(PendingAppleLink.from(try Self.serverRefusal(token: "  "), receivedAt: Self.receivedAt) == nil)
        let overlong = "pal_" + String(repeating: "a", count: 125)
        #expect(PendingAppleLink.from(try Self.serverRefusal(token: overlong), receivedAt: Self.receivedAt) == nil)
    }

    @Test("a repository with no event handler still keeps and sends the pending link")
    func defaultEventHandler() async throws {
        let network = PendingAppleLinkNetwork(refusal: try Self.serverRefusal(), appleLinkOutcome: "linked")
        let repository = NativeAuthSessionRepository(
            vault: InMemoryTokenVault(),
            clientName: "Spoonjoy Apple",
            registerClient: { _, _ in "client-1" },
            exchangeCode: { _, _, _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            exchangeAppleCredential: { credential in try await network.apple(credential) },
            exchangePasswordCredential: { credential in try await network.password(credential) },
            refresh: { _, _ in throw URLError(.badServerResponse) },
            revoke: { _, _ in }
        )
        await #expect(throws: APITransportError.self) {
            _ = try await repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
        }
        _ = try await repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        #expect(await network.passwordCredentials.map(\.pendingAppleLinkToken) == [Self.token])
    }

    @Test("password sign-in carries the token in its JSON body only when there is one")
    func passwordRequestBuilder() throws {
        let plain = NativePasswordSignInCredential(emailOrUsername: "chef@spoonjoy.app", password: "pw")
        let plainBody = try #require(try NativePasswordSignInRequests.exchangeCredential(plain).body)
        let plainJSON = try #require(try JSONSerialization.jsonObject(with: plainBody) as? [String: String])
        #expect(plainJSON == ["emailOrUsername": "chef@spoonjoy.app", "password": "pw"])

        let link = try #require(PendingAppleLink(token: Self.token, expiresAt: Self.receivedAt))
        let linking = plain.linkingApple(link)
        #expect(linking.carriesPendingAppleLink)
        let builder = try NativePasswordSignInRequests.exchangeCredential(linking)
        #expect(builder.pathComponents == ["api", "v1", "auth", "password", "native"])
        let body = try #require(builder.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json["pendingAppleLinkToken"] == Self.token)
        #expect(json["emailOrUsername"] == "chef@spoonjoy.app")
    }

    @Test("code exchange carries the token as the pending_apple_link_token form field only when there is one")
    func codeExchangeRequestBuilder() throws {
        let redirect = NativeAuthSession.redirectURI
        let plain = try OAuthRequests.exchangeCode(clientID: "client", redirectURI: redirect, code: "c", codeVerifier: "v")
        let plainForm = String(decoding: try #require(plain.body), as: UTF8.self)
        #expect(!plainForm.contains("pending_apple_link_token"))
        #expect(plain == (try OAuthRequests.exchangeCode(
            NativeAuthorizationCodeGrant(clientID: "client", redirectURI: redirect, code: "c", codeVerifier: "v")
        )))

        let grant = NativeAuthorizationCodeGrant(
            clientID: "client", redirectURI: redirect, code: "c", codeVerifier: "v", pendingAppleLinkToken: Self.token
        )
        let builder = try OAuthRequests.exchangeCode(grant)
        #expect(builder.pathComponents == ["oauth", "token"])
        #expect(builder.headers["Content-Type"] == "application/x-www-form-urlencoded")
        var components = URLComponents()
        components.percentEncodedQuery = String(decoding: try #require(builder.body), as: UTF8.self)
        let fields = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(fields["pending_apple_link_token"] == Self.token)
        #expect(fields["grant_type"] == "authorization_code")
        #expect(fields["code"] == "c")
    }

    @Test("token responses read the link outcome from either sign-in")
    func decodesLinkOutcome() throws {
        let base = #"{"access_token":"a","refresh_token":"r","token_type":"Bearer","expires_in":3600,"scope":"s""#
        let password = try JSONDecoder().decode(OAuthTokenResponse.self, from: Data((base + #","client_id":"c","appleLink":"linked"}"#).utf8))
        #expect(password.appleLinkOutcome == "linked")
        #expect(password.clientID == "c")
        let oauth = try JSONDecoder().decode(OAuthTokenResponse.self, from: Data((base + #","apple_link":"taken"}"#).utf8))
        #expect(oauth.appleLinkOutcome == "taken")
        let neither = try JSONDecoder().decode(OAuthTokenResponse.self, from: Data((base + "}").utf8))
        #expect(neither.appleLinkOutcome == nil)
        #expect(neither.clientID == nil)
    }

    @Test("a refused password sign-in keeps the pending link; the next one that succeeds spends it")
    func passwordKeepsLinkUntilSuccess() async throws {
        let harness = try PendingAppleLinkHarness(appleLinkOutcome: "linked")
        await #expect(throws: APITransportError.self) {
            _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
        }
        #expect(await harness.repository.hasPendingAppleLink())
        #expect(await harness.events.all == [.received])

        // A mistyped password: the server signs nobody in, so it spends nothing, and neither does the app.
        await harness.network.failNextPassword()
        await #expect(throws: URLError.self) {
            _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        }
        #expect(await harness.repository.hasPendingAppleLink())
        #expect(await !harness.repository.takeAppleConnectedConfirmation())

        // The right password carries the link, connects Apple, and says so once.
        _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        #expect(await !harness.repository.hasPendingAppleLink())
        #expect(await harness.repository.takeAppleConnectedConfirmation())
        #expect(await !harness.repository.takeAppleConnectedConfirmation())

        // After that, sign-ins carry nothing.
        _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        #expect(await !harness.repository.takeAppleConnectedConfirmation())

        let sent = await harness.network.passwordCredentials
        #expect(sent.map(\.pendingAppleLinkToken) == [Self.token, Self.token, nil])
        #expect(await harness.events.all == [
            .received, .sent(via: .password), .sent(via: .password), .outcome("linked")
        ])
    }

    @Test("a refused password sign-in does not bring back a link that sign-out cleared while it was out")
    func passwordFailureAfterSignOutStaysCleared() async throws {
        let harness = try PendingAppleLinkHarness()
        await #expect(throws: APITransportError.self) {
            _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
        }
        let repository = harness.repository
        await harness.network.failNextPassword(whileOut: { try? await repository.revokeAndLogout() })
        await #expect(throws: URLError.self) {
            _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        }
        #expect(await !harness.repository.hasPendingAppleLink())
    }

    @Test("a refused password sign-in does not bring back a link that sign-out cleared while the attempt was reported")
    func passwordFailureAfterSignOutDuringSentEvent() async throws {
        let box = RepositoryBox()
        let harness = try PendingAppleLinkHarness(onEvent: { event in
            if case .sent = event, let repository = box.repository {
                try? await repository.revokeAndLogout()
            }
        })
        box.repository = harness.repository
        await #expect(throws: APITransportError.self) {
            _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
        }
        await harness.network.failNextPassword()
        await #expect(throws: URLError.self) {
            _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        }
        #expect(await !harness.repository.hasPendingAppleLink())
    }

    @Test("sign-out and an Apple sign-in clear an unread confirmation, and a later sign-in never shows a stale one")
    func confirmationClearing() async throws {
        let harness = try PendingAppleLinkHarness(appleLinkOutcome: "linked")
        for clear in [
            { try await harness.repository.revokeAndLogout() },
            { try await harness.repository.clearLocalSession() },
            {
                await harness.network.allowApple()
                _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
                await harness.network.refuseApple()
            },
            { _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential) }
        ] as [@Sendable () async throws -> Void] {
            await #expect(throws: APITransportError.self) {
                _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
            }
            _ = try await harness.signInWithBrowser()
            try await clear()
            #expect(await !harness.repository.takeAppleConnectedConfirmation())
        }
    }

    @Test("only a linked or already-linked answer confirms Apple; other outcomes don't")
    func confirmationOutcomes() async throws {
        for (outcome, confirmed) in [("linked", true), ("already_linked", true), ("taken", false), ("consumed", false)] {
            let harness = try PendingAppleLinkHarness(appleLinkOutcome: outcome)
            await #expect(throws: APITransportError.self) {
                _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
            }
            _ = try await harness.signInWithBrowser()
            #expect(await harness.repository.takeAppleConnectedConfirmation() == confirmed, "outcome \(outcome)")
        }
    }

    @Test("a pending link goes with the next browser code exchange, and the server's outcome is reported")
    func singleUseAcrossBrowser() async throws {
        let harness = try PendingAppleLinkHarness(appleLinkOutcome: "linked")
        await #expect(throws: APITransportError.self) {
            _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
        }
        _ = try await harness.signInWithBrowser()
        _ = try await harness.signInWithBrowser()

        let grants = await harness.network.grants
        #expect(grants.map(\.pendingAppleLinkToken) == [Self.token, nil])
        #expect(await harness.events.all == [.received, .sent(via: .browser), .outcome("linked")])
    }

    @Test("a pending link expires thirty minutes after the Apple answer")
    func expiry() async throws {
        let harness = try PendingAppleLinkHarness(serverExpiresAt: nil)
        await #expect(throws: APITransportError.self) {
            _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
        }
        await harness.clock.advance(by: 30 * 60 - 1)
        #expect(await harness.repository.hasPendingAppleLink())
        await harness.clock.advance(by: 1)
        #expect(await !harness.repository.hasPendingAppleLink())
        _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        #expect(await harness.network.passwordCredentials.map(\.pendingAppleLinkToken) == [nil])
        #expect(await harness.events.all == [.received, .expired])
    }

    @Test("sign-out, a local sign-out and an Apple sign-in that succeeds all forget the pending link")
    func clearing() async throws {
        let harness = try PendingAppleLinkHarness()
        for clear in [
            { try await harness.repository.revokeAndLogout() },
            { try await harness.repository.clearLocalSession() },
            {
                await harness.network.allowApple()
                _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
                await harness.network.refuseApple()
            }
        ] as [@Sendable () async throws -> Void] {
            await #expect(throws: APITransportError.self) {
                _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
            }
            #expect(await harness.repository.hasPendingAppleLink())
            try await clear()
            #expect(await !harness.repository.hasPendingAppleLink())
        }
        _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        #expect(await harness.network.passwordCredentials.map(\.pendingAppleLinkToken) == [nil])
    }

    @Test("the token never leaves the repository in an error, a description, a dump or telemetry")
    func tokenNeverLogged() async throws {
        let harness = try PendingAppleLinkHarness(appleLinkOutcome: "linked")
        var thrown: Error?
        do {
            _ = try await harness.repository.handleAppleSignInCredential(PendingAppleLinkHarness.appleCredential)
        } catch {
            thrown = error
        }
        let error = try #require(thrown)
        // The error that reaches the view still says what happened, so it can show the guidance...
        #expect(PendingAppleLink.userMessage(for: error) == PendingAppleLink.defaultMessage)
        #expect(PendingAppleLink.from(error, receivedAt: Self.receivedAt) == nil)

        // ...and nothing a log line, a crash report or a test failure could print contains the token.
        let link = try #require(PendingAppleLink(token: Self.token, expiresAt: Self.receivedAt))
        let credential = PendingAppleLinkHarness.passwordCredential.linkingApple(link)
        let grant = NativeAuthorizationCodeGrant(
            clientID: "c", redirectURI: NativeAuthSession.redirectURI, code: "code", codeVerifier: "verifier",
            pendingAppleLinkToken: Self.token
        )
        var printed = [
            String(describing: error), String(reflecting: error), "\(link)", String(reflecting: link),
            "\(credential)", String(reflecting: credential), "\(grant)", String(reflecting: grant)
        ]
        for value in [error, link, credential, grant] as [Any] {
            var dumped = ""
            dump(value, to: &dumped)
            printed.append(dumped)
        }

        _ = try await harness.repository.handlePasswordSignInCredential(PendingAppleLinkHarness.passwordCredential)
        let events = await harness.events.all
        #expect(events == [.received, .sent(via: .password), .outcome("linked")])
        for event in events + [.expired, .outcome("free text \(Self.token)")] {
            let descriptor = event.telemetryDescriptor(sessionState: nil)
            let telemetry = try NativeTelemetryRequests.recordEvent(
                descriptor.telemetryEvent(environment: "test", metadata: .unknown)
            )
            printed.append(event.phase)
            printed.append(String(decoding: telemetry.body ?? Data(), as: UTF8.self))
        }
        #expect(PendingAppleLinkEvent.outcome("free text").phase == "pending_link_unknown")

        for text in printed {
            #expect(!text.contains(Self.token), "token leaked into: \(text.prefix(80))")
            #expect(!text.contains("pal_"), "token prefix leaked into: \(text.prefix(80))")
        }
        #expect(!printed.joined().contains("verifier"))
    }
}

private enum PendingAppleLinkTestError: Error {
    case expectedFailureEnvelope
}

/// Reads the clock synchronously for the repository's `now`, which is not async.
private final class ClockBox: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date) {
        self.date = date
    }

    var now: Date {
        lock.withLock { date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { date = date.addingTimeInterval(interval) }
    }
}

/// Lets an event handler reach the repository it was built into.
private final class RepositoryBox: @unchecked Sendable {
    var repository: NativeAuthSessionRepository?
}

private actor EventLog {
    private(set) var all: [PendingAppleLinkEvent] = []

    func append(_ event: PendingAppleLinkEvent) {
        all.append(event)
    }
}

private actor PendingAppleLinkNetwork {
    private let refusal: APITransportError
    private let appleLinkOutcome: String?
    private var appleSucceeds = false
    private var passwordFails = false
    private(set) var passwordCredentials: [NativePasswordSignInCredential] = []
    private(set) var grants: [NativeAuthorizationCodeGrant] = []

    init(refusal: APITransportError, appleLinkOutcome: String?) {
        self.refusal = refusal
        self.appleLinkOutcome = appleLinkOutcome
    }

    func allowApple() { appleSucceeds = true }
    func refuseApple() { appleSucceeds = false }
    private var whileOut: (@Sendable () async -> Void)?
    func failNextPassword(whileOut: (@Sendable () async -> Void)? = nil) {
        passwordFails = true
        self.whileOut = whileOut
    }

    func apple(_ credential: NativeAppleSignInCredential) throws -> OAuthTokenResponse {
        guard appleSucceeds else { throw refusal }
        return response(outcome: nil)
    }

    func password(_ credential: NativePasswordSignInCredential) async throws -> OAuthTokenResponse {
        passwordCredentials.append(credential)
        if passwordFails {
            passwordFails = false
            if let whileOut {
                self.whileOut = nil
                await whileOut()
            }
            throw URLError(.timedOut)
        }
        return response(outcome: credential.carriesPendingAppleLink ? appleLinkOutcome : nil)
    }

    func exchange(_ grant: NativeAuthorizationCodeGrant) -> OAuthTokenResponse {
        grants.append(grant)
        return response(outcome: grant.carriesPendingAppleLink ? appleLinkOutcome : nil)
    }

    private func response(outcome: String?) -> OAuthTokenResponse {
        OAuthTokenResponse(
            accessToken: "sj_access", refreshToken: "sj_refresh", tokenType: "Bearer", expiresIn: 3600,
            scope: NativeAuthSession.defaultScope, clientID: NativeAuthSession.nativeAppClientID,
            appleLinkOutcome: outcome
        )
    }
}

private struct PendingAppleLinkHarness {
    static let appleCredential = NativeAppleSignInCredential(identityToken: "apple.identity.token", rawNonce: "nonce")
    static let passwordCredential = NativePasswordSignInCredential(emailOrUsername: "chef@spoonjoy.app", password: "pw")

    let repository: NativeAuthSessionRepository
    let network: PendingAppleLinkNetwork
    let events = EventLog()
    let clock: ClockHandle
    let vault = InMemoryTokenVault()

    struct ClockHandle: Sendable {
        let box: ClockBox
        func advance(by interval: TimeInterval) async { box.advance(by: interval) }
    }

    init(
        serverExpiresAt: String? = nil,
        appleLinkOutcome: String? = nil,
        onEvent: @escaping PendingAppleLinkEventHandler = { _ in }
    ) throws {
        let box = ClockBox(PendingAppleLinkTests.receivedAt)
        clock = ClockHandle(box: box)
        let network = PendingAppleLinkNetwork(
            refusal: try PendingAppleLinkTests.serverRefusal(expiresAt: serverExpiresAt),
            appleLinkOutcome: appleLinkOutcome
        )
        self.network = network
        let events = self.events
        repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            registerClient: { _, _ in "client-1" },
            exchangeCode: { _, _, _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            exchangeAuthorizationCode: { grant in await network.exchange(grant) },
            exchangeAppleCredential: { credential in try await network.apple(credential) },
            exchangePasswordCredential: { credential in try await network.password(credential) },
            refresh: { _, _ in throw URLError(.badServerResponse) },
            revoke: { _, _ in },
            now: { box.now },
            onPendingAppleLinkEvent: { event in
                await events.append(event)
                await onEvent(event)
            }
        )
    }

    func signInWithBrowser() async throws -> AuthSession {
        let state = try #require(OAuthState(rawValue: OAuthPKCE.randomVerifier()))
        let start = try await repository.startSignIn(state: state, codeChallenge: "challenge", providerHint: .google)
        var callback = URLComponents(url: start.redirectURI, resolvingAgainstBaseURL: false)!
        callback.queryItems = [URLQueryItem(name: "code", value: "code-1"), URLQueryItem(name: "state", value: state.rawValue)]
        return try await repository.handleOAuthCallback(callback.url!, expectedState: state, codeVerifier: "verifier")
    }
}
