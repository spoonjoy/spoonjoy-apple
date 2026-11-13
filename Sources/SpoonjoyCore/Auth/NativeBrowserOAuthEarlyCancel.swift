import Foundation

/// Right after the app is installed or updated, iOS can end a browser sign-in session by itself: the session
/// finishes with ASWebAuthenticationSessionError.canceledLogin (code 1) before any prompt, while swcd re-fetches
/// spoonjoy.app's association because the app's install identity changed (spoonjoy-apple#320). The person sees
/// nothing happen. The app then starts a fresh session, backing off between attempts (`iOSRetryDelays`): swcd's re-sync
/// can take about 10 s, and a retry during it is cancelled the same way (spoonjoy-apple#344, CI run 43353272527:
/// the first retry, 750 ms later, ended after 246 ms with nothing shown).
///
/// A Cancel by the person reports the same error, so a retry needs proof that the system showed nothing for the
/// session. The primary signals, any one of which blocks the retry:
/// - The app was not active when the session started (Control Center, a call banner), or it resigned active
///   afterwards. On iOS the "wants to use spoonjoy.app to sign in" prompt always resigns it before the sheet, for a
///   non-ephemeral session (the app always asks for one).
/// - On iOS, the anchor window's scene deactivating (iPad multi-window).
/// - On macOS, a window beginning a sheet or resigning key, since the prompt and sheet attach to the app's own window
///   and the app may stay active.
/// A best-effort extra: a new view controller (on macOS, a sheet) seen on the anchor window at any of those moments
/// or when the cancel arrives. The system sheet is usually out of process and already gone by the cancel, so this
/// rarely fires, but it can only block a retry.
///
/// On iOS there is no time limit. The cancel can come seconds after `start()`: in CI run 43312729950 it came 5242 ms
/// after, 13 ms after swcd logged "app PI changed". If the resign signal ever failed to fire, a person's Cancel could
/// reopen the sheet up to `iOSRetryDelays.count` times, which is bounded. On macOS and visionOS, where the signals are
/// not guaranteed, each cancel must also come within `window` of its session's `start()`.
public enum NativeBrowserOAuthEarlyCancel {
    /// The time limit outside iOS. See `platformWindow`.
    public static let window: TimeInterval = 1.5
    /// The time limit for a retry on this platform: none on iOS, `window` everywhere else (macOS, and visionOS, where
    /// the resign-active premise has not been verified).
    public static var platformWindow: TimeInterval? {
        #if os(iOS)
        nil
        #else
        window
        #endif
    }
    /// The wait before each retry on iOS, so the fetch the cancel came from can finish. Together they span about 15 s,
    /// past the roughly 10 s re-sync in CI run 43353272527 (spoonjoy-apple#344). Their count is the most retries.
    public static let iOSRetryDelays: [Duration] = [.milliseconds(750), .seconds(2), .seconds(4), .seconds(8)]
    /// The one retry everywhere else: the re-sync backoff (#344) was only ever seen on iOS.
    public static let otherRetryDelays: [Duration] = [.milliseconds(750)]
    /// The retry waits on this platform, chosen like `platformWindow`.
    public static var platformRetryDelays: [Duration] {
        #if os(iOS)
        iOSRetryDelays
        #else
        otherRetryDelays
        #endif
    }

    /// The wait before the next retry, after `retriesSoFar` retries; nil once `delays` are used up.
    public static func retryDelay(afterRetries retriesSoFar: Int, in delays: [Duration]) -> Duration? {
        delays.indices.contains(retriesSoFar) ? delays[retriesSoFar] : nil
    }

    /// Reported to the sign-in's cancellation handler when the sheet never opened: every retry was cancelled by the
    /// system with nothing shown, or the system would not start a retry. The person saw nothing to cancel, so the app
    /// tells them sign-in could not open.
    public struct CouldNotOpen: Error, Equatable, Sendable {
        public init() {}
    }

    /// What the sign-in is doing between attempts, for its owner's status line.
    public enum RetryPhase: Equatable, Sendable {
        /// Waiting before retry `retry` after the system's early cancel.
        case waiting(retry: Int)
        /// The retry's sheet started.
        case started
    }

    /// The status line for a retry phase.
    public static func status(for phase: RetryPhase, providerName: String) -> String {
        switch phase {
        case .waiting: "Opening \(providerName) sign-in."
        case .started: "Finish \(providerName) sign-in in the browser."
        }
    }

    /// The status line when a browser sign-in ends without a callback, and whether it reports a problem: the sheet
    /// never opening (`CouldNotOpen`) is one the person can act on; anything else is their cancel.
    public static func endedStatus(error: (any Error)?, providerName: String?) -> (text: String, isProblem: Bool) {
        guard error is CouldNotOpen else {
            return ("Browser sign-in canceled.", false)
        }
        return ("Could not open \(providerName.map { "\($0) " } ?? "")sign-in. Try again.", true)
    }

    /// Seconds since an arbitrary fixed point, on a clock that never jumps. The timing source for `window`.
    /// It avoids the uptime APIs, which Apple lists as required-reason APIs (system boot time).
    public static func monotonicSeconds() -> TimeInterval {
        let elapsed = clockOrigin.duration(to: .now)
        return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }

    private static let clockOrigin = ContinuousClock.now

    /// ASWebAuthenticationSessionError.canceledLogin.
    public static func isSystemCancel(_ error: (any Error)?) -> Bool {
        guard let error else { return false }
        let nsError = error as NSError
        return nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1
    }

    /// Whether this end is the system's own cancel with nothing shown, which earns a retry while the retry waits last.
    /// `window` nil means no time limit (iOS).
    public static func shouldRetry(
        error: (any Error)?,
        secondsSinceStart: TimeInterval?,
        systemUIAppeared: Bool,
        presentedViewController: Bool,
        window: TimeInterval?
    ) -> Bool {
        guard !systemUIAppeared, !presentedViewController, isSystemCancel(error),
              let secondsSinceStart, secondsSinceStart >= 0 else {
            return false
        }
        guard let window else { return true }
        return secondsSinceStart < window
    }

    /// A start failure or a session's cancel error for the log: the transport kind, status and request id, or the
    /// error's domain and code. Never the description, which can carry a URL or a server response.
    public static func diagnosticReason(_ error: any Error) -> String {
        if let transport = error as? APITransportError {
            let code = transport.urlErrorCode.map { " NSURLError \($0)" } ?? ""
            return "\(transport.kind)\(code) status \(transport.statusCode.map { String($0) } ?? "none") request \(transport.requestID ?? "none")"
        }
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code)"
    }

    public static func milliseconds(_ seconds: TimeInterval?) -> String {
        seconds.map { String(Int(($0 * 1000).rounded())) } ?? "unknown"
    }

    public static let startedMessage = "Browser sign-in sheet started"
    public static let retriedMessage = "Browser sign-in retried: sheet started again"
    public static let retryDidNotStartMessage = "Browser sign-in retry did not start"
    public static let callbackMessage = "Browser sign-in callback received"

    public static func earlyCancelMessage(error: (any Error)?, secondsSinceStart: TimeInterval?, retry: Int, of total: Int) -> String {
        "Browser sign-in early cancel: \(error.map(diagnosticReason) ?? "no error") after \(milliseconds(secondsSinceStart)) ms, systemUIAppeared=false, presentedVC=false; retry \(retry) of \(total)"
    }

    public static func exhaustedMessage(error: (any Error)?, secondsSinceStart: TimeInterval?, retries: Int) -> String {
        "Browser sign-in early cancel: \(error.map(diagnosticReason) ?? "no error") after \(milliseconds(secondsSinceStart)) ms, systemUIAppeared=false, presentedVC=false; all \(retries) retries used"
    }

    public static func endedMessage(
        error: (any Error)?,
        secondsSinceStart: TimeInterval?,
        systemUIAppeared: Bool,
        presentedViewController: Bool
    ) -> String {
        "Browser sign-in ended without a callback: \(error.map(diagnosticReason) ?? "no error") after \(milliseconds(secondsSinceStart)) ms, systemUIAppeared=\(systemUIAppeared), presentedVC=\(presentedViewController)"
    }
}
