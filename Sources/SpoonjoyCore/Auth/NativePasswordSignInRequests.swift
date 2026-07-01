import Foundation

public struct NativePasswordSignInCredential: Equatable, Sendable {
    public let emailOrUsername: String
    public let password: String

    public init(emailOrUsername: String, password: String) {
        self.emailOrUsername = emailOrUsername
        self.password = password
    }
}

public enum NativePasswordSignInRequests {
    public static func exchangeCredential(_ credential: NativePasswordSignInCredential) throws -> APIRequestBuilder {
        let body = NativePasswordSignInRequestBody(
            emailOrUsername: credential.emailOrUsername,
            password: credential.password
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
}
