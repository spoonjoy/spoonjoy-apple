import Foundation

public struct NativeAppleSignInCredential: Equatable, Sendable {
    public let identityToken: String
    public let rawNonce: String
    public let email: String?
    public let fullName: String?

    public init(
        identityToken: String,
        rawNonce: String,
        email: String? = nil,
        fullName: String? = nil
    ) {
        self.identityToken = identityToken
        self.rawNonce = rawNonce
        self.email = email
        self.fullName = fullName
    }
}

public enum NativeAppleSignInRequests {
    /// `client` says which app and install is signing in (platform, version, install ID), so the server can tie the
    /// sign-in, and the install's earlier anonymous telemetry, to the account. Unknown values are left out.
    public static func exchangeCredential(
        _ credential: NativeAppleSignInCredential,
        client: NativeTelemetryAppMetadata = .unknown
    ) throws -> APIRequestBuilder {
        let fields = NativeSignInClientFields(client)
        let body = NativeAppleSignInRequestBody(
            identityToken: credential.identityToken,
            rawNonce: credential.rawNonce,
            email: credential.email,
            fullName: credential.fullName,
            platform: fields.platform,
            appVersion: fields.appVersion,
            installId: fields.installID
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return APIRequestBuilder(
            method: .post,
            pathComponents: ["api", "v1", "auth", "apple", "native"],
            queryItems: [],
            headers: ["Content-Type": "application/json"],
            body: try encoder.encode(body),
            responseCachePolicy: .privateNoStore
        )
    }
}

private struct NativeAppleSignInRequestBody: Encodable {
    let identityToken: String
    let rawNonce: String
    let email: String?
    let fullName: String?
    let platform: String?
    let appVersion: String?
    let installId: String?
}

/// The client fields both native sign-in requests carry, each only when the server would accept it.
struct NativeSignInClientFields: Equatable {
    let platform: String?
    let appVersion: String?
    let installID: String?

    init(_ metadata: NativeTelemetryAppMetadata) {
        platform = ["ios", "macos"].contains(metadata.platform ?? "") ? metadata.platform : nil
        appVersion = NativeDiagnosticMapper.clipped(metadata.appVersion, to: 40)
        installID = metadata.installID.flatMap { NativeInstallID.isValid($0) ? $0 : nil }
    }
}
