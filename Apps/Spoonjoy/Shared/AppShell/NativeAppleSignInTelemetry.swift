import AuthenticationServices
import OSLog
import SpoonjoyCore

enum NativeAppleSignInTelemetry {
    private static let logger = Logger(subsystem: "app.spoonjoy", category: "auth.apple")

    struct Client: Sendable {
        let environment: String
        let metadata: NativeTelemetryAppMetadata
        let configuration: APIClientConfiguration
        let report: @Sendable (NativeTelemetryEvent, APIClientConfiguration) async -> Void

        static let disabled = Client(
            environment: "unknown",
            metadata: .unknown,
            configuration: .spoonjoyProduction,
            report: { _, _ in }
        )

        init(
            environment: String,
            metadata: NativeTelemetryAppMetadata,
            configuration: APIClientConfiguration,
            report: @escaping @Sendable (NativeTelemetryEvent, APIClientConfiguration) async -> Void = Self.defaultReport
        ) {
            self.environment = environment
            self.metadata = metadata
            self.configuration = configuration
            self.report = report
        }

        func recordPhase(
            _ phase: String,
            outcome: NativeAuthTelemetryOutcome = .started,
            credentialPresent: Bool? = nil,
            identityTokenPresent: Bool? = nil,
            rawNoncePresent: Bool? = nil,
            emailPresent: Bool? = nil,
            fullNamePresent: Bool? = nil,
            oauthStatePresent: Bool? = nil,
            redirectURL: URL? = nil,
            sessionState: String? = "signed_out"
        ) async {
            NativeAppleSignInTelemetry.logPhase(phase)
            let descriptor = NativeAuthTelemetryDescriptor(
                authProvider: "apple",
                phase: phase,
                outcome: outcome,
                sessionState: sessionState,
                credentialPresent: credentialPresent,
                identityTokenPresent: identityTokenPresent,
                rawNoncePresent: rawNoncePresent,
                emailPresent: emailPresent,
                fullNamePresent: fullNamePresent,
                oauthStatePresent: oauthStatePresent,
                redirectScheme: redirectURL?.scheme,
                redirectHost: redirectURL?.host
            )
            await record(descriptor)
        }

        func recordCompleted(
            phase: String,
            credential: NativeAppleSignInCredential? = nil,
            sessionState: String? = "authenticated"
        ) async {
            NativeAppleSignInTelemetry.logPhase(phase)
            let descriptor = NativeAuthTelemetryDescriptor(
                authProvider: "apple",
                phase: phase,
                outcome: .completed,
                sessionState: sessionState,
                credentialPresent: credential != nil,
                identityTokenPresent: credential?.identityToken.isEmpty == false,
                rawNoncePresent: credential?.rawNonce.isEmpty == false,
                emailPresent: credential?.email?.isEmpty == false,
                fullNamePresent: credential?.fullName?.isEmpty == false
            )
            await record(descriptor)
        }

        func recordFailure(
            phase: String,
            code: String,
            credentialPresent: Bool? = nil,
            identityTokenPresent: Bool? = nil,
            rawNoncePresent: Bool? = nil,
            emailPresent: Bool? = nil,
            fullNamePresent: Bool? = nil,
            credential: NativeAppleSignInCredential? = nil,
            error: Error? = nil,
            sessionState: String? = "signed_out"
        ) async {
            NativeAppleSignInTelemetry.logFailure(phase: phase, code: code)
            let diagnostic = error.map(NativeAppleSignInTelemetry.diagnosticContext(for:))
            let descriptor = NativeAuthTelemetryDescriptor(
                authProvider: "apple",
                phase: phase,
                outcome: .failed,
                diagnosticCode: code,
                sessionState: sessionState,
                credentialPresent: credentialPresent ?? (credential != nil),
                identityTokenPresent: identityTokenPresent ?? (credential?.identityToken.isEmpty == false),
                rawNoncePresent: rawNoncePresent ?? (credential?.rawNonce.isEmpty == false),
                emailPresent: emailPresent ?? (credential?.email?.isEmpty == false),
                fullNamePresent: fullNamePresent ?? (credential?.fullName?.isEmpty == false),
                errorType: diagnostic?.type,
                requestID: diagnostic?.requestID,
                status: diagnostic?.status,
                apiCode: diagnostic?.code,
                retry: diagnostic?.retry,
                accountBound: false
            )
            await record(descriptor)
        }

        private func record(_ descriptor: NativeAuthTelemetryDescriptor) async {
            await report(descriptor.telemetryEvent(environment: environment, metadata: metadata), configuration)
        }

        private static func defaultReport(
            event: NativeTelemetryEvent,
            configuration: APIClientConfiguration
        ) async {
            do {
                _ = try await URLSessionAPITransport().send(
                    try NativeTelemetryRequests.recordEvent(event),
                    configuration: configuration,
                    decode: NativeTelemetryResponse.self
                )
            } catch {
                // Sign-in telemetry is diagnostic only and must never block auth UX.
            }
        }
    }

    static func logPhase(_ phase: String) {
        logger.info("phase=\(phase, privacy: .public)")
    }

    static func logFailure(phase: String, code: String) {
        logger.error("phase=\(phase, privacy: .public) error_code=\(code, privacy: .public)")
    }

    static func diagnosticCode(for error: Error) -> String {
        if let authorizationError = error as? ASAuthorizationError {
            return "as_authorization_\(authorizationError.code.rawValue)"
        }
        if let transportError = error as? APITransportError {
            if let providerCode = providerCode(from: transportError.apiError) {
                return "provider_\(providerCode)"
            }
            if let apiError = transportError.apiError {
                return "api_\(apiError.code)_\(apiError.status)"
            }
            if let statusCode = transportError.statusCode {
                return "http_\(statusCode)"
            }
            return "transport_\(String(describing: transportError.kind))"
        }
        return "unexpected_\(String(describing: type(of: error)))"
    }

    private static func providerCode(from apiError: APIError?) -> String? {
        guard let providerCode = apiError?.details["providerCode"],
              case .string(let value) = providerCode,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func diagnosticContext(
        for error: Error
    ) -> (type: String, requestID: String?, status: Int?, code: String?, retry: String?) {
        let type = String(describing: Swift.type(of: error))
        guard let transportError = error as? APITransportError else {
            return (type, nil, nil, nil, nil)
        }

        return (
            type,
            transportError.requestID ?? transportError.apiError?.requestID,
            transportError.statusCode ?? transportError.apiError?.status,
            transportError.apiError?.code,
            retryDescription(transportError.retryDecision)
        )
    }

    private static func retryDescription(_ decision: APIRetryDecision) -> String {
        switch decision {
        case .retrySameRequest(let seconds):
            if let seconds {
                "retry_same_request_after_\(seconds)s"
            } else {
                "retry_same_request"
            }
        case .refreshAuthentication:
            "refresh_authentication"
        case .doNotRetry:
            "do_not_retry"
        }
    }
}
