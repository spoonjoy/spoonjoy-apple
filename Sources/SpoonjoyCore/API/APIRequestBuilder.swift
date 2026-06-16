import Foundation

public struct APIRequestBuilder: Equatable {
    public let method: APIRequestMethod
    public let pathComponents: [String]
    public let queryItems: [URLQueryItem]

    public func urlRequest(
        configuration: APIClientConfiguration,
        authorization: APIAuthorizationPolicy = .omit
    ) throws -> APIRequest {
        let path = "/" + pathComponents.map(Self.percentEncodePathSegment).joined(separator: "/")
        var headers = ["Accept": "application/json"]

        if authorization == .includeBearerToken,
           let bearerToken = configuration.bearerToken?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bearerToken.isEmpty {
            headers["Authorization"] = "Bearer \(bearerToken)"
        }

        return APIRequest(
            method: method,
            url: APIRequestURL(
                baseURL: configuration.baseURL,
                path: path,
                queryItems: queryItems
            ),
            queryItems: queryItems,
            headers: headers,
            body: nil
        )
    }

    private static func percentEncodePathSegment(_ segment: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
    }
}
