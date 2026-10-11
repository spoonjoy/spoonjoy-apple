import Foundation

public enum APIRetryDecision: Equatable, Sendable {
    case retrySameRequest(afterSeconds: Int?)
    case refreshAuthentication
    case doNotRetry
}

public enum APIRetryPolicy {
    /// The server answers `temporarily_unavailable` (HTTP 503) when its database stopped answering for a moment.
    /// The same request, with the same `clientMutationId` for a write, is safe to send again after `Retry-After`.
    public static let temporarilyUnavailableCode = "temporarily_unavailable"
    /// The wait before retrying `temporarily_unavailable` when the response names none; the server's own default.
    public static let temporarilyUnavailableDefaultRetrySeconds = 1

    public static func decision(for error: APIError) -> APIRetryDecision {
        if error.code == temporarilyUnavailableCode {
            return .retrySameRequest(afterSeconds: error.retryAfterSeconds ?? temporarilyUnavailableDefaultRetrySeconds)
        }

        switch error.status {
        case 401:
            return .refreshAuthentication
        case 429:
            return .retrySameRequest(afterSeconds: error.retryAfterSeconds)
        case 500...599:
            return .retrySameRequest(afterSeconds: error.retryAfterSeconds)
        default:
            break
        }

        if error.code == "idempotency_in_progress" {
            return .retrySameRequest(afterSeconds: error.retryAfterSeconds)
        }

        return .doNotRetry
    }
}
