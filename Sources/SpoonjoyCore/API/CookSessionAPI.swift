import Foundation

public enum CookSessionRequestError: Error, Equatable, Sendable {
    case invalidBody
}

/// Requests for cook-session protocol v1: `GET`, `POST .../start` and revision-checked `PATCH` under
/// `/api/cook-sessions/:recipeId`. These are not `/api/v1` calls. Reads need `kitchen:read` and writes
/// `kitchen:write`. Writes must carry an `Origin` equal to the site's own origin even with a bearer token.
/// `X-Spoonjoy-Cook-User` is for browser sessions and is left out: a bearer token already names one chef.
public enum CookSessionRequests {
    public static func read(recipeID: String) -> APIRequestBuilder {
        APIRequestSupport.privateRead(pathComponents: ["api", "cook-sessions", recipeID])
    }

    public static func start(recipeID: String, origin: String) -> APIRequestBuilder {
        APIRequestBuilder(
            method: .post,
            pathComponents: ["api", "cook-sessions", recipeID, "start"],
            queryItems: [],
            headers: ["Origin": origin],
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: APIRequestSupport.privateNoStore
        )
    }

    public static func patch(
        recipeID: String,
        server: CookServerSnapshot,
        changes: CookSyncChanges,
        mutationID: String,
        origin: String
    ) throws -> APIRequestBuilder {
        let body: [String: Any] = [
            "attemptId": server.attemptID,
            "expectedRevision": server.revision,
            "mutationId": mutationID,
            "changes": changes.jsonObject
        ]
        // A scale that is not a finite number cannot be written as JSON, and writing it would crash.
        guard JSONSerialization.isValidJSONObject(body) else {
            throw CookSessionRequestError.invalidBody
        }
        let builder = try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "cook-sessions", recipeID],
            body: body
        )
        var headers = builder.headers
        headers["Origin"] = origin
        return APIRequestBuilder(
            method: builder.method,
            pathComponents: builder.pathComponents,
            queryItems: builder.queryItems,
            headers: headers,
            body: builder.body,
            defaultAuthorization: builder.defaultAuthorization,
            responseCachePolicy: builder.responseCachePolicy
        )
    }

    /// The site origin (scheme, host and any port) the server compares the `Origin` header with.
    public static func origin(for baseURL: URL) -> String {
        var origin = "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "")"
        if let port = baseURL.port {
            origin += ":\(port)"
        }
        return origin
    }
}

/// Talks to the cook-session endpoints. The answers are not the `/api/v1` envelope (`{ state }` on success,
/// `{ error: { code, state? } }` on failure), so this reads them itself instead of using the envelope transport.
/// Every failure becomes a `CookSyncResult`; nothing throws.
public struct URLSessionCookSessionClient: CookSessionClient {
    private let session: any URLSessionPerforming
    private let configuration: APIClientConfiguration

    public init(
        session: any URLSessionPerforming = URLSession.shared,
        configuration: APIClientConfiguration
    ) {
        self.session = session
        self.configuration = configuration
    }

    public func read(recipeID: String) async -> CookSyncResult {
        await send(CookSessionRequests.read(recipeID: recipeID))
    }

    public func start(recipeID: String) async -> CookSyncResult {
        await send(CookSessionRequests.start(
            recipeID: recipeID,
            origin: CookSessionRequests.origin(for: configuration.baseURL)
        ))
    }

    public func patch(
        recipeID: String,
        server: CookServerSnapshot,
        changes: CookSyncChanges,
        mutationID: String
    ) async -> CookSyncResult {
        guard let request = try? CookSessionRequests.patch(
            recipeID: recipeID,
            server: server,
            changes: changes,
            mutationID: mutationID,
            origin: CookSessionRequests.origin(for: configuration.baseURL)
        ) else {
            return .rejected
        }
        return await send(request)
    }

    private func send(_ builder: APIRequestBuilder) async -> CookSyncResult {
        guard let request = try? builder.urlRequest(configuration: configuration),
              let url = Self.url(for: request.url) else {
            return .stopped
        }

        var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            return .transient(retryAfterSeconds: nil)
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(retryAfterSeconds: nil)
        }
        return Self.classify(status: http.statusCode, body: data, retryAfter: Self.retryAfterSeconds(http))
    }

    private static func url(for requestURL: APIRequestURL) -> URL? {
        guard var components = URLComponents(url: requestURL.baseURL, resolvingAgainstBaseURL: false),
              components.host?.isEmpty == false else {
            return nil
        }
        components.percentEncodedPath = requestURL.path
        return components.url
    }

    static func classify(status: Int, body: Data, retryAfter: Int?) -> CookSyncResult {
        let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        if 200...299 ~= status {
            if let object, object["state"] is NSNull {
                return .state(nil)
            }
            if let state = snapshot(object?["state"]) {
                return .state(state)
            }
            return .transient(retryAfterSeconds: nil)
        }

        let error = object?["error"] as? [String: Any]
        let code = error?["code"] as? String
        if status == 409, let state = snapshot(error?["state"]) {
            return .conflict(state)
        }
        switch status {
        case 401:
            return .unauthenticated
        case 404:
            return .missing
        case 400:
            return .rejected
        case 429:
            return .transient(retryAfterSeconds: retryAfter)
        case 503 where code == "cook_session_protocol_unavailable":
            return .stopped
        case 500...599:
            return .transient(retryAfterSeconds: retryAfter)
        default:
            // 403, 412 user_mismatch, 428 user_header_required and any other refusal will not change by retrying.
            return .stopped
        }
    }

    private static func snapshot(_ value: Any?) -> CookServerSnapshot? {
        guard let value, JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }
        return try? JSONDecoder().decode(CookServerSnapshot.self, from: data)
    }

    private static func retryAfterSeconds(_ response: HTTPURLResponse) -> Int? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Int(value.trimmingCharacters(in: .whitespaces)), seconds >= 0 else {
            return nil
        }
        return seconds
    }
}
