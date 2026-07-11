import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Auth telemetry contracts")
struct AuthTelemetryContractTests {
    @Test("native telemetry encodes auth events without secrets")
    func nativeTelemetryEncodesAuthEventsWithoutSecrets() throws {
        let request = try NativeTelemetryRequests.recordEvent(NativeTelemetryEvent(
            name: .authFlowFailed,
            stage: "apple-sign-in",
            environment: "production",
            metadata: NativeTelemetryAppMetadata(platform: "ios", appVersion: "1.0", buildNumber: "42"),
            route: "kitchen",
            errorType: "APITransportError",
            requestID: "req_apple_exchange",
            status: 401,
            apiCode: "apple_identity_token_invalid",
            retry: "do_not_retry",
            accountBound: false,
            authProvider: "apple",
            authPhase: "backend_exchange_failed",
            authOutcome: "failed",
            authDiagnosticCode: "provider_invalid_identity_token",
            authSessionState: "signed_out",
            authCredentialPresent: true,
            authIdentityTokenPresent: true,
            authRawNoncePresent: true,
            authEmailPresent: false,
            authFullNamePresent: false,
            authOAuthStatePresent: false,
            authRedirectScheme: "https",
            authRedirectHost: "spoonjoy.app"
        ))
        let urlRequest = try request.urlRequest(configuration: Self.privateConfiguration)
        let body = try decodeTelemetryBody(urlRequest)

        #expect(body["event"] as? String == "auth_flow_failed")
        #expect(body["authProvider"] as? String == "apple")
        #expect(body["authPhase"] as? String == "backend_exchange_failed")
        #expect(body["authOutcome"] as? String == "failed")
        #expect(body["authDiagnosticCode"] as? String == "provider_invalid_identity_token")
        #expect(body["authSessionState"] as? String == "signed_out")
        #expect(body["authCredentialPresent"] as? Bool == true)
        #expect(body["authIdentityTokenPresent"] as? Bool == true)
        #expect(body["authRawNoncePresent"] as? Bool == true)
        #expect(body["authEmailPresent"] as? Bool == false)
        #expect(body["authFullNamePresent"] as? Bool == false)
        #expect(body["authOAuthStatePresent"] as? Bool == false)
        #expect(body["authRedirectScheme"] as? String == "https")
        #expect(body["authRedirectHost"] as? String == "spoonjoy.app")
        #expect(!body.keys.contains("identityToken"))
        #expect(!body.keys.contains("rawNonce"))
        #expect(!body.keys.contains("password"))
        #expect(!body.keys.contains("accessToken"))
        #expect(!body.keys.contains("refreshToken"))
    }

    @Test("Apple sign-in sends structured native telemetry for every phase")
    func appleSignInSendsStructuredNativeTelemetryForEveryPhase() throws {
        let telemetry = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/NativeAppleSignInTelemetry.swift"))
        let signedOut = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift"))
        let root = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"))

        expectContent(
            telemetry,
            in: "Apps/Spoonjoy/Shared/AppShell/NativeAppleSignInTelemetry.swift",
            contains: [
                "NativeAuthTelemetryDescriptor",
                "NativeTelemetryRequests.recordEvent",
                "authProvider: \"apple\"",
                "identityTokenPresent",
                "rawNoncePresent",
                "credentialPresent",
                "recordPhase(",
                "recordFailure("
            ],
            forbids: [
                "identityToken, privacy:",
                "rawNonce, privacy:",
                "password, privacy:",
                "accessToken, privacy:",
                "refreshToken, privacy:"
            ]
        )

        expectContent(
            signedOut,
            in: "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
            contains: [
                "appleSignInTelemetry",
                "recordPhase(\"authorization_request_started\"",
                "recordPhase(\"authorization_completed\"",
                "recordPhase(\"authorization_canceled\"",
                "recordFailure(phase: \"credential_validation_failed\"",
                "recordPhase(\"backend_exchange_started\"",
                "recordPhase(\"backend_exchange_succeeded\"",
                "recordFailure(phase: \"sign_in_failed\""
            ],
            forbids: [
                "Could not finish sign-in: \\(error)"
            ]
        )

        expectContent(
            root,
            in: "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
            contains: [
                "NativeAppleSignInTelemetry.Client",
                "nativeTelemetryMetadata()",
                "backend_request_failed",
                "recordFailure("
            ],
            forbids: []
        )
    }

    private static let privateConfiguration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )
}

private func decodeTelemetryBody(_ request: URLRequest) throws -> [String: Any] {
    let data = try #require(request.httpBody)
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
}

private func readRepoFile(_ relativePath: String) throws -> String {
    try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
}

private func repoRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func uncommentedSwift(_ source: String) -> String {
    source
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line -> String in
            guard let commentRange = line.range(of: "//") else {
                return String(line)
            }
            return String(line[..<commentRange.lowerBound])
        }
        .joined(separator: "\n")
}

private func expectContent(
    _ content: String,
    in path: String,
    contains requiredTokens: [String],
    forbids forbiddenTokens: [String]
) {
    let missing = requiredTokens.filter { !content.contains($0) }
    let forbidden = forbiddenTokens.filter { content.contains($0) }
    #expect(missing.isEmpty, Comment(rawValue: "\(path) missing \(missing.joined(separator: ", "))"))
    #expect(forbidden.isEmpty, Comment(rawValue: "\(path) contains forbidden \(forbidden.joined(separator: ", "))"))
}
