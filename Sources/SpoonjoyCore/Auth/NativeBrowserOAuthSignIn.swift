import Foundation

/// The system browser sheet a browser sign-in runs in (ASWebAuthenticationSession in the app, a fake in tests).
@MainActor
public protocol NativeBrowserOAuthWebSession: AnyObject {
    /// Shows the sheet; false when the system refused to.
    func start() -> Bool
    func cancel()
}

/// Makes the sheet for one attempt. `completion` gets the callback URL, or nil and an error when the sheet closed
/// without one (the cook dismissed it, or the system did).
public typealias NativeBrowserOAuthWebSessionFactory = @MainActor (
    _ authorizationURL: URL,
    _ redirectURI: URL,
    _ completion: @escaping @MainActor (URL?, (any Error)?) async -> Void
) -> any NativeBrowserOAuthWebSession

public enum NativeBrowserOAuthStart: Equatable, Sendable {
    case opened(authorizationURL: URL)
    /// This sign-in already has an attempt open (a double tap): nothing new was started.
    case alreadyInProgress
    case couldNotOpen
}

public enum NativeBrowserOAuthFinish: Sendable {
    case signedIn(AuthSession)
    case failed(any Error)
    /// The sheet closed without a callback.
    case canceled
    /// A newer browser sign-in started (in another window), so this one's sheet was closed.
    case superseded
}

/// Holds the one browser sign-in the app may have open. The web app keeps a single provider sign-in per browser
/// cookie jar (its `__oauth` cookie), and every ASWebAuthenticationSession shares Safari's jar, so a second start
/// replaces the first one's server state and the first callback would come back `invalid_state`. The gate is
/// process-wide so two windows cannot both hold one: the newest start wins and the older sheet is closed.
@MainActor
public final class NativeBrowserOAuthGate {
    public static let shared = NativeBrowserOAuthGate()

    private var holder: (id: UUID, supersede: @MainActor () -> Void)?

    public init() {}

    public var activeAttemptID: UUID? {
        holder?.id
    }

    func claim(_ id: UUID, supersede: @escaping @MainActor () -> Void) {
        let previous = holder
        holder = (id, supersede)
        previous?.supersede()
    }

    func release(_ id: UUID) {
        if holder?.id == id {
            holder = nil
        }
    }
}

/// One browser OAuth sign-in (Google or GitHub), from the tap to the callback: a fresh state and PKCE verifier per
/// attempt, one open sheet at a time, and a callback accepted only for the attempt that is still open, checked
/// against that attempt's own state.
@MainActor
public final class NativeBrowserOAuthSignIn {
    public struct Attempt: Equatable, Sendable {
        public let id: UUID
        public let provider: OAuthProviderHint
        public let state: OAuthState
        public let codeVerifier: String
        public let authorizationURL: URL
    }

    private let repository: NativeAuthSessionRepository
    private let gate: NativeBrowserOAuthGate
    private let makeSession: NativeBrowserOAuthWebSessionFactory
    private let randomSecret: @MainActor () -> String

    public private(set) var attempt: Attempt?
    private var session: (any NativeBrowserOAuthWebSession)?
    private var onFinish: (@MainActor (NativeBrowserOAuthFinish) -> Void)?
    private var onReturn: (@MainActor () -> Void)?
    private var isStarting = false
    private var isFinishing = false

    public init(
        repository: NativeAuthSessionRepository,
        gate: NativeBrowserOAuthGate = .shared,
        randomSecret: @escaping @MainActor () -> String = OAuthPKCE.randomVerifier,
        makeSession: @escaping NativeBrowserOAuthWebSessionFactory
    ) {
        self.repository = repository
        self.gate = gate
        self.randomSecret = randomSecret
        self.makeSession = makeSession
    }

    /// True from the tap until the attempt finishes, including the client registration before the sheet opens and
    /// the code exchange after it closes.
    public var isInProgress: Bool {
        isStarting || attempt != nil || isFinishing
    }

    /// Starts a new attempt with its own state and verifier, unless one is already in progress. `onReturn` is called
    /// when the sheet comes back with a callback, before the code exchange; `onFinish` is called once, when the
    /// attempt ends after it opened. A `cancel()` while the client registration is still in flight is not recorded:
    /// the app never cancels then.
    public func begin(
        provider: OAuthProviderHint,
        onReturn: @escaping @MainActor () -> Void = {},
        onFinish: @escaping @MainActor (NativeBrowserOAuthFinish) -> Void
    ) async -> NativeBrowserOAuthStart {
        guard !isInProgress else {
            return .alreadyInProgress
        }
        isStarting = true
        defer { isStarting = false }

        let codeVerifier = randomSecret()
        guard let state = OAuthState(rawValue: randomSecret()),
              let codeChallenge = try? OAuthPKCE.codeChallenge(for: codeVerifier),
              let start = try? await repository.startSignIn(
                  state: state,
                  codeChallenge: codeChallenge,
                  providerHint: provider
              ) else {
            return .couldNotOpen
        }

        let id = UUID()
        let session = makeSession(start.authorizationURL, start.redirectURI) { [weak self] callbackURL, _ in
            await self?.complete(attemptID: id, callbackURL: callbackURL)
        }
        attempt = Attempt(
            id: id,
            provider: provider,
            state: state,
            codeVerifier: codeVerifier,
            authorizationURL: start.authorizationURL
        )
        self.session = session
        self.onFinish = onFinish
        self.onReturn = onReturn
        // The gate is claimed after registration and before the sheet starts: the older sheet must close before this
        // one's server start replaces its state, even though this start may still fail. So the newest start to
        // finish registering wins, which is nearly always the newest tap.
        gate.claim(id) { [weak self] in
            self?.supersede(attemptID: id)
        }
        guard session.start() else {
            clear(attemptID: id)
            return .couldNotOpen
        }
        return .opened(authorizationURL: start.authorizationURL)
    }

    /// Closes the open sheet, if any, and ends its attempt as canceled.
    public func cancel() {
        guard let attempt else {
            return
        }
        let finish = onFinish
        session?.cancel()
        clear(attemptID: attempt.id)
        finish?(.canceled)
    }

    /// A callback (or a close without one) for `attemptID`. Anything but the open attempt is ignored, so a late
    /// callback from a closed or superseded sheet never reaches the token exchange.
    func complete(attemptID: UUID, callbackURL: URL?) async {
        guard let attempt, attempt.id == attemptID, let finish = onFinish else {
            return
        }
        let returned = onReturn
        clear(attemptID: attemptID)
        guard let callbackURL else {
            finish(.canceled)
            return
        }

        isFinishing = true
        defer { isFinishing = false }
        returned?()
        do {
            let session = try await repository.handleOAuthCallback(
                callbackURL,
                expectedState: attempt.state,
                codeVerifier: attempt.codeVerifier
            )
            finish(.signedIn(session))
        } catch {
            finish(.failed(error))
        }
    }

    private func supersede(attemptID: UUID) {
        // Only the gate calls this, while this attempt still holds it, so the attempt is always the open one.
        guard attempt?.id == attemptID else { return }
        let finish = onFinish
        session?.cancel()
        clear(attemptID: attemptID)
        finish?(.superseded)
    }

    private func clear(attemptID: UUID) {
        attempt = nil
        session = nil
        onFinish = nil
        onReturn = nil
        gate.release(attemptID)
    }
}
