import Foundation

public enum APIRetryDecision: Equatable, Sendable {
    case retrySameRequest(afterSeconds: Int?)
    case refreshAuthentication
    case doNotRetry
}

public enum APIRetryPolicy {
    public static func decision(for error: APIError) -> APIRetryDecision {
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
