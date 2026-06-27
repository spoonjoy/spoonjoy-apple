import AuthenticationServices
import Foundation
import SpoonjoyCore

#if os(macOS)
import AppKit
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

enum SpoonjoyWebAuthenticationCallback: Equatable {
    case https(host: String, path: String)
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
    private let oauthCallback = URL(string: "https://spoonjoy.app/oauth/callback")!

    init(
        sessionFactory: @escaping SpoonjoyWebAuthenticationSessionFactory,
        callbackHandler: @escaping @MainActor (URL) -> Void
    ) {
        self.sessionFactory = sessionFactory
        self.callbackHandler = callbackHandler
    }

    convenience init(callbackHandler: @escaping @MainActor (URL) -> Void) {
        self.init(
            sessionFactory: { authorizationURL, _, completionHandler in
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
            .https(host: "spoonjoy.app", path: "/oauth/callback")
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

    func handleOAuthCallback(_ callbackURL: URL) {
        callbackHandler(callbackURL)
    }

    func cancel() {
        activeSession?.cancel()
        activeSession = nil
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
