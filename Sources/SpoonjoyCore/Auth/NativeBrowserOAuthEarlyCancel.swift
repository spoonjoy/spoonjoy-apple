import Foundation

/// Right after the app is installed or updated, iOS can end a browser sign-in session by itself: the session
/// finishes with ASWebAuthenticationSessionError.canceledLogin (code 1) within a few hundred milliseconds of
/// `start()`, before any prompt, while swcd re-fetches spoonjoy.app's association because the app's install identity
/// changed (spoonjoy-apple#320). The person sees nothing happen. The app then starts one fresh session.
///
/// A Cancel tapped by the person reports the same error, so a retry needs both: nothing the system shows for the
/// session has appeared (on iOS the "wants to use spoonjoy.app to sign in" prompt always comes first and makes the
/// app resign active), and the cancel came within `window` of `start()`.
public enum NativeBrowserOAuthEarlyCancel {
    public static let window: TimeInterval = 1.5
    /// How long to wait before the one retry, so the fetch the cancel came from can finish.
    public static let retryDelay: Duration = .milliseconds(750)

    /// ASWebAuthenticationSessionError.canceledLogin.
    public static func isSystemCancel(_ error: (any Error)?) -> Bool {
        guard let error else { return false }
        let nsError = error as NSError
        return nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1
    }

    public static func shouldRetry(
        error: (any Error)?,
        secondsSinceStart: TimeInterval?,
        systemUIAppeared: Bool,
        alreadyRetried: Bool
    ) -> Bool {
        guard !alreadyRetried, !systemUIAppeared, isSystemCancel(error), let secondsSinceStart else {
            return false
        }
        return secondsSinceStart >= 0 && secondsSinceStart < window
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
        "Browser sign-in early cancel: \(error.map(diagnosticReason) ?? "no error") after \(milliseconds(secondsSinceStart)) ms with nothing shown; retrying once"
    }

    public static func endedMessage(error: (any Error)?, secondsSinceStart: TimeInterval?) -> String {
        "Browser sign-in ended without a callback: \(error.map(diagnosticReason) ?? "no error") after \(milliseconds(secondsSinceStart)) ms"
    }
}
