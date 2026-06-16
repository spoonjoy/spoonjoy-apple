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
