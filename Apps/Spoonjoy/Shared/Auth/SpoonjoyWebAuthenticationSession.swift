import AuthenticationServices
import Foundation
import SpoonjoyCore

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
            sessionFactory: { [presentationContextProvider = SpoonjoyAuthenticationPresentationContextProvider()] authorizationURL, _, completionHandler in
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
        activeSession = session
        return session.start()
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
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
