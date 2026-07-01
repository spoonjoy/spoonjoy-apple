import AuthenticationServices
import Foundation
import SpoonjoyCore

#if os(macOS)
import AppKit
import Darwin
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

enum SpoonjoyWebAuthenticationCallback: Equatable {
    case https(host: String, path: String)
    case loopback(host: String, port: UInt16, path: String)
}

@MainActor
protocol SpoonjoyWebAuthenticationSessionProtocol: AnyObject {
    var prefersEphemeralWebBrowserSession: Bool { get set }
    func start() -> Bool
    func cancel()
}

typealias SpoonjoyWebAuthenticationSessionFactory = @MainActor (
    _ authorizationURL: URL,
    _ callback: SpoonjoyWebAuthenticationCallback,
    _ completionHandler: @escaping @MainActor (URL?, Error?) -> Void
) -> any SpoonjoyWebAuthenticationSessionProtocol

extension ASWebAuthenticationSession: SpoonjoyWebAuthenticationSessionProtocol {}

@MainActor
final class SpoonjoyWebAuthenticationSession {
    private let sessionFactory: SpoonjoyWebAuthenticationSessionFactory
    private let callbackHandler: @MainActor (URL) -> Void
    private var activeSession: (any SpoonjoyWebAuthenticationSessionProtocol)?
    private let oauthCallback: URL

    init(
        callbackURL: URL,
        sessionFactory: @escaping SpoonjoyWebAuthenticationSessionFactory,
        callbackHandler: @escaping @MainActor (URL) -> Void
    ) {
        self.oauthCallback = callbackURL
        self.sessionFactory = sessionFactory
        self.callbackHandler = callbackHandler
    }

    convenience init(callbackURL: URL, callbackHandler: @escaping @MainActor (URL) -> Void) {
        self.init(
            callbackURL: callbackURL,
            sessionFactory: { authorizationURL, _, completionHandler in
#if os(macOS) && DEBUG
                if callbackURL.scheme?.lowercased() == "http",
                   callbackURL.host?.lowercased() == "127.0.0.1",
                   callbackURL.path(percentEncoded: true) == "/callback",
                   callbackURL.port == 53123 {
                    return SpoonjoyLoopbackWebAuthenticationSession(
                        authorizationURL: authorizationURL,
                        callbackURL: callbackURL,
                        completionHandler: completionHandler
                    )
                }
#endif
                guard let presentationContextProvider = SpoonjoyAuthenticationPresentationContextProvider.make() else {
                    return SpoonjoyUnavailableWebAuthenticationSession()
                }
                let callback = ASWebAuthenticationSession.Callback.https(host: "spoonjoy.app", path: "/oauth/callback")
                let session = ASWebAuthenticationSession(url: authorizationURL, callback: callback) { url, error in
                    Task { @MainActor in
                        completionHandler(url, error)
                    }
                }
                session.presentationContextProvider = presentationContextProvider
                return session
            },
            callbackHandler: callbackHandler
        )
    }

    @discardableResult
    func start(authorizationURL: URL, oauthState _: OAuthState) throws -> Bool {
        _ = try OAuthRedirectValidator.validate(oauthCallback)
        let session = sessionFactory(
            authorizationURL,
            callbackDescriptor(for: oauthCallback)
        ) { [weak self] callbackURL, _ in
            guard let callbackURL else {
                return
            }
            self?.handleOAuthCallback(callbackURL)
        }
        session.prefersEphemeralWebBrowserSession = true
        let didStart = session.start()
        activeSession = didStart ? session : nil
        return didStart
    }

    private func callbackDescriptor(for callbackURL: URL) -> SpoonjoyWebAuthenticationCallback {
        if callbackURL.scheme?.lowercased() == "http",
           let host = callbackURL.host,
           let port = callbackURL.port {
            return .loopback(host: host, port: UInt16(port), path: callbackURL.path(percentEncoded: true))
        }
        return .https(host: "spoonjoy.app", path: "/oauth/callback")
    }

    func handleOAuthCallback(_ callbackURL: URL) {
        callbackHandler(callbackURL)
    }

    func cancel() {
        activeSession?.cancel()
        activeSession = nil
    }
}

#if os(macOS) && DEBUG
@MainActor
private final class SpoonjoyLoopbackWebAuthenticationSession: SpoonjoyWebAuthenticationSessionProtocol {
    var prefersEphemeralWebBrowserSession = false

    private let authorizationURL: URL
    private let callbackURL: URL
    private let completionHandler: @MainActor (URL?, Error?) -> Void
    private var serverSocket: Int32 = -1
    private var serverThread: Thread?
    private var didComplete = false

    init(
        authorizationURL: URL,
        callbackURL: URL,
        completionHandler: @escaping @MainActor (URL?, Error?) -> Void
    ) {
        self.authorizationURL = authorizationURL
        self.callbackURL = callbackURL
        self.completionHandler = completionHandler
    }

    func start() -> Bool {
        guard startLoopbackServer() else {
            return false
        }
        guard NSWorkspace.shared.open(authorizationURL) else {
            cancel()
            return false
        }
        return true
    }

    func cancel() {
        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }
    }

    private func startLoopbackServer() -> Bool {
        let socketFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            return false
        }

        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(53123).bigEndian
        guard inet_pton(AF_INET, "127.0.0.1", &address.sin_addr) == 1 else {
            Darwin.close(socketFD)
            return false
        }

        let bindStatus = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindStatus == 0, Darwin.listen(socketFD, 1) == 0 else {
            Darwin.close(socketFD)
            return false
        }

        serverSocket = socketFD
        let callbackURL = callbackURL
        let completionHandler = completionHandler
        let thread = Thread { [weak self] in
            Self.acceptCallback(on: socketFD, callbackURL: callbackURL) { callback in
                Task { @MainActor in
                    guard let self, !self.didComplete else {
                        return
                    }
                    self.didComplete = true
                    self.serverSocket = -1
                    completionHandler(callback, nil)
                }
            }
        }
        thread.name = "Spoonjoy local OAuth callback"
        serverThread = thread
        thread.start()
        return true
    }

    private nonisolated static func acceptCallback(
        on socketFD: Int32,
        callbackURL: URL,
        completion: @escaping @Sendable (URL) -> Void
    ) {
        let clientFD = Darwin.accept(socketFD, nil, nil)
        guard clientFD >= 0 else {
            return
        }
        defer {
            Darwin.close(clientFD)
            Darwin.close(socketFD)
        }

        var buffer = [UInt8](repeating: 0, count: 8192)
        let byteCount = Darwin.read(clientFD, &buffer, buffer.count)
        guard byteCount > 0,
              let request = String(bytes: buffer.prefix(byteCount), encoding: .utf8),
              let callback = parsedCallbackURL(from: request, callbackURL: callbackURL) else {
            writeResponse("Could not finish Spoonjoy sign-in.", to: clientFD)
            return
        }

        writeResponse("Spoonjoy sign-in is complete. You can return to the app.", to: clientFD)
        completion(callback)
    }

    private nonisolated static func parsedCallbackURL(from request: String, callbackURL: URL) -> URL? {
        guard let firstLine = request.split(separator: "\r\n", maxSplits: 1).first else {
            return nil
        }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2,
              parts[0] == "GET" else {
            return nil
        }
        var components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let target = String(parts[1])
        guard target.hasPrefix("/callback") else {
            return nil
        }
        let splitTarget = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        components?.percentEncodedQuery = splitTarget.count == 2 ? String(splitTarget[1]) : nil
        return components?.url
    }

    private nonisolated static func writeResponse(_ message: String, to clientFD: Int32) {
        let escapedMessage = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let body = """
        <!doctype html><meta charset="utf-8"><title>Spoonjoy</title><body style="font: -apple-system-body; padding: 2rem;">\(escapedMessage)</body>
        """
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(Data(body.utf8).count)\r
        Connection: close\r
        \r
        \(body)
        """
        _ = response.withCString { pointer in
            Darwin.write(clientFD, pointer, strlen(pointer))
        }
    }
}
#endif

private final class SpoonjoyAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor

    @MainActor
    static func make() -> SpoonjoyAuthenticationPresentationContextProvider? {
        guard let anchor = Self.preferredPresentationAnchor else {
            return nil
        }
        return SpoonjoyAuthenticationPresentationContextProvider(anchor: anchor)
    }

    private init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
        super.init()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }

    @MainActor
    private static var preferredPresentationAnchor: ASPresentationAnchor? {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
            return ASPresentationAnchor(windowScene: windowScene)
        }
        return nil
        #elseif os(macOS)
        return NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
            ?? NSApplication.shared.windows.first(where: \.isVisible)
            ?? NSApplication.shared.windows.first
        #else
        return ASPresentationAnchor()
        #endif
    }
}

@MainActor
private final class SpoonjoyUnavailableWebAuthenticationSession: SpoonjoyWebAuthenticationSessionProtocol {
    var prefersEphemeralWebBrowserSession = false

    func start() -> Bool {
        false
    }

    func cancel() {
        // No active system session was created.
    }
}
