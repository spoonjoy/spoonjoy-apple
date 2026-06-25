import Foundation

public struct APIEnvelope<Value: Decodable & Equatable>: Decodable, Equatable {
    public let requestID: String
    public let data: Value

    private enum CodingKeys: String, CodingKey {
        case ok
        case requestID = "requestId"
        case data
        case error
    }

    public static func decode(_ data: Data) throws -> APIEnvelope<Value> {
        try JSONDecoder().decode(APIEnvelope<Value>.self, from: data)
    }

    public static func decodeResult(_ data: Data) throws -> APIResult<Value> {
        let envelope = try JSONDecoder().decode(APIResponseEnvelope<Value>.self, from: data)

        switch envelope {
        case .success(let success):
            return .success(success)
        case .failure(let error):
            return .failure(error)
        }
    }
}

public enum APIResult<Value: Decodable & Equatable>: Equatable {
    case success(APIEnvelope<Value>)
    case failure(APIError)
}

private enum APIResponseEnvelope<Value: Decodable & Equatable>: Decodable {
    case success(APIEnvelope<Value>)
    case failure(APIError)

    private enum CodingKeys: String, CodingKey {
        case ok
        case requestID = "requestId"
        case data
        case error
    }

    private struct ErrorPayload: Decodable {
        let code: String
        let message: String
        let status: Int
        let details: [String: JSONValue]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ok = try container.decode(Bool.self, forKey: .ok)
        let requestID = try container.decode(String.self, forKey: .requestID)

        if ok {
            self = .success(
                APIEnvelope(
                    requestID: requestID,
                    data: try container.decode(Value.self, forKey: .data)
                )
            )
        } else {
            let error = try container.decode(ErrorPayload.self, forKey: .error)
            self = .failure(
                APIError(
                    requestID: requestID,
                    code: error.code,
                    message: error.message,
                    status: error.status,
                    retryAfterSeconds: error.details?["retryAfterSeconds"]?.intValue,
                    details: error.details ?? [:]
                )
            )
        }
    }
}

extension APIEnvelope {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ok = try container.decode(Bool.self, forKey: .ok)
        guard ok else {
            throw DecodingError.dataCorruptedError(
                forKey: .ok,
                in: container,
                debugDescription: "Expected a successful API envelope."
            )
        }

        requestID = try container.decode(String.self, forKey: .requestID)
        self.data = try container.decode(Value.self, forKey: .data)
    }
}
