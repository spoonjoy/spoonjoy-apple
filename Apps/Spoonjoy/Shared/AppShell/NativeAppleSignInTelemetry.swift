import AuthenticationServices
import OSLog
import SpoonjoyCore

enum NativeAppleSignInTelemetry {
    private static let logger = Logger(subsystem: "app.spoonjoy", category: "auth.apple")

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
}
