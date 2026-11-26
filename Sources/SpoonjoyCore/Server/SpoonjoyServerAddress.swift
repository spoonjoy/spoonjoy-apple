import Foundation

/// Why an address the cook typed is not a server address the app can use.
public enum SpoonjoyServerAddressError: Error, Equatable, Sendable {
    case empty
    case unreadable
    case unsupportedScheme(String)
    case credentialsNotAllowed
    /// Plain `http://` to a host on the internet: the system refuses it (App Transport Security), and a password sent
    /// over it could be read on the way.
    case insecureRemoteHost(String)

    public var message: String {
        switch self {
        case .empty:
            "Type your server's address."
        case .unreadable:
            "That isn't a web address. Type it as it appears in your browser, such as recipes.example.com."
        case .unsupportedScheme(let scheme):
            "Spoonjoy servers use https:// or http://, not \(scheme)://."
        case .credentialsNotAllowed:
            "Leave the name and password out of the address. You sign in on the next screen."
        case .insecureRemoteHost(let host):
            "\(host) needs https://. Plain http:// works only for a server on your own network."
        }
    }
}

/// The Spoonjoy server the app talks to: its origin (scheme, host and port), with no path and no trailing slash, so
/// every request path appends to it the same way it does to `https://spoonjoy.app`.
public struct SpoonjoyServerAddress: Equatable, Hashable, Sendable {
    public let baseURL: URL

    public static let spoonjoyApp = SpoonjoyServerAddress(origin: URL(string: "https://spoonjoy.app")!)

    private init(origin: URL) {
        baseURL = origin
    }

    /// The address as the cook should read it: the host and any port, with `http://` in front when the server is not
    /// on https, because that is worth knowing.
    public var displayName: String {
        let hostAndPort = baseURL.absoluteString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        return baseURL.scheme == "http" ? "http://\(hostAndPort)" : hostAndPort
    }

    /// The server's address for a URL that already names one, such as a launch override or a saved choice; nil when
    /// it is not one the app could use.
    public init?(baseURL: URL) {
        guard let address = try? Self.parse(baseURL.absoluteString) else {
            return nil
        }
        self = address
    }

    /// Reads an address as a cook types it: `recipes.example.com`, `192.168.1.20:8080`, `https://recipes.example.com/`
    /// or a page of the server pasted from the browser. Without a scheme, a server on the local network is taken to be
    /// plain `http://` and any other `https://`. The host is lowercased, a default port and any path, query or fragment
    /// are dropped.
    public static func parse(_ input: String) throws(SpoonjoyServerAddressError) -> SpoonjoyServerAddress {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw .empty
        }
        guard !trimmed.contains(where: \.isWhitespace) else {
            throw .unreadable
        }

        let hasScheme = trimmed.range(of: "^[A-Za-z][A-Za-z0-9+.-]*://", options: .regularExpression) != nil
        guard let components = URLComponents(string: hasScheme ? trimmed : "placeholder://" + trimmed),
              let rawHost = components.host, !rawHost.isEmpty else {
            throw .unreadable
        }
        guard components.user == nil, components.password == nil else {
            throw .credentialsNotAllowed
        }

        let host = rawHost.lowercased()
        let scheme: String
        if hasScheme {
            scheme = (components.scheme ?? "").lowercased()
        } else {
            scheme = isLocalNetworkHost(host) ? "http" : "https"
        }
        guard scheme == "https" || scheme == "http" else {
            throw .unsupportedScheme(scheme)
        }
        guard scheme == "https" || isLocalNetworkHost(host) else {
            throw .insecureRemoteHost(host)
        }

        var origin = URLComponents()
        origin.scheme = scheme
        origin.host = host
        if let port = components.port, !(scheme == "https" && port == 443), !(scheme == "http" && port == 80) {
            origin.port = port
        }
        guard let url = origin.url else {
            throw .unreadable
        }
        return SpoonjoyServerAddress(origin: url)
    }

    /// A host only the local network can reach: `localhost`, a one-word name, a `.local` or `.home.arpa` name, or a
    /// loopback, private, link-local or shared (Tailscale's 100.64/10) address. App Transport Security lets the app
    /// use plain `http://` to these (`NSAllowsLocalNetworking`).
    public static func isLocalNetworkHost(_ host: String) -> Bool {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host.contains(":") {
            return host == "::1" || host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80:")
        }
        let numbers = host.split(separator: ".", omittingEmptySubsequences: false).map { UInt8($0) }
        if numbers.count == 4, !numbers.contains(nil) {
            let numbers = numbers.map { $0! }
            switch (numbers[0], numbers[1]) {
            case (10, _), (127, _), (192, 168), (169, 254):
                return true
            case (172, let second):
                return (16...31).contains(second)
            case (100, let second):
                return (64...127).contains(second)
            default:
                return false
            }
        }
        return host == "localhost" || !host.contains(".") || host.hasSuffix(".local") || host.hasSuffix(".localhost")
            || host.hasSuffix(".home.arpa")
    }
}
