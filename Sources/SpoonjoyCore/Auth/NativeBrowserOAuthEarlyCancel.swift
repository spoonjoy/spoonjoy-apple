import Foundation

/// Right after the app is installed or updated, iOS can end a browser sign-in session by itself: the session
/// finishes with ASWebAuthenticationSessionError.canceledLogin (code 1) before any prompt, while swcd re-fetches
/// spoonjoy.app's association because the app's install identity changed (spoonjoy-apple#320). The person sees
/// nothing happen. The app then starts one fresh session.
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
/// after, 13 ms after swcd logged "app PI changed". If the resign signal ever failed to fire, a person's Cancel would
/// reopen the sheet once, which is bounded. On macOS and visionOS, where the signals are not guaranteed, the cancel
/// must also come within `window` of `start()`.
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
    /// How long to wait before the one retry, so the fetch the cancel came from can finish.
    public static let retryDelay: Duration = .milliseconds(750)

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

    /// `window` nil means no time limit (iOS).
    public static func shouldRetry(
        error: (any Error)?,
        secondsSinceStart: TimeInterval?,
        systemUIAppeared: Bool,
        presentedViewController: Bool,
        alreadyRetried: Bool,
        window: TimeInterval?
    ) -> Bool {
        guard !alreadyRetried, !systemUIAppeared, !presentedViewController, isSystemCancel(error),
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
            return "\(transport.kind) status \(transport.statusCode.map { String($0) } ?? "none") request \(transport.requestID ?? "none")"
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

    public static func earlyCancelMessage(error: (any Error)?, secondsSinceStart: TimeInterval?) -> String {
        "Browser sign-in early cancel: \(error.map(diagnosticReason) ?? "no error") after \(milliseconds(secondsSinceStart)) ms, systemUIAppeared=false, presentedVC=false; retrying once"
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
