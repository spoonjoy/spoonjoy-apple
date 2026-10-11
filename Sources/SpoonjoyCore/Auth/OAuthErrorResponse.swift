import Foundation

/// Reads the RFC 6749 error body the server sends from its OAuth endpoints (`{"error": ..., "error_description": ...}`)
/// and maps URL loading failures the way the rest of the app does, so the token refresh can tell "the server
/// refused this refresh token" from "something between us and the server answered with a 4xx".
public enum OAuthErrorResponse {
    /// An extension field on the error body that marks a refresh token the chef revoked on purpose ("sign out
    /// everywhere", a password change, account deletion), as opposed to one that merely expired or is unknown.
    public static let reasonKey = "reason"
    public static let userRevokedReason = "revoked_by_user"

    /// The OAuth error codes that mean this refresh token (or its client) can never work again.
    static let permanentErrorCodes: Set<String> = ["invalid_grant", "invalid_client"]

    private struct Body: Decodable {
        let error: String
        let errorDescription: String?
        let reason: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
            case reason
        }
    }

    /// The transport error for an OAuth endpoint answer that carries a JSON OAuth error body, or nil when the
    /// answer is something else (an HTML page from a proxy, a plain-text 404, an empty body).
    public static func transportError(
        statusCode: Int,
        isJSON: Bool,
        data: Data,
        requestID: String?,
        retryAfterSeconds: Int?
    ) -> APITransportError? {
        guard isJSON,
              let body = try? JSONDecoder().decode(Body.self, from: data),
              !body.error.isEmpty else {
            return nil
        }
        var details: [String: JSONValue] = [:]
        if let reason = body.reason, !reason.isEmpty {
            details[reasonKey] = .string(reason)
        }
        let apiError = APIError(
            requestID: requestID ?? "unknown",
            code: body.error,
            message: body.errorDescription ?? body.error,
            status: statusCode,
            retryAfterSeconds: retryAfterSeconds,
            details: details
        )
        return APITransportError(
            kind: .apiError,
            requestID: apiError.requestID,
            statusCode: statusCode,
            apiError: apiError,
            retryDecision: APIRetryPolicy.decision(for: apiError)
        )
    }

    /// The offline transport error for a URL loading failure that means "no usable network", or nil for any
    /// other failure.
    public static func offlineError(for error: URLError) -> APITransportError? {
        guard URLSessionAPITransport.isOffline(error.code) else {
            return nil
        }
        return APITransportError(
            kind: .offline,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .retrySameRequest(afterSeconds: nil)
        )
    }

    /// True when the server refused the refresh token for good: an `invalid_grant` or `invalid_client` OAuth
    /// error. Anything else (a proxy's HTML 403, a 404, a 413, a 5xx, a timeout) says nothing about the token.
    static func isPermanentRefusal(_ error: Error) -> Bool {
        guard let transport = error as? APITransportError,
              let apiError = transport.apiError,
              let status = transport.statusCode,
              (400...401).contains(status) else {
            return false
        }
        return permanentErrorCodes.contains(apiError.code)
    }

    /// True when a refusal says the chef revoked the session on purpose.
    static func isUserRevocation(_ error: Error) -> Bool {
        guard let transport = error as? APITransportError,
              case .string(let reason)? = transport.apiError?.details[reasonKey] else {
            return false
        }
        return reason == userRevokedReason
    }
}
