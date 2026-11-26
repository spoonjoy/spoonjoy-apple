import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Spoonjoy server address")
struct SpoonjoyServerAddressTests {
    @Test("an address keeps only the origin: lowercased host, no default port, no path, no trailing slash", arguments: [
        ("https://spoonjoy.app", "https://spoonjoy.app"),
        ("https://spoonjoy.app/", "https://spoonjoy.app"),
        ("  https://Recipes.Example.com/  \n", "https://recipes.example.com"),
        ("https://recipes.example.com:443/recipes/abc?tab=steps#cook", "https://recipes.example.com"),
        ("https://recipes.example.com:8443", "https://recipes.example.com:8443"),
        ("HTTPS://recipes.example.com", "https://recipes.example.com"),
        ("http://192.168.1.20:8080/", "http://192.168.1.20:8080"),
        ("http://192.168.1.20:80", "http://192.168.1.20"),
        ("http://localhost:8080", "http://localhost:8080"),
        ("https://192.168.1.20", "https://192.168.1.20")
    ])
    func normalizesToTheOrigin(input: String, expected: String) throws {
        #expect(try SpoonjoyServerAddress.parse(input).baseURL.absoluteString == expected)
    }

    @Test("without a scheme, a local server is http and any other https", arguments: [
        ("recipes.example.com", "https://recipes.example.com"),
        ("recipes.example.com/", "https://recipes.example.com"),
        ("192.168.1.20:8080", "http://192.168.1.20:8080"),
        ("10.0.0.5", "http://10.0.0.5"),
        ("localhost:8080", "http://localhost:8080"),
        ("kitchen:8080", "http://kitchen:8080"),
        ("kitchen.local:8080", "http://kitchen.local:8080"),
        ("pantry.home.arpa", "http://pantry.home.arpa"),
        ("8.8.8.8", "https://8.8.8.8")
    ])
    func guessesTheScheme(input: String, expected: String) throws {
        #expect(try SpoonjoyServerAddress.parse(input).baseURL.absoluteString == expected)
    }

    @Test("an address the app cannot use says why", arguments: [
        ("", SpoonjoyServerAddressError.empty),
        ("   \n", .empty),
        ("recipes example com", .unreadable),
        ("https://", .unreadable),
        ("ftp://recipes.example.com", .unsupportedScheme("ftp")),
        ("https://ari:secret@recipes.example.com", .credentialsNotAllowed),
        ("http://recipes.example.com", .insecureRemoteHost("recipes.example.com")),
        ("http://8.8.8.8:8080", .insecureRemoteHost("8.8.8.8"))
    ])
    func refusesAnUnusableAddress(input: String, expected: SpoonjoyServerAddressError) {
        #expect(throws: expected) {
            try SpoonjoyServerAddress.parse(input)
        }
    }

    @Test("every refusal reads as a sentence for the cook")
    func refusalMessages() {
        #expect(SpoonjoyServerAddressError.empty.message == "Type your server's address.")
        #expect(SpoonjoyServerAddressError.unreadable.message.hasPrefix("That isn't a web address."))
        #expect(SpoonjoyServerAddressError.unsupportedScheme("ftp").message == "Spoonjoy servers use https:// or http://, not ftp://.")
        #expect(SpoonjoyServerAddressError.credentialsNotAllowed.message.hasPrefix("Leave the name and password out"))
        #expect(SpoonjoyServerAddressError.insecureRemoteHost("recipes.example.com").message
            == "recipes.example.com needs https://. Plain http:// works only for a server on your own network.")
    }

    @Test("the display name shows http:// only when the server is not on https")
    func displayName() throws {
        #expect(SpoonjoyServerAddress.spoonjoyApp.displayName == "spoonjoy.app")
        #expect(try SpoonjoyServerAddress.parse("recipes.example.com:8443").displayName == "recipes.example.com:8443")
        #expect(try SpoonjoyServerAddress.parse("192.168.1.20:8080").displayName == "http://192.168.1.20:8080")
    }

    @Test("a URL that already names a server reads the same way, and one that cannot be used is nil")
    func initFromURL() throws {
        #expect(SpoonjoyServerAddress(baseURL: try #require(URL(string: "https://spoonjoy.app/"))) == .spoonjoyApp)
        #expect(SpoonjoyServerAddress(baseURL: try #require(URL(string: "http://recipes.example.com"))) == nil)
    }

    @Test("local network hosts are the ones App Transport Security lets the app reach over http", arguments: [
        ("localhost", true), ("kitchen", true), ("kitchen.local", true), ("app.localhost", true), ("pantry.home.arpa", true),
        ("127.0.0.1", true), ("10.1.2.3", true), ("192.168.0.9", true), ("169.254.3.4", true),
        ("172.16.0.1", true), ("172.31.255.1", true), ("172.32.0.1", false), ("172.15.0.1", false),
        ("100.64.0.1", true), ("100.127.0.1", true), ("100.128.0.1", false), ("100.63.0.1", false),
        ("192.169.0.1", false), ("8.8.8.8", false), ("1.2.3.999", false), ("recipes.example.com", false),
        ("::1", true), ("[::1]", true), ("fd12::1", true), ("fc00::1", true), ("fe80::1", true), ("2001:db8::1", false)
    ])
    func localNetworkHosts(host: String, isLocal: Bool) {
        #expect(SpoonjoyServerAddress.isLocalNetworkHost(host) == isLocal)
    }
}

@Suite("Spoonjoy server check")
struct SpoonjoyServerCheckTests {
    private static let address = SpoonjoyServerAddress.spoonjoyApp

    @Test("the check asks the server's health endpoint for JSON, past any cache")
    func request() {
        let request = SpoonjoyServerCheck.urlRequest(for: Self.address)
        #expect(request.url?.absoluteString == "https://spoonjoy.app/api/v1/health")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.timeoutInterval == SpoonjoyServerCheck.timeout)
    }

    @Test("a Spoonjoy server's health answer passes")
    func spoonjoyPasses() async throws {
        let session = ServerCheckSession(.answer(status: 200, body: Self.health(ok: true, version: "v1")))
        try await SpoonjoyServerCheck.check(Self.address, session: session)
        #expect(await session.requested.map(\.url?.path) == ["/api/v1/health"])
    }

    @Test("anything else that answers is not a Spoonjoy server", arguments: [
        ServerCheckSession.Reply.answer(status: 200, body: "<html>Welcome to nginx</html>"),
        .answer(status: 404, body: health(ok: true, version: "v1")),
        .answer(status: 200, body: health(ok: false, version: "v1")),
        .answer(status: 200, body: health(ok: true, version: "v2")),
        .answer(status: 200, body: #"{"ok":true,"requestId":"req","data":{"status":"up"}}"#),
        .notHTTP
    ])
    func otherAnswersAreRefused(reply: ServerCheckSession.Reply) async {
        await #expect(throws: SpoonjoyServerCheckError.notSpoonjoy("spoonjoy.app")) {
            try await SpoonjoyServerCheck.check(Self.address, session: ServerCheckSession(reply))
        }
    }

    @Test("no answer at all is unreachable")
    func unreachable() async {
        await #expect(throws: SpoonjoyServerCheckError.unreachable("spoonjoy.app")) {
            try await SpoonjoyServerCheck.check(Self.address, session: ServerCheckSession(.failure))
        }
    }

    @Test("both outcomes name the server for the cook")
    func messages() {
        #expect(SpoonjoyServerCheckError.unreachable("http://192.168.1.20:8080").message
            == "Spoonjoy couldn't reach http://192.168.1.20:8080. Check the address, and that the server is running and on this network.")
        #expect(SpoonjoyServerCheckError.notSpoonjoy("recipes.example.com").message
            == "recipes.example.com answered, but it isn't a Spoonjoy server.")
    }

    static func health(ok: Bool, version: String) -> String {
        #"{"ok":true,"requestId":"req_1","data":{"ok":\#(ok),"version":"\#(version)","authenticated":false}}"#
    }
}

@Suite("Spoonjoy server choice")
struct SpoonjoyServerChoiceStoreTests {
    @Test("nothing saved is the app's own server; a saved server comes back; forgetting it goes back to the default")
    func savesAndForgets() throws {
        let defaults = try #require(UserDefaults(suiteName: "server-choice-\(UUID().uuidString)"))
        let store = SpoonjoyServerChoiceStore(defaults: defaults)
        #expect(store.load() == nil)

        let kitchen = try SpoonjoyServerAddress.parse("192.168.1.20:8080")
        store.save(kitchen)
        #expect(defaults.string(forKey: SpoonjoyServerChoiceStore.key) == "http://192.168.1.20:8080")
        #expect(SpoonjoyServerChoiceStore(defaults: defaults).load() == kitchen)

        store.save(nil)
        #expect(store.load() == nil)
        #expect(defaults.object(forKey: SpoonjoyServerChoiceStore.key) == nil)
    }

    @Test("a saved value the app cannot use counts as nothing saved")
    func unreadableSavedValue() throws {
        let defaults = try #require(UserDefaults(suiteName: "server-choice-\(UUID().uuidString)"))
        defaults.set("http://recipes.example.com", forKey: SpoonjoyServerChoiceStore.key)
        #expect(SpoonjoyServerChoiceStore(defaults: defaults).load() == nil)
        defaults.set("", forKey: SpoonjoyServerChoiceStore.key)
        #expect(SpoonjoyServerChoiceStore(defaults: defaults).load() == nil)
    }
}

@Suite("Browser sign-in on the chosen server")
struct ChosenServerAuthorizationTests {
    @Test("the authorize page is the chosen server's, and the code still comes back to the app's own callback")
    func authorizeOnTheChosenServer() throws {
        let state = try #require(OAuthState(rawValue: "state-123"))
        let url = try NativeAuthSession.authorizationURL(
            clientID: "client",
            redirectURI: NativeAuthSession.redirectURI,
            scope: NativeAuthSession.defaultScope,
            state: state,
            codeChallenge: "challenge",
            serverBaseURL: try SpoonjoyServerAddress.parse("192.168.1.20:8080").baseURL
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "http")
        #expect(components.host == "192.168.1.20")
        #expect(components.port == 8080)
        #expect(components.path == "/oauth/authorize")
        #expect(components.queryItems?.first { $0.name == "redirect_uri" }?.value == "https://spoonjoy.app/oauth/callback")
    }

    @Test("without a server named, the authorize page stays spoonjoy.app's")
    func defaultsToProduction() throws {
        let url = try NativeAuthSession.authorizationURL(
            clientID: "client",
            redirectURI: NativeAuthSession.redirectURI,
            scope: NativeAuthSession.defaultScope,
            state: try #require(OAuthState(rawValue: "state-123")),
            codeChallenge: "challenge"
        )
        #expect(url.absoluteString.hasPrefix("https://spoonjoy.app/oauth/authorize?"))
    }
}

actor ServerCheckSession: URLSessionPerforming {
    enum Reply: Sendable, CustomTestStringConvertible {
        case answer(status: Int, body: String)
        case notHTTP
        case failure

        var testDescription: String {
            switch self {
            case .answer(let status, let body): "\(status) \(body.prefix(40))"
            case .notHTTP: "not HTTP"
            case .failure: "no answer"
            }
        }
    }

    private let reply: Reply
    private(set) var requested: [URLRequest] = []

    init(_ reply: Reply) {
        self.reply = reply
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requested.append(request)
        let url = request.url ?? URL(string: "https://spoonjoy.app")!
        switch reply {
        case .answer(let status, let body):
            return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
        case .notHTTP:
            return (Data(), URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        case .failure:
            throw URLError(.cannotConnectToHost)
        }
    }
}
