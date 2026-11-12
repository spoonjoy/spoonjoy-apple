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
        alreadyRetried: Bool = false,
        window: TimeInterval?
    ) -> Bool {
        NativeBrowserOAuthEarlyCancel.shouldRetry(
            error: error ?? systemCancel,
            secondsSinceStart: seconds,
            systemUIAppeared: systemUIAppeared,
            presentedViewController: presentedViewController,
            alreadyRetried: alreadyRetried,
            window: window
        )
    }

    @Test("iOS: a system cancel with nothing shown is retried once, however late it comes")
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
        #expect(!retries(after: 5.242, alreadyRetried: true, window: nil))
    }

    @Test("macOS: only a system cancel within the window, with nothing shown, is retried")
    func macRetryRule() {
        let window = NativeBrowserOAuthEarlyCancel.window
        #expect(retries(after: 0.2, window: window))
        #expect(!retries(after: 5.242, window: window))
        #expect(!retries(after: window, window: window))
        #expect(!retries(after: 0.2, systemUIAppeared: true, window: window))
        #expect(!retries(after: 0.2, presentedViewController: true, window: window))
        #expect(!retries(after: 0.2, alreadyRetried: true, window: window))
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
                alreadyRetried: false, window: window
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
        #expect(second - first >= 0.015)
        #expect(second - first < 5)
    }

    @Test("the log lines carry the domain, code and timing, never a description")
    func logLines() {
        #expect(NativeBrowserOAuthEarlyCancel.earlyCancelMessage(error: systemCancel, secondsSinceStart: 0.1754) ==
            "Browser sign-in early cancel: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 175 ms, systemUIAppeared=false, presentedVC=false; retrying once")
        #expect(NativeBrowserOAuthEarlyCancel.endedMessage(error: systemCancel, secondsSinceStart: 4, systemUIAppeared: true, presentedViewController: false) ==
            "Browser sign-in ended without a callback: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 4000 ms, systemUIAppeared=true, presentedVC=false")
        #expect(NativeBrowserOAuthEarlyCancel.endedMessage(error: nil, secondsSinceStart: nil, systemUIAppeared: false, presentedViewController: true) ==
            "Browser sign-in ended without a callback: no error after unknown ms, systemUIAppeared=false, presentedVC=true")
        let secret = NSError(domain: "x", code: 7, userInfo: [NSLocalizedDescriptionKey: "https://spoonjoy.app/oauth/callback?code=oac_secret"])
        #expect(!NativeBrowserOAuthEarlyCancel.endedMessage(error: secret, secondsSinceStart: 1, systemUIAppeared: false, presentedViewController: false).contains("oac_secret"))
        let transport = APITransportError(kind: .apiError, requestID: "req_1", statusCode: 503, apiError: nil, retryDecision: .doNotRetry)
        #expect(NativeBrowserOAuthEarlyCancel.diagnosticReason(transport) == "apiError status 503 request req_1")
    }
}
