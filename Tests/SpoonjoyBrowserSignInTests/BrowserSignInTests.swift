import CryptoKit
import Foundation
import Testing
@testable import SpoonjoyCore

/// "Continue with Google" from the tap to the https://spoonjoy.app/oauth/callback return, with a fake browser sheet in
/// place of ASWebAuthenticationSession. These tests run under `swift test` and on an iOS simulator (native.yml,
/// "Browser sign-in on the iOS simulator"). The server keeps one provider sign-in per browser cookie jar (its
/// `__oauth` cookie) and answers a callback without it with `invalid_state`, so the app must never have two server
/// starts open at once, and must check each return against the attempt that started it.
@MainActor
@Suite("Browser sign-in", .serialized)
struct BrowserSignInTests {
    @Test("the Google start URL is the exact /oauth/authorize request the server turns into its Google start")
    func googleStartURLIsExact() async throws {
        let harness = Harness()
        let start = await harness.flow.begin(provider: .google) { _ in }

        let attempt = try #require(harness.flow.attempt)
        #expect(start == .opened(authorizationURL: attempt.authorizationURL))
        let url = try #require(URLComponents(url: attempt.authorizationURL, resolvingAgainstBaseURL: false))
        #expect(url.scheme == "https")
        #expect(url.host == "spoonjoy.app")
        #expect(url.path == "/oauth/authorize")
        let query = Dictionary(uniqueKeysWithValues: (url.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(query == [
            "client_id": Harness.clientID,
            "redirect_uri": "https://spoonjoy.app/oauth/callback",
            "response_type": "code",
            "scope": NativeAuthSession.defaultScope,
            "state": attempt.state.rawValue,
            "code_challenge": s256(attempt.codeVerifier),
            "code_challenge_method": "S256",
            "provider": "google"
        ])
        // The sheet opens on that URL and waits for the universal-link callback.
        #expect(harness.sheets.opened.map(\.authorizationURL) == [attempt.authorizationURL])
        #expect(harness.sheets.opened.map(\.redirectURI) == [URL(string: "https://spoonjoy.app/oauth/callback")!])
        #expect(harness.sheets.sessions.map(\.startCount) == [1])
    }

    @Test("without the provider hint the start URL leaves provider out, so the server shows spoonjoy.app/login")
    func startWithoutProviderHintOmitsProvider() async throws {
        let harness = Harness()
        _ = await harness.flow.begin(provider: .google, sendsProviderHint: false) { _ in }

        let attempt = try #require(harness.flow.attempt)
        let url = try #require(URLComponents(url: attempt.authorizationURL, resolvingAgainstBaseURL: false))
        #expect(url.path == "/oauth/authorize")
        #expect(!(url.queryItems ?? []).contains { $0.name == "provider" })
        #expect(attempt.provider == .google)
    }

    @Test("the login-page launch variable is honoured only when it is exactly 1")
    func loginPageVariable() {
        #expect(NativeBrowserOAuthSignIn.loginPageRequested(environment: ["SPOONJOY_UI_TEST_BROWSER_SIGN_IN_LOGIN_PAGE": "1"]))
        #expect(!NativeBrowserOAuthSignIn.loginPageRequested(environment: [:]))
        #expect(!NativeBrowserOAuthSignIn.loginPageRequested(environment: ["SPOONJOY_UI_TEST_BROWSER_SIGN_IN_LOGIN_PAGE": "0"]))
    }

    @Test("a sheet that closes without a callback passes its error on; a cancel by the app passes none")
    func cancelPassesTheSheetErrorThrough() async throws {
        let closed = Harness()
        let closedFinishes = FinishLog()
        _ = await closed.flow.begin(provider: .google) { closedFinishes.record($0) }
        await closed.sheets.close(0)
        guard case let .canceled(error)? = closedFinishes.all.first else {
            Issue.record("The sheet's close did not finish as canceled")
            return
        }
        let nsError = try #require(error) as NSError
        #expect(nsError.domain == NSURLErrorDomain)
        #expect(nsError.code == URLError.userCancelledAuthentication.rawValue)
        #expect(NativeBrowserOAuthSignIn.diagnosticReason(nsError) == "\(NSURLErrorDomain) \(URLError.userCancelledAuthentication.rawValue)")

        let byApp = Harness()
        let byAppFinishes = FinishLog()
        _ = await byApp.flow.begin(provider: .google) { byAppFinishes.record($0) }
        byApp.flow.cancel()
        guard case let .canceled(appError)? = byAppFinishes.all.first else {
            Issue.record("The app's cancel did not finish as canceled")
            return
        }
        #expect(appError == nil)
    }

    @Test("a start that cannot open says why: the registration's error, a refused sheet or a bad secret")
    func startFailureSaysWhy() async throws {
        let offline = Harness(registrationFails: true)
        #expect(await offline.flow.begin(provider: .google) { _ in } == .couldNotOpen)
        #expect((offline.flow.startFailure as? URLError)?.code == .notConnectedToInternet)

        let refused = Harness(sheetStarts: false)
        #expect(await refused.flow.begin(provider: .google) { _ in } == .couldNotOpen)
        #expect(refused.flow.startFailure as? NativeBrowserOAuthStartFailure == .sheetRefused)

        let badSecret = Harness(randomSecret: { "not a verifier" })
        #expect(await badSecret.flow.begin(provider: .google) { _ in } == .couldNotOpen)
        #expect(badSecret.flow.startFailure as? NativeBrowserOAuthStartFailure == .invalidSecret)

        let opened = Harness()
        #expect(await opened.flow.begin(provider: .google) { _ in } != .couldNotOpen)
        #expect(opened.flow.startFailure == nil)
    }

    @Test("a transport error logs its kind, status and request id, never its description")
    func transportReason() {
        let error = APITransportError(kind: .apiError, requestID: "req_1", statusCode: 503, apiError: nil, retryDecision: .doNotRetry)
        #expect(NativeBrowserOAuthSignIn.diagnosticReason(error) == "apiError status 503 request req_1")
        let bare = APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        #expect(NativeBrowserOAuthSignIn.diagnosticReason(bare) == "offline status none request none")
    }

    @Test("a system cancel right after start, with nothing shown, starts one fresh sheet for the same attempt")
    func earlyCancelRetriesOnce() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        let attempt = try #require(harness.flow.attempt)

        harness.clock.advance(0.2)
        await harness.sheets.close(0, error: systemCancel)
        await harness.flow.retryTask?.value

        #expect(finishes.names.isEmpty)
        #expect(harness.flow.attempt == attempt)
        #expect(harness.pauses.all == [NativeBrowserOAuthSignIn.earlyCancelRetryDelay])
        #expect(harness.sheets.opened.map(\.authorizationURL) == [attempt.authorizationURL, attempt.authorizationURL])
        #expect(harness.sheets.sessions.map(\.startCount) == [1, 1])
        #expect(harness.gate.activeAttemptID == attempt.id)

        await harness.sheets.complete(1, with: serverCallback(code: "oac_code", state: attempt.state))
        #expect(finishes.names == ["signedIn"])
        #expect(await harness.network.exchanges.map(\.codeVerifier) == [attempt.codeVerifier])
        #expect(harness.logs.lines == [
            "Browser sign-in sheet started",
            "Browser sign-in early cancel: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 200 ms, systemUIAppeared=false, presentedVC=false; retrying once",
            "Browser sign-in retried: sheet started again",
            "Browser sign-in callback received"
        ])
        let secrets = ["://", "?", "code=", "state=", "oac_", attempt.state.rawValue, attempt.codeVerifier]
        #expect(harness.logs.lines.allSatisfy { line in !secrets.contains { line.contains($0) } })
    }

    @Test("a second early cancel in the same attempt finishes as canceled")
    func secondEarlyCancelFinishes() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }

        harness.clock.advance(0.2)
        await harness.sheets.close(0, error: systemCancel)
        await harness.flow.retryTask?.value
        harness.clock.advance(0.2)
        await harness.sheets.close(1, error: systemCancel)

        #expect(finishes.names == ["canceled"])
        #expect(harness.sheets.sessions.count == 2)
        #expect(harness.flow.attempt == nil)
        #expect(harness.gate.activeAttemptID == nil)
    }

    @Test("a cancel by the person never starts the sheet again: after the window, after the prompt showed, or another error")
    func personCancelDoesNotRetry() async throws {
        let late = Harness()
        let lateFinishes = FinishLog()
        _ = await late.flow.begin(provider: .google) { lateFinishes.record($0) }
        late.clock.advance(NativeBrowserOAuthSignIn.earlyCancelWindow + 0.1)
        await late.sheets.close(0, error: systemCancel)
        #expect(lateFinishes.names == ["canceled"])
        #expect(late.sheets.sessions.count == 1)

        let shown = Harness()
        let shownFinishes = FinishLog()
        _ = await shown.flow.begin(provider: .google) { shownFinishes.record($0) }
        shown.sheets.sessions[0].systemUIAppeared = true
        shown.clock.advance(0.3)
        await shown.sheets.close(0, error: systemCancel)
        #expect(shownFinishes.names == ["canceled"])
        #expect(shown.sheets.sessions.count == 1)

        let other = Harness()
        let otherFinishes = FinishLog()
        _ = await other.flow.begin(provider: .google) { otherFinishes.record($0) }
        other.clock.advance(0.1)
        await other.sheets.close(0, error: URLError(.userCancelledAuthentication))
        #expect(otherFinishes.names == ["canceled"])
        #expect(other.sheets.sessions.count == 1)
        #expect(other.pauses.all.isEmpty)
    }

    @Test("iOS: a system cancel 5 s after start, with nothing shown, still gets one fresh sheet; a second one finishes as canceled")
    func iOSLateEarlyCancelRetries() async throws {
        // CI run 43312729950: the cancel came 5242 ms after start, 13 ms after swcd's "app PI changed".
        let harness = Harness(earlyCancelWindow: nil)
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }

        harness.clock.advance(5.242)
        await harness.sheets.close(0, error: systemCancel)
        await harness.flow.retryTask?.value
        #expect(finishes.names.isEmpty)
        #expect(harness.sheets.sessions.map(\.startCount) == [1, 1])

        harness.clock.advance(5)
        await harness.sheets.close(1, error: systemCancel)
        #expect(finishes.names == ["canceled"])
        #expect(harness.sheets.sessions.count == 2)
        #expect(harness.logs.lines.last ==
            "Browser sign-in ended without a callback: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 5000 ms, systemUIAppeared=false, presentedVC=false")
    }

    @Test("macOS: the same 5 s cancel is outside the window and finishes as canceled")
    func macLateCancelDoesNotRetry() async throws {
        let harness = Harness(earlyCancelWindow: NativeBrowserOAuthEarlyCancel.window)
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        harness.clock.advance(5.242)
        await harness.sheets.close(0, error: systemCancel)
        #expect(finishes.names == ["canceled"])
        #expect(harness.sheets.sessions.count == 1)
        #expect(harness.pauses.all.isEmpty)
    }

    private enum Shown: CaseIterable {
        case resignedActive, presentedViewController, both
    }

    @Test("the person's Cancel after the sheet was shown never relaunches it, early or late, on either platform")
    func personCancelAfterSheetShown() async throws {
        for window in [nil, NativeBrowserOAuthEarlyCancel.window] {
            for seconds in [0.3, 5.242] {
                for shown in Shown.allCases {
                    let harness = Harness(earlyCancelWindow: window)
                    let finishes = FinishLog()
                    _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
                    harness.sheets.sessions[0].systemUIAppeared = shown != .presentedViewController
                    harness.sheets.sessions[0].presentedViewController = shown != .resignedActive
                    harness.clock.advance(seconds)
                    await harness.sheets.close(0, error: systemCancel)
                    let label = Comment(rawValue: "window \(String(describing: window)) after \(seconds) s, \(shown)")
                    #expect(finishes.names == ["canceled"], label)
                    #expect(harness.sheets.sessions.count == 1, label)
                    #expect(harness.pauses.all.isEmpty, label)
                    #expect(harness.flow.retryTask == nil, label)
                }
            }
        }
    }

    @Test("a cancel by the app never starts the sheet again")
    func appCancelDoesNotRetry() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        harness.flow.cancel()
        #expect(finishes.names == ["canceled"])
        #expect(harness.sheets.sessions.count == 1)
        #expect(harness.pauses.all.isEmpty)
    }

    @Test("a newer start or the app's cancel during the retry pause wins, and the old retry never starts a sheet")
    func supersedeDuringRetryPause() async throws {
        let gate = NativeBrowserOAuthGate()
        let latchA = Latch()
        let windowA = Harness(gate: gate, pauseLatch: latchA)
        let windowB = Harness(gate: gate)
        let finishesA = FinishLog()
        _ = await windowA.flow.begin(provider: .google) { finishesA.record($0) }
        windowA.clock.advance(0.2)
        await windowA.sheets.close(0, error: systemCancel)
        let closing = try #require(windowA.flow.retryTask)
        await latchA.waitUntilReached()

        _ = await windowB.flow.begin(provider: .google) { _ in }
        #expect(finishesA.names == ["superseded"])
        await latchA.open()
        await closing.value
        #expect(windowA.sheets.sessions.count == 1)
        #expect(windowA.flow.attempt == nil)
        #expect(gate.activeAttemptID == windowB.flow.attempt?.id)

        let latchC = Latch()
        let windowC = Harness(pauseLatch: latchC)
        let finishesC = FinishLog()
        _ = await windowC.flow.begin(provider: .google) { finishesC.record($0) }
        windowC.clock.advance(0.2)
        await windowC.sheets.close(0, error: systemCancel)
        let closingC = try #require(windowC.flow.retryTask)
        await latchC.waitUntilReached()
        windowC.flow.cancel()
        await latchC.open()
        await closingC.value
        #expect(finishesC.names == ["canceled"])
        #expect(windowC.sheets.sessions.count == 1)
        #expect(!windowC.flow.isInProgress)
    }

    @Test("a second close from the old sheet during the retry pause ends the attempt, and the retry opens nothing")
    func closeDuringRetryPauseEndsAttempt() async throws {
        let latch = Latch()
        let harness = Harness(pauseLatch: latch)
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        harness.clock.advance(0.2)
        await harness.sheets.close(0, error: systemCancel)
        let retry = try #require(harness.flow.retryTask)
        await latch.waitUntilReached()

        // The pause has dropped the sheet, so nothing says whether the system showed anything: no second retry.
        await harness.sheets.close(0, error: systemCancel)
        #expect(finishes.names == ["canceled"])
        await latch.open()
        await retry.value
        #expect(harness.sheets.sessions.count == 1)
        #expect(!harness.flow.isInProgress)
        #expect(harness.logs.lines.last?.contains("systemUIAppeared=true, presentedVC=true") == true)
    }

    @Test("the default pause waits before the retry sheet opens")
    func defaultRetryPause() async throws {
        let harness = Harness()
        let flow = NativeBrowserOAuthSignIn(
            repository: harness.repository,
            gate: harness.gate,
            uptime: { [clock = harness.clock] in clock.now },
            earlyCancelWindow: NativeBrowserOAuthEarlyCancel.window,
            makeSession: harness.sheets.make
        )
        _ = await flow.begin(provider: .google) { _ in }
        harness.clock.advance(0.2)
        await harness.sheets.close(0, error: systemCancel)
        await flow.retryTask?.value
        #expect(harness.sheets.sessions.map(\.startCount) == [1, 1])
    }

    @Test("a retry the system will not start logs that and finishes the attempt as canceled")
    func retryThatDoesNotStartFinishesCanceled() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        harness.sheets.startResults[1] = false

        harness.clock.advance(0.2)
        await harness.sheets.close(0, error: systemCancel)
        await harness.flow.retryTask?.value

        #expect(finishes.names == ["canceled"])
        #expect(harness.sheets.sessions.map(\.startCount) == [1, 1])
        #expect(harness.logs.lines.last == NativeBrowserOAuthEarlyCancel.retryDidNotStartMessage)
        #expect(harness.flow.attempt == nil)
        #expect(harness.gate.activeAttemptID == nil)
    }

    @Test("a sign-in whose owner goes away during the retry pause opens no sheet")
    func ownerGoneDuringRetryPause() async throws {
        let harness = Harness()
        let latch = Latch()
        let sheets = FakeSheets(startResult: true)
        let clock = TestClock()
        var flow: NativeBrowserOAuthSignIn? = NativeBrowserOAuthSignIn(
            repository: harness.repository,
            gate: NativeBrowserOAuthGate(),
            randomSecret: OAuthPKCE.randomVerifier,
            uptime: { [clock] in clock.now },
            pause: { _ in await latch.reach() },
            log: { _ in },
            makeSession: sheets.make
        )
        _ = await flow?.begin(provider: .google) { _ in }
        clock.advance(0.2)
        await sheets.close(0, error: systemCancel)
        let retry = try #require(flow?.retryTask)
        await latch.waitUntilReached()

        weak let gone = flow
        flow = nil
        #expect(gone == nil)
        await latch.open()
        await retry.value
        #expect(sheets.sessions.count == 1)
    }

    @Test("each tap starts a fresh attempt with its own state, verifier and sheet")
    func eachTapStartsAFreshAttempt() async throws {
        let harness = Harness()
        let finishes = FinishLog()

        #expect(await harness.flow.begin(provider: .google) { finishes.record($0) } != .couldNotOpen)
        let first = try #require(harness.flow.attempt)
        await harness.sheets.close(0)
        #expect(await harness.flow.begin(provider: .google) { finishes.record($0) } != .couldNotOpen)
        let second = try #require(harness.flow.attempt)

        #expect(first.id != second.id)
        #expect(first.state != second.state)
        #expect(first.codeVerifier != second.codeVerifier)
        #expect(first.state.rawValue != first.codeVerifier)
        #expect(OAuthPKCE.isValidVerifier(first.state.rawValue))
        #expect(OAuthPKCE.isValidVerifier(second.codeVerifier))
        #expect(stateParameter(of: first.authorizationURL) == first.state.rawValue)
        #expect(stateParameter(of: second.authorizationURL) == second.state.rawValue)
        #expect(harness.sheets.sessions.count == 2)
        #expect(finishes.names == ["canceled"])
    }

    @Test("a double tap starts one server flow, while registering, while the sheet is open and while finishing")
    func doubleTapStartsOneServerFlow() async throws {
        let registration = Latch()
        let exchange = Latch()
        let harness = Harness(registrationLatch: registration, exchangeLatch: exchange)
        let finishes = FinishLog()

        // Second tap while the client registration is still in flight.
        var returns = 0
        let firstTap = Task {
            await harness.flow.begin(provider: .google, onReturn: { returns += 1 }) { finishes.record($0) }
        }
        await registration.waitUntilReached()
        #expect(harness.flow.isInProgress)
        #expect(await harness.flow.begin(provider: .google) { _ in Issue.record("A refused tap must not finish") } == .alreadyInProgress)
        await registration.open()
        let firstStart = await firstTap.value
        #expect(firstStart != .couldNotOpen)
        let attempt = try #require(harness.flow.attempt)

        // A retry while the sheet is open.
        #expect(await harness.flow.begin(provider: .google) { _ in Issue.record("A refused tap must not finish") } == .alreadyInProgress)
        #expect(await harness.flow.begin(provider: .github) { _ in Issue.record("A refused tap must not finish") } == .alreadyInProgress)

        // And while the code exchange runs after the callback.
        let callback = Task { await harness.sheets.complete(0, with: serverCallback(code: "oac_code", state: attempt.state)) }
        await exchange.waitUntilReached()
        #expect(returns == 1)
        #expect(harness.flow.isInProgress)
        #expect(await harness.flow.begin(provider: .google) { _ in Issue.record("A refused tap must not finish") } == .alreadyInProgress)
        await exchange.open()
        await callback.value

        #expect(await harness.network.registrations == 1)
        #expect(harness.sheets.sessions.count == 1)
        #expect(await harness.network.exchanges.count == 1)
        #expect(finishes.names == ["signedIn"])
        #expect(!harness.flow.isInProgress)
    }

    @Test("the exact redirect the server sends back (code, state and iss) signs in with that attempt's verifier")
    func exactServerRedirectSignsIn() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        let attempt = try #require(harness.flow.attempt)

        // spoonjoy-v2 app/lib/oauth-routes.server.ts: new URL(redirectUri) with code, state and iss set.
        await harness.sheets.complete(0, with: serverCallback(code: "oac_code", state: attempt.state))

        #expect(finishes.names == ["signedIn"])
        #expect(await harness.network.exchanges == [
            Exchange(
                clientID: Harness.clientID,
                redirectURI: "https://spoonjoy.app/oauth/callback",
                code: "oac_code",
                codeVerifier: attempt.codeVerifier
            )
        ])
        #expect(try await harness.vault.loadSession()?.accessToken == "sj_access")
        #expect(harness.flow.attempt == nil)
        #expect(harness.gate.activeAttemptID == nil)
    }

    @Test("a return with another attempt's state is refused before any code exchange")
    func returnWithAnotherStateIsRefused() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        let attempt = try #require(harness.flow.attempt)
        let other = try #require(OAuthState(rawValue: "an-older-attempts-state"))

        await harness.sheets.complete(0, with: serverCallback(code: "oac_code", state: other))

        #expect(finishes.all.count == 1)
        guard case .failed(let error) = finishes.all.first else {
            Issue.record("Expected a failed finish, got \(finishes.names)")
            return
        }
        #expect(error as? NativeAuthSessionError == .stateMismatch(expected: attempt.state.rawValue, actual: other.rawValue))
        #expect(await harness.network.exchanges.isEmpty)
        #expect(!harness.flow.isInProgress)
    }

    @Test("a server error return (error, state and iss) ends the attempt without an exchange")
    func serverErrorReturnEndsAttempt() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        let attempt = try #require(harness.flow.attempt)

        // spoonjoy-v2 redirectBackWithError: error, state and iss.
        await harness.sheets.complete(0, with: serverErrorCallback(error: "access_denied", state: attempt.state))

        guard case .failed(let error) = finishes.all.first else {
            Issue.record("Expected a failed finish, got \(finishes.names)")
            return
        }
        #expect(error as? NativeAuthSessionError == .authorizationFailed("access_denied"))
        #expect(await harness.network.exchanges.isEmpty)
        #expect(!harness.flow.isInProgress)

        // An error return carrying some other state is still a state mismatch.
        finishes.reset()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        let stale = try #require(OAuthState(rawValue: "stale"))
        await harness.sheets.complete(1, with: serverErrorCallback(error: "access_denied", state: stale))
        guard case .failed(let mismatch) = finishes.all.first,
              case .stateMismatch = mismatch as? NativeAuthSessionError else {
            Issue.record("Expected a state mismatch, got \(finishes.names)")
            return
        }
    }

    @Test("a closed sheet cleans up, its late callback is ignored, and the next tap starts fresh")
    func closedSheetCleansUp() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        let attempt = try #require(harness.flow.attempt)

        await harness.sheets.close(0)
        #expect(finishes.names == ["canceled"])
        #expect(harness.flow.attempt == nil)
        #expect(!harness.flow.isInProgress)
        #expect(harness.gate.activeAttemptID == nil)

        // The system delivering the old sheet's callback anyway reaches nothing.
        await harness.sheets.complete(0, with: serverCallback(code: "oac_code", state: attempt.state))
        #expect(await harness.network.exchanges.isEmpty)
        #expect(finishes.names == ["canceled"])

        #expect(await harness.flow.begin(provider: .google) { _ in } != .couldNotOpen)
        #expect(harness.flow.attempt?.state != attempt.state)
    }

    @Test("cancel closes the open sheet once and frees the gate")
    func cancelClosesTheSheet() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        harness.flow.cancel()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }

        harness.flow.cancel()
        harness.flow.cancel()

        #expect(harness.sheets.sessions.map(\.cancelCount) == [1])
        #expect(finishes.names == ["canceled"])
        #expect(harness.gate.activeAttemptID == nil)
        #expect(!harness.flow.isInProgress)
    }

    @Test("a newer start in another window closes the older sheet, whose late callback is ignored")
    func newerStartInAnotherWindowSupersedes() async throws {
        let gate = NativeBrowserOAuthGate()
        let windowA = Harness(gate: gate)
        let windowB = Harness(gate: gate)
        let finishesA = FinishLog()
        let finishesB = FinishLog()

        _ = await windowA.flow.begin(provider: .google) { finishesA.record($0) }
        let attemptA = try #require(windowA.flow.attempt)
        #expect(gate.activeAttemptID == attemptA.id)
        _ = await windowB.flow.begin(provider: .google) { finishesB.record($0) }
        let attemptB = try #require(windowB.flow.attempt)

        #expect(windowA.sheets.sessions.map(\.cancelCount) == [1])
        #expect(finishesA.names == ["superseded"])
        #expect(windowA.flow.attempt == nil)
        #expect(gate.activeAttemptID == attemptB.id)

        // The older sheet's callback (its server state was replaced by B's start) never reaches the exchange.
        await windowA.sheets.complete(0, with: serverCallback(code: "oac_old", state: attemptA.state))
        #expect(await windowA.network.exchanges.isEmpty)

        await windowB.sheets.complete(0, with: serverCallback(code: "oac_new", state: attemptB.state))
        #expect(finishesB.names == ["signedIn"])
        #expect(await windowB.network.exchanges.map(\.codeVerifier) == [attemptB.codeVerifier])
        #expect(gate.activeAttemptID == nil)
    }

    @Test("a sheet the system will not show, a failed registration or a bad secret leaves nothing open")
    func failedStartsLeaveNothingOpen() async throws {
        let refused = Harness(sheetStarts: false)
        #expect(await refused.flow.begin(provider: .google) { _ in Issue.record("Nothing opened") } == .couldNotOpen)
        #expect(refused.sheets.sessions.map(\.startCount) == [1])
        #expect(!refused.flow.isInProgress)
        #expect(refused.gate.activeAttemptID == nil)

        let offline = Harness(registrationFails: true)
        #expect(await offline.flow.begin(provider: .google) { _ in Issue.record("Nothing opened") } == .couldNotOpen)
        #expect(offline.sheets.sessions.isEmpty)
        #expect(!offline.flow.isInProgress)

        let badSecret = Harness(randomSecret: { "not a verifier" })
        #expect(await badSecret.flow.begin(provider: .google) { _ in Issue.record("Nothing opened") } == .couldNotOpen)
        let blankSecret = Harness(randomSecret: { " " })
        #expect(await blankSecret.flow.begin(provider: .google) { _ in Issue.record("Nothing opened") } == .couldNotOpen)
        #expect(await badSecret.network.registrations == 0)
        #expect(await blankSecret.network.registrations == 0)
    }

    @Test("a second callback for the same attempt is ignored")
    func duplicateCallbackIgnored() async throws {
        let harness = Harness()
        let finishes = FinishLog()
        _ = await harness.flow.begin(provider: .google) { finishes.record($0) }
        let attempt = try #require(harness.flow.attempt)
        let callback = serverCallback(code: "oac_code", state: attempt.state)

        await harness.sheets.complete(0, with: callback)
        await harness.sheets.complete(0, with: callback)

        #expect(finishes.names == ["signedIn"])
        #expect(await harness.network.exchanges.count == 1)
    }

    @Test("the app's own defaults: the shared gate and random 43-character secrets")
    func appDefaults() async throws {
        let harness = Harness()
        let sheets = FakeSheets(startResult: true)
        let flow = NativeBrowserOAuthSignIn(repository: harness.repository, makeSession: sheets.make)
        _ = await flow.begin(provider: .google) { _ in }
        let attempt = try #require(flow.attempt)

        #expect(NativeBrowserOAuthGate.shared.activeAttemptID == attempt.id)
        #expect(attempt.state.rawValue.count == 43)
        #expect(attempt.codeVerifier.count == 43)
        flow.cancel()
        #expect(NativeBrowserOAuthGate.shared.activeAttemptID == nil)
    }

    /// Optional and network-dependent: the live production chain from the URL the app builds, up to Google. Runs only
    /// with SPOONJOY_LIVE_OAUTH_CHAIN=1 (the simulator job sets it); it registers a public client the way the app's
    /// first sign-in does (one row in production per run, the cost of walking the real chain), and signs nobody in.
    @Test(
        "live: /oauth/authorize?provider=google redirects through /auth/google to accounts.google.com",
        .enabled(if: ProcessInfo.processInfo.environment["SPOONJOY_LIVE_OAUTH_CHAIN"] == "1")
    )
    func liveGoogleStartChain() async throws {
        let walker = RedirectWalker()
        let clientID = try await walker.registerClient()
        let vault = InMemoryTokenVault()
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            registerClient: { _, _ in clientID },
            exchangeCode: { _, _, _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            refresh: { _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            revoke: { _, _ in },
            serverBaseURL: URL(string: "https://spoonjoy.app")!
        )
        let sheets = FakeSheets(startResult: true)
        let flow = NativeBrowserOAuthSignIn(repository: repository, gate: NativeBrowserOAuthGate(), makeSession: sheets.make)
        _ = await flow.begin(provider: .google) { _ in }
        let attempt = try #require(flow.attempt)

        let authorize = try await walker.get(attempt.authorizationURL)
        #expect(authorize.status == 302, "GET /oauth/authorize answered \(authorize.status)")
        let googleStartURL = try #require(authorize.location)
        #expect(googleStartURL.host == "spoonjoy.app")
        #expect(googleStartURL.path == "/auth/google")

        let googleStart = try await walker.get(googleStartURL)
        #expect(googleStart.status == 302, "GET /auth/google answered \(googleStart.status)")
        let google = try #require(googleStart.location.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(google.host == "accounts.google.com")
        #expect(google.path == "/o/oauth2/v2/auth")
        #expect(google.queryItems?.first { $0.name == "redirect_uri" }?.value == "https://spoonjoy.app/auth/google/callback")
        #expect(google.queryItems?.first { $0.name == "state" }?.value?.isEmpty == false)
        let cookie = try #require(googleStart.setCookies.first { $0.name == "__oauth" }, "GET /auth/google set no __oauth cookie")
        #expect(cookie.isHTTPOnly)
        #expect(cookie.isSecure)
        #expect(cookie.path == "/")
        #expect(cookie.sameSitePolicy == nil || cookie.sameSitePolicy?.rawValue.lowercased() == "none")
        flow.cancel()
    }
}

// MARK: - Harness

@MainActor
private final class Harness {
    nonisolated static let clientID = "cm_browser_sign_in"

    let vault: InMemoryTokenVault
    let network: NetworkSpy
    let sheets: FakeSheets
    let gate: NativeBrowserOAuthGate
    let repository: NativeAuthSessionRepository
    let flow: NativeBrowserOAuthSignIn
    let clock = TestClock()
    let pauses = PauseLog()
    let logs = LogLines()

    init(
        gate: NativeBrowserOAuthGate = NativeBrowserOAuthGate(),
        sheetStarts: Bool = true,
        registrationFails: Bool = false,
        registrationLatch: Latch? = nil,
        exchangeLatch: Latch? = nil,
        randomSecret: @escaping @MainActor () -> String = OAuthPKCE.randomVerifier,
        pauseLatch: Latch? = nil,
        earlyCancelWindow: TimeInterval? = NativeBrowserOAuthEarlyCancel.window
    ) {
        let vault = InMemoryTokenVault()
        let network = NetworkSpy(
            registrationFails: registrationFails,
            registrationLatch: registrationLatch,
            exchangeLatch: exchangeLatch
        )
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            registerClient: { name, redirectURI in try await network.register(name: name, redirectURI: redirectURI) },
            exchangeCode: { clientID, redirectURI, code, verifier in
                try await network.exchange(clientID: clientID, redirectURI: redirectURI, code: code, codeVerifier: verifier)
            },
            refresh: { _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            revoke: { _, _ in },
            reusesSavedClientID: false,
            serverBaseURL: URL(string: "https://spoonjoy.app")!
        )
        let sheets = FakeSheets(startResult: sheetStarts)
        self.vault = vault
        self.network = network
        self.sheets = sheets
        self.gate = gate
        self.repository = repository
        self.flow = NativeBrowserOAuthSignIn(
            repository: repository,
            gate: gate,
            randomSecret: randomSecret,
            uptime: { [clock] in clock.now },
            earlyCancelWindow: earlyCancelWindow,
            pause: { [pauses] duration in
                pauses.record(duration)
                await pauseLatch?.reach()
            },
            log: { [logs] in logs.lines.append($0) },
            makeSession: sheets.make
        )
    }
}

@MainActor
private final class TestClock {
    var now: TimeInterval = 1000

    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}

@MainActor
private final class PauseLog {
    private(set) var all: [Duration] = []

    func record(_ duration: Duration) {
        all.append(duration)
    }
}

@MainActor
private final class LogLines {
    var lines: [String] = []
}

/// ASWebAuthenticationSessionError.canceledLogin, as the system reports it.
private let systemCancel = NSError(domain: "com.apple.AuthenticationServices.WebAuthenticationSession", code: 1)

@MainActor
private final class FinishLog {
    private(set) var all: [NativeBrowserOAuthFinish] = []

    var names: [String] {
        all.map(describe)
    }

    func record(_ finish: NativeBrowserOAuthFinish) {
        all.append(finish)
    }

    func reset() {
        all = []
    }
}

private struct Exchange: Equatable, Sendable {
    let clientID: String
    let redirectURI: String
    let code: String
    let codeVerifier: String
}

private actor NetworkSpy {
    private let registrationFails: Bool
    private let registrationLatch: Latch?
    private let exchangeLatch: Latch?
    private(set) var registrations = 0
    private(set) var exchanges: [Exchange] = []

    init(registrationFails: Bool, registrationLatch: Latch?, exchangeLatch: Latch?) {
        self.registrationFails = registrationFails
        self.registrationLatch = registrationLatch
        self.exchangeLatch = exchangeLatch
    }

    func register(name: String, redirectURI: URL) async throws -> String {
        registrations += 1
        #expect(name == "Spoonjoy Apple")
        #expect(redirectURI.absoluteString == "https://spoonjoy.app/oauth/callback")
        await registrationLatch?.reach()
        if registrationFails {
            throw URLError(.notConnectedToInternet)
        }
        return Harness.clientID
    }

    func exchange(clientID: String, redirectURI: URL, code: String, codeVerifier: String) async throws -> OAuthTokenResponse {
        exchanges.append(Exchange(clientID: clientID, redirectURI: redirectURI.absoluteString, code: code, codeVerifier: codeVerifier))
        await exchangeLatch?.reach()
        return OAuthTokenResponse(
            accessToken: "sj_access",
            refreshToken: "ort_refresh",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: NativeAuthSession.defaultScope
        )
    }
}

/// Holds an async operation at a known point until the test opens it, so a test can tap while it is in flight
/// without sleeping.
private actor Latch {
    private var reached = false
    private var isOpen = false
    private var reachWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func reach() async {
        reached = true
        reachWaiters.forEach { $0.resume() }
        reachWaiters = []
        guard !isOpen else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilReached() async {
        guard !reached else { return }
        await withCheckedContinuation { reachWaiters.append($0) }
    }

    func open() {
        isOpen = true
        openWaiters.forEach { $0.resume() }
        openWaiters = []
    }
}

@MainActor
private final class FakeSheets {
    struct Opened {
        let authorizationURL: URL
        let redirectURI: URL
        let completion: @MainActor (URL?, (any Error)?) async -> Void
    }

    private let startResult: Bool
    /// Overrides `startResult` for the sheet at that index.
    var startResults: [Int: Bool] = [:]
    private(set) var opened: [Opened] = []
    private(set) var sessions: [FakeSheet] = []

    init(startResult: Bool) {
        self.startResult = startResult
    }

    func make(
        authorizationURL: URL,
        redirectURI: URL,
        completion: @escaping @MainActor (URL?, (any Error)?) async -> Void
    ) -> any NativeBrowserOAuthWebSession {
        opened.append(Opened(authorizationURL: authorizationURL, redirectURI: redirectURI, completion: completion))
        let sheet = FakeSheet(startResult: startResults[sessions.count] ?? startResult)
        sessions.append(sheet)
        return sheet
    }

    func complete(_ index: Int, with callbackURL: URL) async {
        await opened[index].completion(callbackURL, nil)
    }

    func close(_ index: Int, error: any Error = URLError(.userCancelledAuthentication)) async {
        await opened[index].completion(nil, error)
    }
}

@MainActor
private final class FakeSheet: NativeBrowserOAuthWebSession {
    private let startResult: Bool
    private(set) var startCount = 0
    private(set) var cancelCount = 0
    var systemUIAppeared = false
    var presentedViewController = false

    init(startResult: Bool) {
        self.startResult = startResult
    }

    func start() -> Bool {
        startCount += 1
        return startResult
    }

    func cancel() {
        cancelCount += 1
    }
}

// MARK: - Live chain

private struct RedirectStep {
    let status: Int
    let location: URL?
    let setCookies: [HTTPCookie]
}

private final class RedirectWalker: NSObject, URLSessionTaskDelegate, Sendable {
    private let session: URLSession

    override init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration)
        super.init()
    }

    func registerClient() async throws -> String {
        let builder = try OAuthRequests.registerClient(
            clientName: "Spoonjoy Apple",
            redirectURIs: [NativeAuthSession.redirectURI]
        )
        var request = URLRequest(url: URL(string: "https://spoonjoy.app/oauth/register")!)
        request.httpMethod = "POST"
        request.httpBody = builder.body
        builder.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        try #require((200...299).contains(status), "POST /oauth/register answered \(status)")
        return try JSONDecoder().decode(OAuthRegisterResponse.self, from: data).clientID
    }

    func get(_ url: URL) async throws -> RedirectStep {
        let (_, response) = try await session.data(for: URLRequest(url: url), delegate: self)
        let http = try #require(response as? HTTPURLResponse)
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, field in
            if let name = field.key as? String, let value = field.value as? String {
                result[name] = value
            }
        }
        let location = http.value(forHTTPHeaderField: "Location").flatMap { URL(string: $0, relativeTo: url)?.absoluteURL }
        return RedirectStep(
            status: http.statusCode,
            location: location,
            setCookies: HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}

// MARK: - Helpers

private func serverCallback(code: String, state: OAuthState) -> URL {
    var url = URLComponents(string: "https://spoonjoy.app/oauth/callback")!
    url.queryItems = [
        URLQueryItem(name: "code", value: code),
        URLQueryItem(name: "state", value: state.rawValue)
    ]
    // URLSearchParams encodes the issuer's colon and slashes, as the server's Location header carries them.
    return URL(string: url.string! + "&iss=https%3A%2F%2Fspoonjoy.app")!
}

private func serverErrorCallback(error: String, state: OAuthState) -> URL {
    var url = URLComponents(string: "https://spoonjoy.app/oauth/callback")!
    url.queryItems = [
        URLQueryItem(name: "error", value: error),
        URLQueryItem(name: "state", value: state.rawValue)
    ]
    return URL(string: url.string! + "&iss=https%3A%2F%2Fspoonjoy.app")!
}

private func stateParameter(of url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value
}

private func s256(_ verifier: String) -> String {
    Data(SHA256.hash(data: Data(verifier.utf8)))
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func describe(_ finish: NativeBrowserOAuthFinish) -> String {
    switch finish {
    case .signedIn:
        "signedIn"
    case .failed(let error):
        "failed(\(error))"
    case .canceled:
        "canceled"
    case .superseded:
        "superseded"
    }
}
