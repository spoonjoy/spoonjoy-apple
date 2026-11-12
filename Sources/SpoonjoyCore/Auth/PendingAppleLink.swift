import Foundation

/// An Apple sign-in the server verified but could not match to an account, because Apple sent no email and the
/// Apple ID is linked to no Spoonjoy account. The server answers `/api/v1/auth/apple/native` with
/// `validation_error` whose details carry `providerCode: "apple_email_unavailable"`, a `pendingAppleLinkToken` and
/// its `pendingAppleLinkExpiresAt` (spoonjoy-v2 `pending-apple-link.server.ts`). Sending that token with the next
/// password sign-in or browser code exchange links Apple to the account that signs in, once.
///
/// The token is a credential for that link: it is kept in memory only, never written to the vault, and never
/// printed. `description`, `debugDescription` and the mirror leave it out, so string interpolation, `dump` and
/// test failure output cannot leak it.
public struct PendingAppleLink: Equatable, Sendable {
    public static let providerCode = "apple_email_unavailable"
    public static let tokenDetailKey = "pendingAppleLinkToken"
    public static let expiresAtDetailKey = "pendingAppleLinkExpiresAt"
    /// The server's own lifetime for a pending link; used when the answer carries no expiry.
    public static let lifetime: TimeInterval = 30 * 60
    /// The server's longest accepted token (spoonjoy-v2 `MAX_TOKEN_LENGTH`).
    static let maxTokenLength = 128
    public static let defaultMessage =
        "We couldn't find a Spoonjoy account for this Apple ID yet. Sign in with Google or your password and we'll connect Apple for you."

    let token: String
    public let expiresAt: Date

    init?(token: String, expiresAt: Date) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxTokenLength else {
            return nil
        }
        self.token = trimmed
        self.expiresAt = expiresAt
    }

    public func isExpired(at date: Date) -> Bool {
        date >= expiresAt
    }

    /// The pending link an Apple sign-in failure carries, or nil when the failure is anything else. It expires on
    /// the device thirty minutes after `receivedAt`, the server's own lifetime. The server's
    /// `pendingAppleLinkExpiresAt` is server time; comparing it with a device clock that runs fast would drop the
    /// link early, and the server checks its own expiry anyway.
    public static func from(_ error: Error, receivedAt: Date) -> PendingAppleLink? {
        guard let apiError = appleEmailUnavailableError(error),
              case .string(let token)? = apiError.details[tokenDetailKey] else {
            return nil
        }
        return PendingAppleLink(token: token, expiresAt: receivedAt.addingTimeInterval(lifetime))
    }

    /// True when `error` is the server's "no account for this Apple ID yet" answer, with or without a token.
    public static func isAppleEmailUnavailable(_ error: Error) -> Bool {
        appleEmailUnavailableError(error) != nil
    }

    /// Said when the server could not keep a pending link, so signing in another way will not connect Apple.
    public static let noLinkMessage =
        "We couldn't find a Spoonjoy account for this Apple ID yet. Sign in with Google, GitHub or your password."

    /// The words to show for the "no account for this Apple ID yet" answer: the server's message, or the same
    /// copy when the server sent none. When the answer carries no pending link, nothing will be connected, so the
    /// words don't promise it. Nil for any other failure.
    public static func userMessage(for error: Error) -> String? {
        guard let apiError = appleEmailUnavailableError(error) else {
            return nil
        }
        // A redacted error has lost its token but keeps this marker, so the view still knows a link is waiting.
        let carriesLink = apiError.details[tokenDetailKey] != nil || apiError.details[linkKeptDetailKey] != nil
        guard carriesLink else {
            return noLinkMessage
        }
        let message = apiError.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? defaultMessage : message
    }

    /// Put in place of the token by `redacting`: says a link is waiting without carrying it.
    static let linkKeptDetailKey = "pendingAppleLinkKept"

    /// `error` with the pending link token and its expiry taken out of the API error details, so the error can
    /// be logged, reported or shown without carrying the token. Anything else passes through unchanged.
    public static func redacting(_ error: Error) -> Error {
        if let apiError = error as? APIError {
            return redacted(apiError) ?? apiError
        }
        guard let transport = error as? APITransportError,
              let apiError = transport.apiError,
              let redactedError = redacted(apiError) else {
            return error
        }
        return APITransportError(
            kind: transport.kind,
            requestID: transport.requestID,
            statusCode: transport.statusCode,
            apiError: redactedError,
            retryDecision: transport.retryDecision
        )
    }

    private static func redacted(_ apiError: APIError) -> APIError? {
        guard apiError.details[tokenDetailKey] != nil || apiError.details[expiresAtDetailKey] != nil else {
            return nil
        }
        var details = apiError.details
        if details[tokenDetailKey] != nil {
            details[linkKeptDetailKey] = .bool(true)
        }
        details[tokenDetailKey] = nil
        details[expiresAtDetailKey] = nil
        return APIError(
            requestID: apiError.requestID,
            code: apiError.code,
            message: apiError.message,
            status: apiError.status,
            retryAfterSeconds: apiError.retryAfterSeconds,
            details: details
        )
    }

    private static func appleEmailUnavailableError(_ error: Error) -> APIError? {
        let apiError = (error as? APITransportError)?.apiError ?? (error as? APIError)
        guard let apiError, case .string(providerCode)? = apiError.details["providerCode"] else {
            return nil
        }
        return apiError
    }
}

extension PendingAppleLink: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "PendingAppleLink(token: <redacted>, expiresAt: \(expiresAt))"
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(self, children: ["expiresAt": expiresAt], displayStyle: .struct)
    }
}

/// What happened to a pending Apple link, for telemetry. It names events, never the token.
public enum PendingAppleLinkEvent: Equatable, Sendable {
    /// An Apple sign-in found no account and the server left a pending link.
    case received
    /// The pending link went out with a sign-in by another method.
    case sent(via: Method)
    /// The server's answer about a sent link (`linked`, `already_linked`, `taken`, `expired`, ...), when the
    /// sign-in succeeded and the server reported one.
    case outcome(String)
    /// The pending link expired on the device before it was used.
    case expired
    /// A sign-in that carried the link failed, or the server could not write the link, so the server spent nothing
    /// and the app keeps it for the next sign-in.
    case kept

    public enum Method: String, Equatable, Sendable {
        case password
        case browser
    }

    /// The telemetry phase name for this event.
    public var phase: String {
        switch self {
        case .received:
            "pending_link_received"
        case .sent(let method):
            "pending_link_sent_\(method.rawValue)"
        case .outcome(let outcome):
            "pending_link_\(Self.safeOutcome(outcome))"
        case .expired:
            "pending_link_expired"
        case .kept:
            "pending_link_kept"
        }
    }

    /// The outcome words the server documents; anything else is reported as `unknown`, so a value the server
    /// echoes can never put free text in telemetry.
    static let knownOutcomes: Set<String> = [
        "linked", "already_linked", "taken", "provider_already_linked", "expired", "consumed", "invalid", "error"
    ]

    /// The outcomes that leave Apple connected to the account that just signed in.
    static let connectedOutcomes: Set<String> = ["linked", "already_linked"]

    private static func safeOutcome(_ outcome: String) -> String {
        knownOutcomes.contains(outcome) ? outcome : "unknown"
    }

    /// The telemetry descriptor for this event: Apple provider, the phase, and no free text.
    public func telemetryDescriptor(sessionState: String?) -> NativeAuthTelemetryDescriptor {
        NativeAuthTelemetryDescriptor(
            authProvider: "apple",
            phase: phase,
            outcome: self == .expired ? .failed : .completed,
            sessionState: sessionState
        )
    }
}

public typealias PendingAppleLinkEventHandler = @Sendable (PendingAppleLinkEvent) async -> Void
