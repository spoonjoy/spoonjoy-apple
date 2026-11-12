import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Browser sign-in early cancel")
struct NativeBrowserOAuthEarlyCancelTests {
    private let systemCancel = NSError(domain: "com.apple.AuthenticationServices.WebAuthenticationSession", code: 1)

    @Test("only a system cancel within the window, with nothing shown, and not retried yet, is retried")
    func retryRule() {
        #expect(NativeBrowserOAuthEarlyCancel.shouldRetry(error: systemCancel, secondsSinceStart: 0.2, systemUIAppeared: false, alreadyRetried: false))
        // The person's Cancel: the prompt or sheet had appeared.
        #expect(!NativeBrowserOAuthEarlyCancel.shouldRetry(error: systemCancel, secondsSinceStart: 0.2, systemUIAppeared: true, alreadyRetried: false))
        // After the window.
        #expect(!NativeBrowserOAuthEarlyCancel.shouldRetry(error: systemCancel, secondsSinceStart: 1.5, systemUIAppeared: false, alreadyRetried: false))
        // At most once per attempt.
        #expect(!NativeBrowserOAuthEarlyCancel.shouldRetry(error: systemCancel, secondsSinceStart: 0.2, systemUIAppeared: false, alreadyRetried: true))
        // Any other error, no error (the app's own cancel), or an unknown start time.
        #expect(!NativeBrowserOAuthEarlyCancel.shouldRetry(error: URLError(.userCancelledAuthentication), secondsSinceStart: 0.2, systemUIAppeared: false, alreadyRetried: false))
        #expect(!NativeBrowserOAuthEarlyCancel.shouldRetry(error: NSError(domain: "com.apple.AuthenticationServices.WebAuthenticationSession", code: 2), secondsSinceStart: 0.2, systemUIAppeared: false, alreadyRetried: false))
        #expect(!NativeBrowserOAuthEarlyCancel.shouldRetry(error: nil, secondsSinceStart: 0.2, systemUIAppeared: false, alreadyRetried: false))
        #expect(!NativeBrowserOAuthEarlyCancel.shouldRetry(error: systemCancel, secondsSinceStart: nil, systemUIAppeared: false, alreadyRetried: false))
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
            "Browser sign-in early cancel: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 175 ms, systemUIAppeared=false; retrying once")
        #expect(NativeBrowserOAuthEarlyCancel.endedMessage(error: systemCancel, secondsSinceStart: 4, systemUIAppeared: true) ==
            "Browser sign-in ended without a callback: com.apple.AuthenticationServices.WebAuthenticationSession 1 after 4000 ms, systemUIAppeared=true")
        #expect(NativeBrowserOAuthEarlyCancel.endedMessage(error: nil, secondsSinceStart: nil, systemUIAppeared: false) ==
            "Browser sign-in ended without a callback: no error after unknown ms, systemUIAppeared=false")
        let secret = NSError(domain: "x", code: 7, userInfo: [NSLocalizedDescriptionKey: "https://spoonjoy.app/oauth/callback?code=oac_secret"])
        #expect(!NativeBrowserOAuthEarlyCancel.endedMessage(error: secret, secondsSinceStart: 1, systemUIAppeared: false).contains("oac_secret"))
        let transport = APITransportError(kind: .apiError, requestID: "req_1", statusCode: 503, apiError: nil, retryDecision: .doNotRetry)
        #expect(NativeBrowserOAuthEarlyCancel.diagnosticReason(transport) == "apiError status 503 request req_1")
    }
}
