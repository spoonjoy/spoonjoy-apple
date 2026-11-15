import Foundation

/// The request a browser sign-in makes before its sheet opens (on a fresh install, the client registration) is the
/// app's first network request. It can fail fast on a network that is still coming up: in CI run 43312739328 it
/// failed as offline 0.5 s after the tap, and people saw "Could not open Google sign-in" in the first minute after
/// an install or update (spoonjoy-apple#314, #330). So a transient failure that came back fast is retried up to
/// twice, after `delays`, before the error shows. A slow failure or a timeout is not retried: the person has already
/// waited, and three 15 s timeouts would hold the spinner for most of a minute. The attempt stays busy across the waits, and it stops quietly if it stops being current
/// (cancelled, or a newer sign-in took over) during one.
public enum NativeBrowserOAuthStartRetry {
    /// The waits before the second and third tries: about 2.7 s in all before the error shows.
    public static let delays: [Duration] = [.milliseconds(700), .seconds(2)]
    /// A failure that took longer than this, from send to failure, is not retried.
    public static let fastFailureLimit: TimeInterval = 3

    /// A transient failure that came back within `fastFailureLimit` and was not a timeout.
    public static func shouldRetry(_ error: any Error, secondsTaken: TimeInterval) -> Bool {
        guard isTransient(error), secondsTaken < fastFailureLimit else {
            return false
        }
        let code = (error as? APITransportError)?.urlErrorCode ?? (error as? URLError)?.code.rawValue
        return code != URLError.Code.timedOut.rawValue
    }

    /// An offline or network-level failure: no usable answer came back. Never an HTTP status error, a cancellation,
    /// or anything that is not a transport error (a bad PKCE secret, a vault failure).
    public static func isTransient(_ error: any Error) -> Bool {
        if let transport = error as? APITransportError {
            return transport.kind == .offline || transport.kind == .networkFailure
        }
        // The OAuth requests rethrow a URLError that is not one of the offline codes (a TLS failure, a bad server
        // response) as is. Those are network-level too, apart from a cancel or a request the app built wrong.
        if let urlError = error as? URLError {
            return ![.cancelled, .badURL, .unsupportedURL, .userCancelledAuthentication].contains(urlError.code)
        }
        return false
    }

    public static func retriedMessage(error: any Error, attempt: Int) -> String {
        "Browser sign-in start retried after \(NativeBrowserOAuthEarlyCancel.diagnosticReason(error)) (attempt \(attempt))"
    }

    public static let abandonedMessage = "Browser sign-in start stopped: no longer the current attempt"

    /// Runs `operation`, retrying a fast transient failure (`shouldRetry`) after each of `delays`. Throws the last error once the tries
    /// run out or the error is not transient, and `CancellationError` when `isCurrent` turns false (or the task is
    /// cancelled) during a wait, so nothing starts for an attempt that was replaced.
    @MainActor
    public static func run<Value>(
        delays: [Duration] = delays,
        pause: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @MainActor () -> TimeInterval = { NativeBrowserOAuthEarlyCancel.monotonicSeconds() },
        isCurrent: @MainActor () -> Bool,
        log: @MainActor (String) -> Void,
        operation: @MainActor () async throws -> Value
    ) async throws -> Value {
        for (index, delay) in delays.enumerated() {
            let sentAt = now()
            do {
                return try await operation()
            } catch {
                guard shouldRetry(error, secondsTaken: now() - sentAt) else {
                    throw error
                }
                // Cancelled or replaced while the request was in flight: stop without logging a retry or waiting.
                guard !Task.isCancelled, isCurrent() else {
                    log(abandonedMessage)
                    throw CancellationError()
                }
                log(retriedMessage(error: error, attempt: index + 1))
                try await pause(delay)
                guard !Task.isCancelled, isCurrent() else {
                    log(abandonedMessage)
                    throw CancellationError()
                }
            }
        }
        return try await operation()
    }
}
