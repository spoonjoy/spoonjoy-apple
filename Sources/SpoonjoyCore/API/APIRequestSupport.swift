import Foundation

public enum MutationIdempotency: Equatable, Sendable {
    case header
    case body
    case query
}

public typealias ShoppingDeleteIdempotency = MutationIdempotency

public struct UploadFile: Equatable, Sendable {
    public let fileName: String
    public let contentType: String
    public let data: Data

    public init(fileName: String, contentType: String, data: Data) {
        self.fileName = fileName
        self.contentType = contentType
        self.data = data
    }
}

enum APIRequestSupport {
    static let publicReadCache = APIResponseCachePolicy.publicCache(
        maxAgeSeconds: 60,
        staleWhileRevalidateSeconds: 300
    )
    static let privateNoStore = APIResponseCachePolicy.privateNoStore

    static func publicRead(
        method: APIRequestMethod = .get,
        pathComponents: [String],
        queryItems: [URLQueryItem] = []
    ) -> APIRequestBuilder {
        APIRequestBuilder(
            method: method,
            pathComponents: pathComponents,
            queryItems: queryItems,
            responseCachePolicy: publicReadCache
        )
    }

    static func privateRead(
        method: APIRequestMethod = .get,
        pathComponents: [String],
        queryItems: [URLQueryItem] = []
    ) -> APIRequestBuilder {
        APIRequestBuilder(
            method: method,
            pathComponents: pathComponents,
            queryItems: queryItems,
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: privateNoStore
        )
    }

    static func privateJSON(
        method: APIRequestMethod,
        pathComponents: [String],
        body: [String: Any],
        queryItems: [URLQueryItem] = []
    ) throws -> APIRequestBuilder {
        APIRequestBuilder(
            method: method,
            pathComponents: pathComponents,
            queryItems: queryItems,
            headers: ["Content-Type": "application/json"],
            body: try jsonData(body),
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: privateNoStore
        )
    }

    static func privateJSONDelete(
        pathComponents: [String],
        clientMutationID: String,
        idempotency: MutationIdempotency,
        body: [String: Any] = [:]
    ) throws -> APIRequestBuilder {
        switch idempotency {
        case .header:
            var headers = ["X-Client-Mutation-Id": clientMutationID]
            let encodedBody: Data?
            if body.isEmpty {
                encodedBody = nil
            } else {
                headers["Content-Type"] = "application/json"
                encodedBody = try jsonData(body)
            }

            return APIRequestBuilder(
                method: .delete,
                pathComponents: pathComponents,
                queryItems: [],
                headers: headers,
                body: encodedBody,
                defaultAuthorization: .includeBearerToken,
                responseCachePolicy: privateNoStore
            )
        case .body:
            var requestBody = body
            requestBody["clientMutationId"] = clientMutationID
            return try privateJSON(method: .delete, pathComponents: pathComponents, body: requestBody)
        case .query:
            return APIRequestBuilder(
                method: .delete,
                pathComponents: pathComponents,
                queryItems: [URLQueryItem(name: "clientMutationId", value: clientMutationID)],
                headers: body.isEmpty ? [:] : ["Content-Type": "application/json"],
                body: body.isEmpty ? nil : try jsonData(body),
                defaultAuthorization: .includeBearerToken,
                responseCachePolicy: privateNoStore
            )
        }
    }

    static func privateMultipart(
        method: APIRequestMethod,
        pathComponents: [String],
        fileField: String,
        file: UploadFile,
        fields: [String: String] = [:]
    ) throws -> APIRequestBuilder {
        try validateMultipartHeaderValue(fileField, label: "file field")
        try validateMultipartHeaderValue(file.fileName, label: "file name")
        try validateMultipartHeaderValue(file.contentType, label: "content type")
        for name in fields.keys {
            try validateMultipartHeaderValue(name, label: "field name")
        }

        let boundary = multipartBoundary(file: file, fields: fields)

        return APIRequestBuilder(
            method: method,
            pathComponents: pathComponents,
            queryItems: [],
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: multipartBody(boundary: boundary, fileField: fileField, file: file, fields: fields),
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: privateNoStore
        )
    }

    static func jsonData(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func jsonObject(from value: JSONValue) -> Any {
        switch value {
        case .object(let object):
            var result: [String: Any] = [:]
            for (key, value) in object {
                result[key] = jsonObject(from: value)
            }
            return result
        case .array(let values):
            return values.map(jsonObject(from:))
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return NSNull()
        }
    }

    private static func multipartBody(
        boundary: String,
        fileField: String,
        file: UploadFile,
        fields: [String: String]
    ) -> Data {
        var body = Data()

        appendPartPreamble(boundary: boundary, to: &body)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(file.fileName)\"\r\n")
        body.append("Content-Type: \(file.contentType)\r\n\r\n")
        body.append(file.data)
        body.append("\r\n")

        for name in fields.keys.sorted() {
            guard let value = fields[name] else {
                continue
            }

            appendPartPreamble(boundary: boundary, to: &body)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append(value)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")
        return body
    }

    private static func appendPartPreamble(boundary: String, to body: inout Data) {
        body.append("--\(boundary)\r\n")
    }

    private static func validateMultipartHeaderValue(_ value: String, label: String) throws {
        guard !value.isEmpty else {
            throw APIRequestBuildError.invalidMultipartHeaderValue(label)
        }

        for scalar in value.unicodeScalars {
            if scalar == "\"" || scalar.value < 0x20 || scalar.value == 0x7F {
                throw APIRequestBuildError.invalidMultipartHeaderValue(label)
            }
        }
    }

    private static func multipartBoundary(file: UploadFile, fields: [String: String]) -> String {
        for _ in 0..<10 {
            let boundary = "SpoonjoyBoundary-\(UUID().uuidString)"
            let boundaryData = Data(boundary.utf8)
            guard file.data.range(of: boundaryData) == nil else {
                continue
            }
            guard !fields.values.contains(where: { $0.contains(boundary) }) else {
                continue
            }
            return boundary
        }

        return "SpoonjoyBoundary-\(UUID().uuidString)"
    }
}

extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
