import Foundation

public struct APIRequestBuilder: Equatable, Sendable {
    public let method: APIRequestMethod
    public let pathComponents: [String]
    public let queryItems: [URLQueryItem]
    public let headers: [String: String]
    public let body: Data?
    public let defaultAuthorization: APIAuthorizationPolicy
    public let responseCachePolicy: APIResponseCachePolicy?

    public init(
        method: APIRequestMethod,
        pathComponents: [String],
        queryItems: [URLQueryItem],
        headers: [String: String] = [:],
        body: Data? = nil,
        defaultAuthorization: APIAuthorizationPolicy = .omit,
        responseCachePolicy: APIResponseCachePolicy? = nil
    ) {
        self.method = method
        self.pathComponents = pathComponents
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.defaultAuthorization = defaultAuthorization
        self.responseCachePolicy = responseCachePolicy
    }

    public func urlRequest(
        configuration: APIClientConfiguration,
        authorization: APIAuthorizationPolicy? = nil
    ) throws -> APIRequest {
        let path = "/" + pathComponents.map(Self.percentEncodePathSegment).joined(separator: "/")
        var requestHeaders = ["Accept": "application/json"]

        for (name, value) in headers {
            requestHeaders[name] = value
        }

        let authorization = authorization ?? defaultAuthorization
        var includesBearerToken = false
        if authorization == .includeBearerToken,
           let bearerToken = configuration.bearerToken?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bearerToken.isEmpty {
            requestHeaders["Authorization"] = "Bearer \(bearerToken)"
            includesBearerToken = true
        }

        return APIRequest(
            method: method,
            url: APIRequestURL(
                baseURL: configuration.baseURL,
                path: path,
                queryItems: queryItems
            ),
            queryItems: queryItems,
            headers: requestHeaders,
            body: body,
            responseCachePolicy: resolvedResponseCachePolicy(includesBearerToken: includesBearerToken)
        )
    }

    private func resolvedResponseCachePolicy(includesBearerToken: Bool) -> APIResponseCachePolicy? {
        guard includesBearerToken else {
            return responseCachePolicy
        }

        switch responseCachePolicy {
        case .publicCache:
            return .privateNoStore
        case .privateNoStore, nil:
            return responseCachePolicy
        }
    }

    private static func percentEncodePathSegment(_ segment: String) -> String {
        var encoded = ""

        for byte in segment.utf8 {
            if isUnreservedPathByte(byte) {
                encoded.unicodeScalars.append(UnicodeScalar(Int(byte))!)
            } else {
                encoded += String(format: "%%%02X", byte)
            }
        }

        return encoded
    }

    private static func isUnreservedPathByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 45, 46, 48...57, 65...90, 95, 97...122, 126:
            true
        default:
            false
        }
    }
}
