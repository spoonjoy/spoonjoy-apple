import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Browser sign-in early cancel")
struct NativeBrowserOAuthEarlyCancelTests {
    private let systemCancel = NSError(domain: "com.apple.AuthenticationServices.WebAuthenticationSession", code: 1)

    private func retries(
        _ error: (any Error)? = nil,
        after seconds: TimeInterval?,
        systemUIAppeared: Bool = false,
        presentedViewController: Bool = false,
        window: TimeInterval?
    ) -> Bool {
        NativeBrowserOAuthEarlyCancel.shouldRetry(
            error: error ?? systemCancel,
            secondsSinceStart: seconds,
            systemUIAppeared: systemUIAppeared,
            presentedViewController: presentedViewController,
            window: window
        )
    }

    @Test("iOS: a system cancel with nothing shown is retried, however late it comes")
    func iOSRetryRule() {
        // CI run 43312729950: the cancel came 5242 ms after start, 13 ms after swcd's "app PI changed".
        for seconds in [0.2, 5.242, 30] {
            #expect(retries(after: seconds, window: nil))
        }
        // The person's Cancel: the prompt made the app resign active, or a view controller was presented.
        for seconds in [0.2, 5.242] {
            #expect(!retries(after: seconds, systemUIAppeared: true, window: nil))
            #expect(!retries(after: seconds, presentedViewController: true, window: nil))
        }
    }

    @Test("the retries back off over about 15 s and then stop")
    func retryBackoff() {
        // swcd's re-sync in CI run 43353272527 ran about 10 s, and a retry 750 ms in was cancelled too (#344).
        #expect(NativeBrowserOAuthEarlyCancel.retryDelays == [.milliseconds(750), .seconds(2), .seconds(4), .seconds(8)])
        #expect((0..<4).map { NativeBrowserOAuthEarlyCancel.retryDelay(afterRetries: $0) } == NativeBrowserOAuthEarlyCancel.retryDelays)
        #expect(NativeBrowserOAuthEarlyCancel.retryDelay(afterRetries: 4) == nil)
        #expect(NativeBrowserOAuthEarlyCancel.retryDelay(afterRetries: -1) == nil)
        #expect(NativeBrowserOAuthEarlyCancel.RetriesExhausted() == NativeBrowserOAuthEarlyCancel.RetriesExhausted())
    }

    @Test("macOS: only a system cancel within the window, with nothing shown, is retried")
    func macRetryRule() {
        let window = NativeBrowserOAuthEarlyCancel.window
        #expect(retries(after: 0.2, window: window))
        #expect(!retries(after: 5.242, window: window))
        #expect(!retries(after: window, window: window))
        #expect(!retries(after: 0.2, systemUIAppeared: true, window: window))
        #expect(!retries(after: 0.2, presentedViewController: true, window: window))
    }

    @Test("this platform's time limit is none on iOS and the window everywhere else")
    func platformWindow() {
        #if os(iOS)
        #expect(NativeBrowserOAuthEarlyCancel.platformWindow == nil)
        #else
        #expect(NativeBrowserOAuthEarlyCancel.platformWindow == NativeBrowserOAuthEarlyCancel.window)
        #endif
    }

    @Test("only ASWebAuthenticationSession's canceledLogin, with a known start time, is ever retried")
    func onlySystemCancelIsRetried() {
        for window in [nil, NativeBrowserOAuthEarlyCancel.window] {
            #expect(!retries(URLError(.userCancelledAuthentication), after: 0.2, window: window))
            #expect(!retries(NSError(domain: "com.apple.AuthenticationServices.WebAuthenticationSession", code: 2), after: 0.2, window: window))
            #expect(!NativeBrowserOAuthEarlyCancel.shouldRetry(
                error: nil, secondsSinceStart: 0.2, systemUIAppeared: false, presentedViewController: false,
                window: window
            ))
            #expect(!retries(after: nil, window: window))
            #expect(!retries(after: -1, window: window))
        }
    }

    @Test("the timing clock moves forward")
    func monotonicClock() async throws {
        let first = NativeBrowserOAuthEarlyCancel.monotonicSeconds()
        try await Task.sleep(for: .milliseconds(20))
        let second = NativeBrowserOAuthEarlyCancel.monotonicSeconds()
        // Only the direction is checked: a loaded runner can hold this task far past the sleep (#343).
        #expect(second > first)
    }

    @Test("the log lines carry the domain, code and timing, never a description")
    func logLines() {
        #expect(NativeBrowserOAuthEarlyCancel.earlyCancelMessage(error: systemCancel, secondsSinceStart: 0.1754, retry: 2) ==
            "Browser sign-in early cancel: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 175 ms, systemUIAppeared=false, presentedVC=false; retry 2 of 4")
        #expect(NativeBrowserOAuthEarlyCancel.exhaustedMessage(error: systemCancel, secondsSinceStart: 0.246) ==
            "Browser sign-in early cancel: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 246 ms, systemUIAppeared=false, presentedVC=false; all 4 retries used")
        #expect(NativeBrowserOAuthEarlyCancel.exhaustedMessage(error: nil, secondsSinceStart: nil) ==
            "Browser sign-in early cancel: no error after unknown ms, systemUIAppeared=false, presentedVC=false; all 4 retries used")
        #expect(NativeBrowserOAuthEarlyCancel.endedMessage(error: systemCancel, secondsSinceStart: 4, systemUIAppeared: true, presentedViewController: false) ==
            "Browser sign-in ended without a callback: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 4000 ms, systemUIAppeared=true, presentedVC=false")
        #expect(NativeBrowserOAuthEarlyCancel.endedMessage(error: nil, secondsSinceStart: nil, systemUIAppeared: false, presentedViewController: true) ==
            "Browser sign-in ended without a callback: no error after unknown ms, systemUIAppeared=false, presentedVC=true")
        let secret = NSError(domain: "x", code: 7, userInfo: [NSLocalizedDescriptionKey: "https://spoonjoy.app/oauth/callback?code=oac_secret"])
        #expect(!NativeBrowserOAuthEarlyCancel.endedMessage(error: secret, secondsSinceStart: 1, systemUIAppeared: false, presentedViewController: false).contains("oac_secret"))
        let transport = APITransportError(kind: .apiError, requestID: "req_1", statusCode: 503, apiError: nil, retryDecision: .doNotRetry)
        #expect(NativeBrowserOAuthEarlyCancel.diagnosticReason(transport) == "apiError status 503 request req_1")
        let bare = APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        #expect(NativeBrowserOAuthEarlyCancel.diagnosticReason(bare) == "offline status none request none")
        #expect(NativeBrowserOAuthEarlyCancel.earlyCancelMessage(error: nil, secondsSinceStart: nil, retry: 1) ==
            "Browser sign-in early cancel: no error after unknown ms, systemUIAppeared=false, presentedVC=false; retry 1 of 4")
    }
}
