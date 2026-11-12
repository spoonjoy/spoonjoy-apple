import Foundation

public struct NativePasswordSignInCredential: Equatable, Sendable {
    public let emailOrUsername: String
    public let password: String
    /// The pending Apple link this sign-in carries, set only by `NativeAuthSessionRepository` and never printed.
    let pendingAppleLinkToken: String?

    public init(emailOrUsername: String, password: String) {
        self.emailOrUsername = emailOrUsername
        self.password = password
        self.pendingAppleLinkToken = nil
    }

    private init(emailOrUsername: String, password: String, pendingAppleLinkToken: String?) {
        self.emailOrUsername = emailOrUsername
        self.password = password
        self.pendingAppleLinkToken = pendingAppleLinkToken
    }

    /// True when this sign-in will ask the server to link a pending Apple sign-in to the account.
    public var carriesPendingAppleLink: Bool {
        pendingAppleLinkToken != nil
    }

    func linkingApple(_ pendingAppleLink: PendingAppleLink?) -> NativePasswordSignInCredential {
        NativePasswordSignInCredential(
            emailOrUsername: emailOrUsername,
            password: password,
            pendingAppleLinkToken: pendingAppleLink?.token
        )
    }
}

extension NativePasswordSignInCredential: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "NativePasswordSignInCredential(emailOrUsername: \(emailOrUsername), password: <redacted>, pendingAppleLink: \(carriesPendingAppleLink))"
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: ["emailOrUsername": emailOrUsername, "carriesPendingAppleLink": carriesPendingAppleLink],
            displayStyle: .struct
        )
    }
}

public enum NativePasswordSignInRequests {
    public static func exchangeCredential(_ credential: NativePasswordSignInCredential) throws -> APIRequestBuilder {
        let body = NativePasswordSignInRequestBody(
            emailOrUsername: credential.emailOrUsername,
            password: credential.password,
            pendingAppleLinkToken: credential.pendingAppleLinkToken
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return APIRequestBuilder(
            method: .post,
            pathComponents: ["api", "v1", "auth", "password", "native"],
            queryItems: [],
            headers: ["Content-Type": "application/json"],
            body: try encoder.encode(body),
            responseCachePolicy: .privateNoStore
        )
    }
}

private struct NativePasswordSignInRequestBody: Encodable {
    let emailOrUsername: String
    let password: String
    /// Left out of the body when nil (synthesized `encodeIfPresent`), so a plain sign-in sends what it always did.
    let pendingAppleLinkToken: String?
}
