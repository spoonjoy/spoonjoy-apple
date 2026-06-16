import Foundation

public struct APIError: Error, Codable, Equatable {
    public let requestID: String
    public let code: String
    public let message: String
    public let status: Int
    public let retryAfterSeconds: Int?

    public init(
        requestID: String,
        code: String,
        message: String,
        status: Int,
        retryAfterSeconds: Int? = nil
    ) {
        self.requestID = requestID
        self.code = code
        self.message = message
        self.status = status
        self.retryAfterSeconds = retryAfterSeconds
    }
}
