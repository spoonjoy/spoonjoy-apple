import AuthenticationServices
import Foundation
import OSLog
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
    private let cancellationHandler: @MainActor (Error?) -> Void
    private var activeSession: (any SpoonjoyWebAuthenticationSessionProtocol)?
    private let oauthCallback: URL
    private static let logger = Logger(subsystem: "app.spoonjoy", category: "auth.browser")
    // One early-cancel retry per sign-in (NativeBrowserOAuthEarlyCancel, spoonjoy-apple#320).
    private var authorizationURL: URL?
    private var sessionStartedAt: TimeInterval?
    private var retried = false
    private var systemUIAppeared = false
    private var generation = 0
    private let uptime: @MainActor () -> TimeInterval
    private let pause: @MainActor (Duration) async -> Void
    // Written once on the main actor in start(); read only in deinit. NotificationCenter removal is thread-safe.
    nonisolated(unsafe) private var resignObserver: (any NSObjectProtocol)?
    #if os(macOS)
    nonisolated(unsafe) private var sheetObservers: [any NSObjectProtocol] = []
    #endif

    init(
        callbackURL: URL,
        sessionFactory: @escaping SpoonjoyWebAuthenticationSessionFactory,
        callbackHandler: @escaping @MainActor (URL) -> Void,
        cancellationHandler: @escaping @MainActor (Error?) -> Void = { _ in },
        uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        pause: @escaping @MainActor (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.oauthCallback = callbackURL
        self.sessionFactory = sessionFactory
        self.callbackHandler = callbackHandler
        self.cancellationHandler = cancellationHandler
        self.uptime = uptime
        self.pause = pause
    }

    convenience init(
        callbackURL: URL,
        callbackHandler: @escaping @MainActor (URL) -> Void,
        cancellationHandler: @escaping @MainActor (Error?) -> Void = { _ in }
    ) {
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
                return SpoonjoySystemWebAuthenticationSession(
                    session: session,
                    presentationContextProvider: presentationContextProvider
                )
            },
            callbackHandler: callbackHandler,
            cancellationHandler: cancellationHandler
        )
    }

    @discardableResult
    func start(authorizationURL: URL, oauthState _: OAuthState) throws -> Bool {
        _ = try OAuthRedirectValidator.validate(oauthCallback)
        self.authorizationURL = authorizationURL
        // The system prompt ("Spoonjoy wants to use spoonjoy.app to sign in") always comes before the sheet and makes
        // the app resign active, so a cancel after that is the person's and is never retried.
        if resignObserver == nil {
            resignObserver = NotificationCenter.default.addObserver(
                forName: Self.resignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.systemUIAppeared = true
                }
            }
        }
        #if os(macOS)
        // On macOS the prompt and sheet attach to the app's own window, so the app may stay active. A window beginning
        // a sheet or resigning key counts too; one from another window only skips a retry.
        if sheetObservers.isEmpty {
            sheetObservers = [NSWindow.willBeginSheetNotification, NSWindow.didResignKeyNotification].map { name in
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.systemUIAppeared = true
                    }
                }
            }
        }
        #endif
        return startSession(authorizationURL)
    }

    private func startSession(_ authorizationURL: URL) -> Bool {
        let sessionGeneration = generation
        let session = sessionFactory(
            authorizationURL,
            callbackDescriptor(for: oauthCallback)
        ) { [weak self] callbackURL, error in
            guard let self else { return }
            guard let callbackURL else {
                // A session the app canceled ends as before, without a retry.
                guard sessionGeneration == self.generation else {
                    self.handleAuthenticationCancellation(error)
                    return
                }
                self.sessionEnded(error)
                return
            }
            Self.logger.notice("\(NativeBrowserOAuthEarlyCancel.callbackMessage, privacy: .public)")
            self.handleOAuthCallback(callbackURL)
        }
        session.prefersEphemeralWebBrowserSession = false
        let didStart = session.start()
        activeSession = didStart ? session : nil
        if didStart {
            sessionStartedAt = uptime()
            Self.logger.notice("\(NativeBrowserOAuthEarlyCancel.startedMessage, privacy: .public)")
        }
        return didStart
    }

    /// iOS can end a session by itself right after an install or update (spoonjoy-apple#320); that one cancel gets
    /// one fresh session after a short pause. Every other end goes to the cancellation handler at once, as before.
    private func sessionEnded(_ error: Error?) {
        let elapsed = sessionStartedAt.map { uptime() - $0 }
        guard let authorizationURL,
              NativeBrowserOAuthEarlyCancel.shouldRetry(
                  error: error,
                  secondsSinceStart: elapsed,
                  systemUIAppeared: systemUIAppeared,
                  alreadyRetried: retried
              ) else {
            let ended = NativeBrowserOAuthEarlyCancel.endedMessage(
                error: error,
                secondsSinceStart: elapsed,
                systemUIAppeared: systemUIAppeared
            )
            Self.logger.notice("\(ended, privacy: .public)")
            handleAuthenticationCancellation(error)
            return
        }
        retried = true
        Self.logger.notice("\(NativeBrowserOAuthEarlyCancel.earlyCancelMessage(error: error, secondsSinceStart: elapsed), privacy: .public)")
        activeSession = nil
        sessionStartedAt = nil
        let pausedGeneration = generation
        retryTask = Task { [weak self, pause] in
            await pause(NativeBrowserOAuthEarlyCancel.retryDelay)
            // The app canceled or dropped the sign-in during the pause: nothing more to do.
            guard let self, pausedGeneration == self.generation else { return }
            if self.startSession(authorizationURL) {
                Self.logger.notice("\(NativeBrowserOAuthEarlyCancel.retriedMessage, privacy: .public)")
            } else {
                Self.logger.notice("\(NativeBrowserOAuthEarlyCancel.retryDidNotStartMessage, privacy: .public)")
                self.handleAuthenticationCancellation(error)
            }
        }
    }

    /// The pending retry after an early cancel, if any; tests await it.
    private(set) var retryTask: Task<Void, Never>?

    deinit {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        #if os(macOS)
        sheetObservers.forEach { NotificationCenter.default.removeObserver($0) }
        #endif
    }

    private static var resignActiveNotification: Notification.Name {
        #if os(macOS)
        NSApplication.willResignActiveNotification
        #else
        UIApplication.willResignActiveNotification
        #endif
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

    func handleAuthenticationCancellation(_ error: Error?) {
        activeSession = nil
        cancellationHandler(error)
    }

    func cancel() {
        generation += 1
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

/// ASWebAuthenticationSession holds its presentation context provider weakly, and `start()` returns false
/// once the provider is gone. This wrapper owns the provider for as long as the session is in use.
@MainActor
final class SpoonjoySystemWebAuthenticationSession: SpoonjoyWebAuthenticationSessionProtocol {
    private let session: ASWebAuthenticationSession
    private let presentationContextProvider: any ASWebAuthenticationPresentationContextProviding

    init(session: ASWebAuthenticationSession, presentationContextProvider: any ASWebAuthenticationPresentationContextProviding) {
        self.session = session
        self.presentationContextProvider = presentationContextProvider
        session.presentationContextProvider = presentationContextProvider
    }

    /// What the system session sees at `start()`; nil means `start()` would return false.
    var attachedPresentationContextProvider: (any ASWebAuthenticationPresentationContextProviding)? {
        session.presentationContextProvider
    }

    var prefersEphemeralWebBrowserSession: Bool {
        get { session.prefersEphemeralWebBrowserSession }
        set { session.prefersEphemeralWebBrowserSession = newValue }
    }

    func start() -> Bool {
        session.start()
    }

    func cancel() {
        session.cancel()
    }
}

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
