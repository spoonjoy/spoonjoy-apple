import Foundation

public enum OAuthRedirectValidationError: Error, Equatable {
    case missingHost
    case unsupportedScheme(String?)
    case remoteHTTPHost(String)
    case credentialsNotAllowed
    case fragmentNotAllowed
}

public enum OAuthRedirectValidator {
    public static func validate(_ url: URL) throws -> Bool {
        guard url.fragment == nil else {
            throw OAuthRedirectValidationError.fragmentNotAllowed
        }

        guard url.user == nil, url.password == nil else {
            throw OAuthRedirectValidationError.credentialsNotAllowed
        }

        guard let scheme = url.scheme?.lowercased() else {
            throw OAuthRedirectValidationError.unsupportedScheme(nil)
        }
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            throw OAuthRedirectValidationError.missingHost
        }

        switch scheme {
        case "https":
            return true
        case "http":
            guard host == "localhost" || host == "127.0.0.1" else {
                throw OAuthRedirectValidationError.remoteHTTPHost(host)
            }

            return true
        default:
            throw OAuthRedirectValidationError.unsupportedScheme(scheme)
        }
    }
}
