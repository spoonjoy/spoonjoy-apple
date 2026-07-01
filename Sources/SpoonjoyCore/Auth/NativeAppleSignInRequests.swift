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
    public static func exchangeCredential(_ credential: NativeAppleSignInCredential) throws -> APIRequestBuilder {
        let body = NativeAppleSignInRequestBody(
            identityToken: credential.identityToken,
            rawNonce: credential.rawNonce,
            email: credential.email,
            fullName: credential.fullName
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
}
