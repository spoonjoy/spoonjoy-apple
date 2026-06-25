import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("URLSession API transport")
struct APITransportTests {
    @Test("URLSession transport builds URLRequests and decodes successful envelopes")
    func transportBuildsURLRequestsAndDecodesSuccessEnvelopes() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_transport_success", name: "Lemon pantry")
                ))
            ]
        )
        let transport = URLSessionAPITransport(session: session)
        let request = APIRequestBuilder(
            method: .patch,
            pathComponents: ["api", "v1", "profile"],
            queryItems: [
                URLQueryItem(name: "include", value: "preferences"),
                URLQueryItem(name: "device", value: "iPhone 26")
            ],
            headers: ["Content-Type": "application/json", "X-Client-Mutation-Id": "profile-update-1"],
            body: Data(#"{"displayName":"Ari"}"#.utf8),
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: .privateNoStore
        )

        let envelope = try await transport.send(
            request,
            configuration: Self.configuration(bearerToken: "sj_access_original"),
            decode: TransportPayload.self
        )
        let capturedRequest = try #require(await session.capturedRequests().first)

        #expect(envelope.requestID == "req_transport_success")
        #expect(envelope.data == TransportPayload(name: "Lemon pantry"))
        #expect(capturedRequest.httpMethod == "PATCH")
        #expect(capturedRequest.url?.absoluteString == "https://spoonjoy.app/api/v1/profile?include=preferences&device=iPhone%2026")
        #expect(capturedRequest.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(capturedRequest.value(forHTTPHeaderField: "Authorization") == "Bearer sj_access_original")
        #expect(capturedRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(capturedRequest.value(forHTTPHeaderField: "X-Client-Mutation-Id") == "profile-update-1")
        #expect(capturedRequest.httpBody == Data(#"{"displayName":"Ari"}"#.utf8))
        #expect(capturedRequest.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test("API error envelopes preserve request IDs details and retry decisions")
    func apiErrorEnvelopesPreserveRequestIDsDetailsAndRetryDecisions() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 429,
                    headers: ["Content-Type": "application/json", "Retry-After": "9"],
                    body: Self.errorEnvelope(
                        requestID: "req_rate_limited",
                        code: "rate_limited",
                        message: "Slow down",
                        status: 429,
                        details: #""retryAfterSeconds": 3, "limit": "write-mutations""#
                    )
                ))
            ]
        )
        let transport = URLSessionAPITransport(session: session)

        do {
            _ = try await transport.send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected rate-limited API response to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_rate_limited")
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: 9))
            #expect(error.apiError == APIError(
                requestID: "req_rate_limited",
                code: "rate_limited",
                message: "Slow down",
                status: 429,
                retryAfterSeconds: 9,
                details: [
                    "retryAfterSeconds": .number(3),
                    "limit": .string("write-mutations")
                ]
            ))
        }
    }

    @Test("ordinary server error envelopes preserve full API error fields")
    func ordinaryServerErrorEnvelopesPreserveFullAPIErrorFields() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 503,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_origin_down",
                        code: "database_unavailable",
                        message: "Try again soon",
                        status: 503,
                        details: #""region": "iad", "retryClass": "transient""#
                    )
                ))
            ]
        )
        let transport = URLSessionAPITransport(session: session)

        do {
            _ = try await transport.send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected server error envelope to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_origin_down")
            #expect(error.statusCode == 503)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
            #expect(error.apiError == APIError(
                requestID: "req_origin_down",
                code: "database_unavailable",
                message: "Try again soon",
                status: 503,
                details: [
                    "region": .string("iad"),
                    "retryClass": .string("transient")
                ]
            ))
        }
    }

    @Test("401 responses refresh configuration and replay authenticated requests once")
    func unauthorizedResponsesRefreshConfigurationAndReplayAuthenticatedRequestsOnce() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_expired_token",
                        code: "invalid_token",
                        message: "Refresh required",
                        status: 401
                    )
                )),
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: Self.successEnvelope(requestID: "req_after_refresh", name: "Fresh spoon")
                ))
            ]
        )
        let refresher = RecordingAuthenticationRefresher(
            refreshedConfiguration: Self.configuration(bearerToken: "sj_access_refreshed")
        )
        let transport = URLSessionAPITransport(session: session, authenticationRefresher: refresher)

        let replayedRequest = Self.privateMutationRequest()

        let envelope = try await transport.send(
            replayedRequest,
            configuration: Self.configuration(bearerToken: "sj_access_expired"),
            decode: TransportPayload.self
        )
        let requests = await session.capturedRequests()
        let refreshCalls = await refresher.capturedErrors()
        let firstRequest = try #require(requests.first)
        let secondRequest = try #require(requests.dropFirst().first)

        #expect(envelope.requestID == "req_after_refresh")
        #expect(envelope.data == TransportPayload(name: "Fresh spoon"))
        #expect(requests.count == 2)
        #expect(firstRequest.httpMethod == "POST")
        #expect(secondRequest.httpMethod == firstRequest.httpMethod)
        #expect(secondRequest.url == firstRequest.url)
        #expect(secondRequest.cachePolicy == firstRequest.cachePolicy)
        #expect(secondRequest.httpBody == firstRequest.httpBody)
        #expect(firstRequest.url?.absoluteString == "https://spoonjoy.app/api/v1/spoons?source=siri")
        #expect(firstRequest.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(firstRequest.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(secondRequest.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(firstRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(secondRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(firstRequest.value(forHTTPHeaderField: "X-Client-Mutation-Id") == "spoon-siri-1")
        #expect(secondRequest.value(forHTTPHeaderField: "X-Client-Mutation-Id") == "spoon-siri-1")
        #expect(firstRequest.value(forHTTPHeaderField: "Authorization") == "Bearer sj_access_expired")
        #expect(secondRequest.value(forHTTPHeaderField: "Authorization") == "Bearer sj_access_refreshed")
        #expect(refreshCalls == [
            APIError(
                requestID: "req_expired_token",
                code: "invalid_token",
                message: "Refresh required",
                status: 401
            )
        ])
    }

    @Test("a second 401 after refresh is surfaced instead of looping")
    func secondUnauthorizedResponseAfterRefreshIsSurfacedInsteadOfLooping() async throws {
        let session = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_expired_token",
                        code: "invalid_token",
                        message: "Refresh required",
                        status: 401
                    )
                )),
                .success(Self.response(
                    statusCode: 401,
                    headers: ["Content-Type": "application/json"],
                    body: Self.errorEnvelope(
                        requestID: "req_still_invalid",
                        code: "invalid_token",
                        message: "Still invalid",
                        status: 401
                    )
                ))
            ]
        )
        let refresher = RecordingAuthenticationRefresher(
            refreshedConfiguration: Self.configuration(bearerToken: "sj_access_refreshed")
        )
        let transport = URLSessionAPITransport(session: session, authenticationRefresher: refresher)

        do {
            _ = try await transport.send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access_expired"),
                decode: TransportPayload.self
            )
            Issue.record("Expected second unauthorized response to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_still_invalid")
            #expect(error.retryDecision == .refreshAuthentication)
            #expect(error.apiError?.code == "invalid_token")
            #expect(await session.capturedRequests().count == 2)
            #expect(await refresher.capturedErrors().count == 1)
        }
    }

    @Test("non JSON and malformed JSON failures retain status and request id context")
    func nonJSONAndMalformedJSONFailuresRetainContext() async throws {
        let nonJSONSession = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 502,
                    headers: ["Content-Type": "text/html", "X-Request-Id": "req_edge_html"],
                    body: Data("<html>bad gateway</html>".utf8)
                ))
            ]
        )
        let malformedJSONSession = RecordingURLSession(
            responses: [
                .success(Self.response(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json", "X-Request-Id": "req_bad_json"],
                    body: Data(#"{"ok": true, "requestId": "req_bad_json", "data":"#.utf8)
                ))
            ]
        )

        do {
            _ = try await URLSessionAPITransport(session: nonJSONSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected non-JSON response to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_edge_html")
            #expect(error.statusCode == 502)
            #expect(error.isNonJSONResponse)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
        }

        do {
            _ = try await URLSessionAPITransport(session: malformedJSONSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected malformed JSON response to throw")
        } catch let error as APITransportError {
            #expect(error.requestID == "req_bad_json")
            #expect(error.statusCode == 200)
            #expect(error.isMalformedJSONResponse)
            #expect(error.retryDecision == .doNotRetry)
        }
    }

    @Test("offline failures and cancellations are classified distinctly")
    func offlineFailuresAndCancellationsAreClassifiedDistinctly() async throws {
        let offlineSession = RecordingURLSession(responses: [.failure(URLError(.notConnectedToInternet))])
        let cancelledSession = RecordingURLSession(responses: [.failure(URLError(.cancelled))])

        do {
            _ = try await URLSessionAPITransport(session: offlineSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected offline URL error to throw")
        } catch let error as APITransportError {
            #expect(error.isOffline)
            #expect(error.retryDecision == .retrySameRequest(afterSeconds: nil))
            #expect(error.requestID == nil)
        }

        do {
            _ = try await URLSessionAPITransport(session: cancelledSession).send(
                Self.privateReadRequest(),
                configuration: Self.configuration(bearerToken: "sj_access"),
                decode: TransportPayload.self
            )
            Issue.record("Expected cancelled URL error to throw")
        } catch let error as APITransportError {
            #expect(error.isCancelled)
            #expect(error.retryDecision == .doNotRetry)
            #expect(error.requestID == nil)
        }
    }

    private static func privateReadRequest() -> APIRequestBuilder {
        APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "shopping-list"],
            queryItems: [],
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: .privateNoStore
        )
    }

    private static func privateMutationRequest() -> APIRequestBuilder {
        APIRequestBuilder(
            method: .post,
            pathComponents: ["api", "v1", "spoons"],
            queryItems: [URLQueryItem(name: "source", value: "siri")],
            headers: [
                "Content-Type": "application/json",
                "X-Client-Mutation-Id": "spoon-siri-1"
            ],
            body: Data(#"{"recipeId":"recipe_lemon","spooned":true}"#.utf8),
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: .privateNoStore
        )
    }

    private static func configuration(bearerToken: String) -> APIClientConfiguration {
        APIClientConfiguration(
            baseURL: URL(string: "https://spoonjoy.app")!,
            bearerToken: bearerToken
        )
    }

    private static func response(
        statusCode: Int,
        headers: [String: String],
        body: Data
    ) -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: URL(string: "https://spoonjoy.app/api/v1/shopping-list")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (body, response)
    }

    private static func successEnvelope(requestID: String, name: String) -> Data {
        Data(
            """
            {
              "ok": true,
              "requestId": "\(requestID)",
              "data": { "name": "\(name)" }
            }
            """.utf8
        )
    }

    private static func errorEnvelope(
        requestID: String,
        code: String,
        message: String,
        status: Int,
        details: String? = nil
    ) -> Data {
        let detailsObject = details.map { ", \"details\": { \($0) }" } ?? ""
        return Data(
            """
            {
              "ok": false,
              "requestId": "\(requestID)",
              "error": {
                "code": "\(code)",
                "message": "\(message)",
                "status": \(status)\(detailsObject)
              }
            }
            """.utf8
        )
    }
}

private struct TransportPayload: Decodable, Equatable, Sendable {
    let name: String
}

private actor RecordingURLSession: URLSessionPerforming {
    private var responses: [Result<(Data, URLResponse), Error>]
    private var requests: [URLRequest] = []

    init(responses: [Result<(Data, URLResponse), Error>]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }

        let response = responses.removeFirst()
        return try response.get()
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }
}

private actor RecordingAuthenticationRefresher: APIAuthenticationRefresher {
    private let refreshedConfiguration: APIClientConfiguration
    private var errors: [APIError] = []

    init(refreshedConfiguration: APIClientConfiguration) {
        self.refreshedConfiguration = refreshedConfiguration
    }

    func refreshedConfiguration(
        after error: APIError,
        configuration: APIClientConfiguration
    ) async throws -> APIClientConfiguration {
        errors.append(error)
        #expect(configuration.bearerToken == "sj_access_expired")
        return refreshedConfiguration
    }

    func capturedErrors() -> [APIError] {
        errors
    }
}
