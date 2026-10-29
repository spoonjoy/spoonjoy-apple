import Foundation

public protocol SpoonjoyAPITransport: Sendable {
    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value>
}

public protocol URLSessionPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionPerforming {}

public protocol APIAuthenticationRefresher: Sendable {
    func refreshedConfiguration(
        after error: APIError,
        configuration: APIClientConfiguration
    ) async throws -> APIClientConfiguration
}

public enum APITransportErrorKind: Equatable, Sendable {
    case apiError
    case nonJSONResponse
    case malformedJSONResponse
    case offline
    case cancelled
    case invalidRequestURL
    case nonHTTPResponse
    case networkFailure
}

public struct APITransportError: Error, Equatable, Sendable {
    public let kind: APITransportErrorKind
    public let requestID: String?
    public let statusCode: Int?
    public let apiError: APIError?
    public let retryDecision: APIRetryDecision

    public var isNonJSONResponse: Bool {
        kind == .nonJSONResponse
    }

    public var isMalformedJSONResponse: Bool {
        kind == .malformedJSONResponse
    }

    public var isOffline: Bool {
        kind == .offline
    }

    public var isCancelled: Bool {
        kind == .cancelled
    }

    public init(
        kind: APITransportErrorKind,
        requestID: String?,
        statusCode: Int?,
        apiError: APIError?,
        retryDecision: APIRetryDecision
    ) {
        self.kind = kind
        self.requestID = requestID
        self.statusCode = statusCode
        self.apiError = apiError
        self.retryDecision = retryDecision
    }

    static func invalidRequestURL() -> APITransportError {
        APITransportError(
            kind: .invalidRequestURL,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .doNotRetry
        )
    }
}

public struct URLSessionAPITransport: SpoonjoyAPITransport, Sendable {
    private let session: any URLSessionPerforming
    private let authenticationRefresher: (any APIAuthenticationRefresher)?
    private let refreshedCredential = RefreshedCredential()

    public init(
        session: any URLSessionPerforming = URLSession.shared,
        authenticationRefresher: (any APIAuthenticationRefresher)? = nil
    ) {
        self.session = session
        self.authenticationRefresher = authenticationRefresher
    }

    public func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        try await send(
            request,
            configuration: configuration,
            decode: valueType,
            hasRefreshedAuthentication: false
        )
    }

    /// Sends a request built ahead of time, such as a sync page. A 401 that asks for new credentials refreshes them
    /// once and replays the request with the new access token, like the builder overload does. Later requests built
    /// with the rejected token go out with the refreshed one, so each page of a sync does not hit 401 first.
    public func send<Value: Decodable & Equatable>(
        _ request: APIRequest,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        var request = request
        if let sent = Self.bearerCredential(in: request),
           let replacement = refreshedCredential.replacement(for: sent.token) {
            request = Self.replacingBearerToken(in: request, header: sent.header, with: replacement)
        }
        do {
            return try await sendOnce(request, decode: valueType)
        } catch let error as APITransportError {
            guard case .refreshAuthentication = error.retryDecision,
                  let sent = Self.bearerCredential(in: request),
                  let apiError = error.apiError,
                  let authenticationRefresher else {
                throw error
            }
            // The token this request carried is the one the server rejected, whatever the configuration says.
            let refreshedConfiguration = try await Self.refreshedConfiguration(
                using: authenticationRefresher,
                after: error,
                apiError: apiError,
                configuration: APIClientConfiguration(baseURL: configuration.baseURL, bearerToken: sent.token)
            )
            guard let bearerToken = refreshedConfiguration.bearerToken else {
                throw error
            }
            refreshedCredential.record(rejected: sent.token, refreshed: bearerToken)
            return try await sendOnce(
                Self.replacingBearerToken(in: request, header: sent.header, with: bearerToken),
                decode: valueType
            )
        }
    }

    /// Asks the refresher for new credentials after `error`. A refresh that fails with anything but an OAuth refusal
    /// or a lost connection (a proxy's HTML 403, a 5xx) says nothing about the request, so the original 401 is
    /// rethrown: a queued edit then waits as an auth failure instead of being held as a rejected edit.
    private static func refreshedConfiguration(
        using refresher: any APIAuthenticationRefresher,
        after error: APITransportError,
        apiError: APIError,
        configuration: APIClientConfiguration
    ) async throws -> APIClientConfiguration {
        do {
            return try await refresher.refreshedConfiguration(after: apiError, configuration: configuration)
        } catch let refreshError as APITransportError where !refreshError.isOffline {
            throw error
        }
    }

    /// The request's Authorization header name, matched in any case, and the bearer token it carries.
    private static func bearerCredential(in request: APIRequest) -> (header: String, token: String)? {
        let prefix = "Bearer "
        for (name, value) in request.headers where name.caseInsensitiveCompare("Authorization") == .orderedSame {
            guard value.count > prefix.count,
                  value.prefix(prefix.count).caseInsensitiveCompare(prefix) == .orderedSame else {
                return nil
            }
            return (name, String(value.dropFirst(prefix.count)))
        }
        return nil
    }

    private static func replacingBearerToken(in request: APIRequest, header: String, with token: String) -> APIRequest {
        var headers = request.headers
        headers[header] = "Bearer \(token)"
        return APIRequest(
            method: request.method,
            url: request.url,
            queryItems: request.queryItems,
            headers: headers,
            body: request.body,
            responseCachePolicy: request.responseCachePolicy,
            timeoutInterval: request.timeoutInterval
        )
    }

    private func sendOnce<Value: Decodable & Equatable>(
        _ request: APIRequest,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let urlRequest = try buildURLRequest(from: request)
        let response: (data: Data, urlResponse: URLResponse)

        do {
            response = try await session.data(for: urlRequest)
        } catch {
            throw Self.transportError(from: error)
        }

        return try Self.decode(
            response.data,
            response: response.urlResponse,
            as: valueType
        )
    }

    private func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type,
        hasRefreshedAuthentication: Bool
    ) async throws -> APIEnvelope<Value> {
        let urlRequest = try buildURLRequest(
            from: try request.urlRequest(configuration: configuration)
        )
        let response: (data: Data, urlResponse: URLResponse)

        do {
            response = try await session.data(for: urlRequest)
        } catch {
            throw Self.transportError(from: error)
        }

        do {
            return try Self.decode(
                response.data,
                response: response.urlResponse,
                as: valueType
            )
        } catch let error as APITransportError {
            guard case .refreshAuthentication = error.retryDecision,
                  !hasRefreshedAuthentication,
                  let apiError = error.apiError,
                  let authenticationRefresher else {
                throw error
            }

            let refreshedConfiguration = try await Self.refreshedConfiguration(
                using: authenticationRefresher,
                after: error,
                apiError: apiError,
                configuration: configuration
            )
            return try await send(
                request,
                configuration: refreshedConfiguration,
                decode: valueType,
                hasRefreshedAuthentication: true
            )
        }
    }

    private func buildURLRequest(from request: APIRequest) throws -> URLRequest {
        guard let url = Self.url(from: request.url, queryItems: request.queryItems) else {
            throw APITransportError.invalidRequestURL()
        }

        var urlRequest = URLRequest(
            url: url,
            cachePolicy: Self.cachePolicy(for: request.responseCachePolicy)
        )
        urlRequest.timeoutInterval = request.timeoutInterval
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        return urlRequest
    }

    private static func url(from requestURL: APIRequestURL, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(
            url: requestURL.baseURL,
            resolvingAgainstBaseURL: false
        ),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              components.host?.isEmpty == false else {
            return nil
        }

        components.percentEncodedPath = requestURL.path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

    private static func decode<Value: Decodable & Equatable>(
        _ data: Data,
        response: URLResponse,
        as valueType: Value.Type
    ) throws -> APIEnvelope<Value> {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APITransportError(
                kind: .nonHTTPResponse,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }

        let statusCode = httpResponse.statusCode
        let retryAfterSeconds = retryAfterSeconds(from: httpResponse)
        guard isJSONResponse(httpResponse) else {
            let requestID = requestID(from: httpResponse)
            throw APITransportError(
                kind: .nonJSONResponse,
                requestID: requestID,
                statusCode: statusCode,
                apiError: syntheticAPIError(
                    statusCode: statusCode,
                    requestID: requestID,
                    message: "HTTP \(statusCode) returned a non-JSON response.",
                    retryAfterSeconds: retryAfterSeconds
                ),
                retryDecision: retryDecision(for: statusCode, retryAfterSeconds: retryAfterSeconds)
            )
        }

        do {
            switch try APIEnvelope<Value>.decodeResult(data) {
            case .success(let envelope):
                guard 200...299 ~= statusCode else {
                    throw APITransportError(
                        kind: .apiError,
                        requestID: envelope.requestID,
                        statusCode: statusCode,
                        apiError: syntheticAPIError(
                            statusCode: statusCode,
                            requestID: envelope.requestID,
                            message: "HTTP \(statusCode) returned a successful API envelope.",
                            retryAfterSeconds: retryAfterSeconds
                        ),
                        retryDecision: retryDecision(for: statusCode, retryAfterSeconds: retryAfterSeconds)
                    )
                }
                return envelope
            case .failure(let apiError):
                let apiError = apiError.withRetryAfterSeconds(
                    retryAfterSeconds ?? apiError.retryAfterSeconds
                )
                throw APITransportError(
                    kind: .apiError,
                    requestID: apiError.requestID,
                    statusCode: statusCode,
                    apiError: apiError,
                    retryDecision: APIRetryPolicy.decision(for: apiError)
                )
            }
        } catch let error as APITransportError {
            throw error
        } catch {
            let requestID = requestID(from: httpResponse)
            throw APITransportError(
                kind: .malformedJSONResponse,
                requestID: requestID,
                statusCode: statusCode,
                apiError: syntheticAPIError(
                    statusCode: statusCode,
                    requestID: requestID,
                    message: "HTTP \(statusCode) returned a malformed JSON response.",
                    retryAfterSeconds: retryAfterSeconds
                ),
                retryDecision: retryDecision(for: statusCode, retryAfterSeconds: retryAfterSeconds)
            )
        }
    }

    private static func transportError(from error: Error) -> APITransportError {
        if error is CancellationError {
            return APITransportError(
                kind: .cancelled,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                // A cancelled request never reached an answer, so it can be sent again. A queued edit whose
                // request was cancelled stays pending and goes out on the next drain.
                retryDecision: .retrySameRequest(afterSeconds: nil)
            )
        }

        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                return APITransportError(
                    kind: .cancelled,
                    requestID: nil,
                    statusCode: nil,
                    apiError: nil,
                    retryDecision: .retrySameRequest(afterSeconds: nil)
                )
            }

            if isOffline(urlError.code) {
                return APITransportError(
                    kind: .offline,
                    requestID: nil,
                    statusCode: nil,
                    apiError: nil,
                    retryDecision: .retrySameRequest(afterSeconds: nil)
                )
            }
        }

        return APITransportError(
            kind: .networkFailure,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .retrySameRequest(afterSeconds: nil)
        )
    }

    private static func cachePolicy(for policy: APIResponseCachePolicy?) -> URLRequest.CachePolicy {
        switch policy {
        case .privateNoStore:
            return .reloadIgnoringLocalCacheData
        case .publicCache, nil:
            return .useProtocolCachePolicy
        }
    }

    private static func retryDecision(for statusCode: Int, retryAfterSeconds: Int?) -> APIRetryDecision {
        switch statusCode {
        case 401:
            return .refreshAuthentication
        case 429:
            return .retrySameRequest(afterSeconds: retryAfterSeconds)
        case 500...599:
            return .retrySameRequest(afterSeconds: retryAfterSeconds)
        default:
            return .doNotRetry
        }
    }

    private static func syntheticAPIError(
        statusCode: Int,
        requestID: String?,
        message: String,
        retryAfterSeconds: Int?
    ) -> APIError? {
        guard !(200...299 ~= statusCode) else {
            return nil
        }

        return APIError(
            requestID: requestID ?? "unknown",
            code: "http_status_\(statusCode)",
            message: message,
            status: statusCode,
            retryAfterSeconds: retryAfterSeconds
        )
    }

    private static func isJSONResponse(_ response: HTTPURLResponse) -> Bool {
        guard let contentType = headerValue("Content-Type", in: response) else {
            return false
        }

        let lowercased = contentType.lowercased()
        return lowercased.contains("application/json") || lowercased.contains("+json")
    }

    private static func requestID(from response: HTTPURLResponse) -> String? {
        headerValue("X-Request-Id", in: response)
    }

    private static func retryAfterSeconds(from response: HTTPURLResponse) -> Int? {
        guard let retryAfter = headerValue("Retry-After", in: response)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !retryAfter.isEmpty else {
            return nil
        }

        if let seconds = Int(retryAfter), seconds >= 0 {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"

        return formatter.date(from: retryAfter).map { retryDate in
            max(0, Int(ceil(retryDate.timeIntervalSince(Date()))))
        }
    }

    private static func headerValue(_ name: String, in response: HTTPURLResponse) -> String? {
        let lowercasedName = name.lowercased()
        for (key, value) in response.allHeaderFields {
            guard String(describing: key).lowercased() == lowercasedName else {
                continue
            }

            return String(describing: value)
        }

        return nil
    }

    static func isOffline(_ code: URLError.Code) -> Bool {
        switch code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .timedOut,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}

private extension APIError {
    func withRetryAfterSeconds(_ retryAfterSeconds: Int?) -> APIError {
        APIError(
            requestID: requestID,
            code: code,
            message: message,
            status: status,
            retryAfterSeconds: retryAfterSeconds,
            details: details
        )
    }
}

/// The last access token a 401 replaced and the token that replaced it, shared by every copy of one transport.
private final class RefreshedCredential: @unchecked Sendable {
    private let lock = NSLock()
    private var rejected: String?
    private var refreshed: String?

    func record(rejected: String, refreshed: String) {
        lock.lock()
        defer { lock.unlock() }
        self.rejected = rejected
        self.refreshed = refreshed
    }

    func replacement(for token: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token == rejected ? refreshed : nil
    }
}
