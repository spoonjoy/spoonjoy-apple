import Foundation

public struct APIClientConfiguration: Equatable, Sendable {
    public let baseURL: URL
    public let bearerToken: String?

    public init(baseURL: URL, bearerToken: String? = nil) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
    }

    public static let spoonjoyProduction = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!
    )
}

public enum APIAuthorizationPolicy: Equatable, Sendable {
    case omit
    case includeBearerToken
}

public enum APIRequestMethod: String, Equatable, Sendable {
    case get = "GET"
}

public struct APIRequestURL: Equatable, Sendable {
    public let baseURL: URL
    public let path: String
    public let queryItems: [URLQueryItem]
}

public struct APIRequest: Equatable, Sendable {
    public let method: APIRequestMethod
    public let url: APIRequestURL
    public let queryItems: [URLQueryItem]
    public let headers: [String: String]
    public let body: Data?
}
