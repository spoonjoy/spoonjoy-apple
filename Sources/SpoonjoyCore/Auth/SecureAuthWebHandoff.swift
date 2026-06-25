import Foundation

public enum SecureAuthWebHandoff: String, CaseIterable, Equatable, Sendable {
    case login = "https://spoonjoy.app/login"
    case signup = "https://spoonjoy.app/signup"
    case logout = "https://spoonjoy.app/logout"
    case google = "https://spoonjoy.app/auth/google"
    case github = "https://spoonjoy.app/auth/github"
    case apple = "https://spoonjoy.app/auth/apple"
    case agentConnect = "https://spoonjoy.app/agent/connect"
    case oauthAuthorize = "https://spoonjoy.app/oauth/authorize"

    public var url: URL {
        URL(string: rawValue)!
    }
}
