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

    @Test("auth telemetry descriptors preserve started completed and failed outcomes")
    func authTelemetryDescriptorsPreserveStartedCompletedAndFailedOutcomes() {
        let metadata = NativeTelemetryAppMetadata(platform: "ios", appVersion: "1.0", buildNumber: "28")
        let started = NativeAuthTelemetryDescriptor(
            authProvider: "apple",
            phase: "authorization_request_started",
            outcome: .started,
            diagnosticCode: "apple_sheet_opened",
            sessionState: "signed_out",
            credentialPresent: false,
            identityTokenPresent: false,
            rawNoncePresent: true,
            emailPresent: false,
            fullNamePresent: false,
            oauthStatePresent: false,
            redirectScheme: "https",
            redirectHost: "spoonjoy.app",
            route: "kitchen",
            errorType: nil,
            requestID: nil,
            status: nil,
            apiCode: nil,
            retry: nil,
            accountBound: false
        ).telemetryEvent(environment: "production", metadata: metadata)
        let completed = NativeAuthTelemetryDescriptor(
            authProvider: "apple",
            phase: "backend_exchange_succeeded",
            outcome: .completed
        ).telemetryEvent(environment: "production", metadata: metadata)
        let failed = NativeAuthTelemetryDescriptor(
            authProvider: "apple",
            phase: "backend_exchange_failed",
            outcome: .failed,
            errorType: "APITransportError",
            requestID: "req_apple_exchange",
            status: 401,
            apiCode: "apple_identity_token_invalid",
            retry: "do_not_retry"
        ).telemetryEvent(environment: "production", metadata: metadata)

        #expect(started.name == .authFlowStarted)
        #expect(started.stage == "auth")
        #expect(started.environment == "production")
        #expect(started.metadata == metadata)
        #expect(started.route == "kitchen")
        #expect(started.authProvider == "apple")
        #expect(started.authPhase == "authorization_request_started")
        #expect(started.authOutcome == "started")
        #expect(started.authDiagnosticCode == "apple_sheet_opened")
        #expect(started.authSessionState == "signed_out")
        #expect(started.authCredentialPresent == false)
        #expect(started.authIdentityTokenPresent == false)
        #expect(started.authRawNoncePresent == true)
        #expect(started.authEmailPresent == false)
        #expect(started.authFullNamePresent == false)
        #expect(started.authOAuthStatePresent == false)
        #expect(started.authRedirectScheme == "https")
        #expect(started.authRedirectHost == "spoonjoy.app")
        #expect(started.accountBound == false)
        #expect(completed.name == .authFlowCompleted)
        #expect(completed.authOutcome == "completed")
        #expect(failed.name == .authFlowFailed)
        #expect(failed.errorType == "APITransportError")
        #expect(failed.requestID == "req_apple_exchange")
        #expect(failed.status == 401)
        #expect(failed.apiCode == "apple_identity_token_invalid")
        #expect(failed.retry == "do_not_retry")
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

private func decodeTelemetryBody(_ request: APIRequest) throws -> [String: Any] {
    let data = try #require(request.body)
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
