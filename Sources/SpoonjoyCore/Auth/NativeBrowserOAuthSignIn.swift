import Foundation

/// The system browser sheet a browser sign-in runs in (ASWebAuthenticationSession in the app, a fake in tests).
@MainActor
public protocol NativeBrowserOAuthWebSession: AnyObject {
    /// Shows the sheet; false when the system refused to.
    func start() -> Bool
    func cancel()
    /// True once anything the system shows for this session has appeared since `start()`: on iOS the "wants to use
    /// spoonjoy.app to sign in" prompt, which always comes before the sheet and makes the app resign active. A cancel
    /// after that came from the person, never from the system.
    var systemUIAppeared: Bool { get }
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

/// Why a start returned `.couldNotOpen`, for the app's log.
public enum NativeBrowserOAuthStartFailure: Error, Equatable, Sendable {
    /// The random state or verifier was not usable.
    case invalidSecret
    /// The system would not show the sheet.
    case sheetRefused
}

public enum NativeBrowserOAuthFinish: Sendable {
    case signedIn(AuthSession)
    case failed(any Error)
    /// The sheet closed without a callback: the sheet's error (ASWebAuthenticationSessionError and its code), or nil
    /// when the app closed it.
    case canceled((any Error)?)
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
    private let uptime: @MainActor () -> TimeInterval
    private let pause: @MainActor (Duration) async -> Void
    private let log: @MainActor (String) -> Void

    public private(set) var attempt: Attempt?
    /// Why the last `begin` returned `.couldNotOpen`: a `NativeBrowserOAuthStartFailure`, or the registration's own
    /// error. Nil after a start that opened or was refused as already in progress.
    public private(set) var startFailure: (any Error)?
    private var session: (any NativeBrowserOAuthWebSession)?
    private var onFinish: (@MainActor (NativeBrowserOAuthFinish) -> Void)?
    private var onReturn: (@MainActor () -> Void)?
    private var isStarting = false
    private var isFinishing = false
    private var redirectURI: URL?
    private var sessionStartedAt: TimeInterval?
    private var retriedAttemptID: UUID?
    /// The pause before an early-cancel retry. It holds this object weakly, so a view torn down mid-pause opens no sheet.
    private(set) var retryTask: Task<Void, Never>?

    /// A cancel this soon after `start()`, with nothing shown, came from the system, not the person.
    public static let earlyCancelWindow = NativeBrowserOAuthEarlyCancel.window
    public static let earlyCancelRetryDelay = NativeBrowserOAuthEarlyCancel.retryDelay

    public init(
        repository: NativeAuthSessionRepository,
        gate: NativeBrowserOAuthGate = .shared,
        randomSecret: @escaping @MainActor () -> String = OAuthPKCE.randomVerifier,
        uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        pause: @escaping @MainActor (Duration) async -> Void = { try? await Task.sleep(for: $0) },
        log: @escaping @MainActor (String) -> Void = { _ in },
        makeSession: @escaping NativeBrowserOAuthWebSessionFactory
    ) {
        self.repository = repository
        self.gate = gate
        self.randomSecret = randomSecret
        self.uptime = uptime
        self.pause = pause
        self.log = log
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
    /// the app never cancels then. With `sendsProviderHint` false, /oauth/authorize gets no provider
    /// hint and shows spoonjoy.app/login (BrowserSignInCallbackUITests, Debug builds only).
    public func begin(
        provider: OAuthProviderHint,
        sendsProviderHint: Bool = true,
        onReturn: @escaping @MainActor () -> Void = {},
        onFinish: @escaping @MainActor (NativeBrowserOAuthFinish) -> Void
    ) async -> NativeBrowserOAuthStart {
        startFailure = nil
        guard !isInProgress else {
            return .alreadyInProgress
        }
        isStarting = true
        defer { isStarting = false }

        let codeVerifier = randomSecret()
        guard let state = OAuthState(rawValue: randomSecret()),
              let codeChallenge = try? OAuthPKCE.codeChallenge(for: codeVerifier) else {
            startFailure = NativeBrowserOAuthStartFailure.invalidSecret
            return .couldNotOpen
        }
        let start: NativeAuthSignInStart
        do {
            start = try await repository.startSignIn(
                state: state,
                codeChallenge: codeChallenge,
                providerHint: sendsProviderHint ? provider : nil
            )
        } catch {
            startFailure = error
            return .couldNotOpen
        }

        let id = UUID()
        let session = makeSheet(attemptID: id, authorizationURL: start.authorizationURL, redirectURI: start.redirectURI)
        redirectURI = start.redirectURI
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
            startFailure = NativeBrowserOAuthStartFailure.sheetRefused
            return .couldNotOpen
        }
        sessionStartedAt = uptime()
        log(NativeBrowserOAuthEarlyCancel.startedMessage)
        return .opened(authorizationURL: start.authorizationURL)
    }

    /// The launch environment variable that asks a Debug build to start browser sign-in without the provider hint, so
    /// the sheet shows spoonjoy.app/login (BrowserSignInCallbackUITests). The app checks it in Debug builds only.
    public static let loginPageEnvironmentVariable = "SPOONJOY_UI_TEST_BROWSER_SIGN_IN_LOGIN_PAGE"

    public static func loginPageRequested(environment: [String: String]) -> Bool {
        environment[loginPageEnvironmentVariable] == "1"
    }

    /// A start failure or a sheet's cancel error for the log; see `NativeBrowserOAuthEarlyCancel.diagnosticReason`.
    public static func diagnosticReason(_ error: any Error) -> String {
        NativeBrowserOAuthEarlyCancel.diagnosticReason(error)
    }

    /// Closes the open sheet, if any, and ends its attempt as canceled.
    public func cancel() {
        guard let attempt else {
            return
        }
        let finish = onFinish
        session?.cancel()
        clear(attemptID: attempt.id)
        finish?(.canceled(nil))
    }

    /// A callback (or a close without one) for `attemptID`. Anything but the open attempt is ignored, so a late
    /// callback from a closed or superseded sheet never reaches the token exchange.
    func complete(attemptID: UUID, callbackURL: URL?, error: (any Error)? = nil) async {
        guard let attempt, attempt.id == attemptID, let finish = onFinish else {
            return
        }
        guard let callbackURL else {
            let elapsed = sessionStartedAt.map { uptime() - $0 }
            let systemUIAppeared = session?.systemUIAppeared ?? true
            if NativeBrowserOAuthEarlyCancel.shouldRetry(
                error: error,
                secondsSinceStart: elapsed,
                systemUIAppeared: systemUIAppeared,
                alreadyRetried: retriedAttemptID == attemptID
            ) {
                retriedAttemptID = attemptID
                log(NativeBrowserOAuthEarlyCancel.earlyCancelMessage(error: error, secondsSinceStart: elapsed))
                scheduleRetry(attemptID: attemptID, error: error)
                return
            }
            log(NativeBrowserOAuthEarlyCancel.endedMessage(
                error: error,
                secondsSinceStart: elapsed,
                systemUIAppeared: systemUIAppeared
            ))
            clear(attemptID: attemptID)
            finish(.canceled(error))
            return
        }
        let returned = onReturn
        clear(attemptID: attemptID)
        log(NativeBrowserOAuthEarlyCancel.callbackMessage)

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

    /// Starts one fresh sheet for the same attempt after a short pause. A cancel, a newer start or a callback during
    /// the pause wins: the retry only runs while this attempt is still the open one. The pause holds this object
    /// weakly, so if its owner goes away meanwhile, no sheet opens.
    private func scheduleRetry(attemptID: UUID, error: (any Error)?) {
        session = nil
        sessionStartedAt = nil
        retryTask = Task { [weak self, pause] in
            await pause(Self.earlyCancelRetryDelay)
            self?.resumeRetry(attemptID: attemptID, error: error)
        }
    }

    private func resumeRetry(attemptID: UUID, error: (any Error)?) {
        guard let attempt, attempt.id == attemptID, let redirectURI, let finish = onFinish else {
            return
        }
        let sheet = makeSheet(attemptID: attempt.id, authorizationURL: attempt.authorizationURL, redirectURI: redirectURI)
        session = sheet
        guard sheet.start() else {
            log(NativeBrowserOAuthEarlyCancel.retryDidNotStartMessage)
            clear(attemptID: attempt.id)
            finish(.canceled(error))
            return
        }
        sessionStartedAt = uptime()
        log(NativeBrowserOAuthEarlyCancel.retriedMessage)
    }

    private func makeSheet(attemptID: UUID, authorizationURL: URL, redirectURI: URL) -> any NativeBrowserOAuthWebSession {
        makeSession(authorizationURL, redirectURI) { [weak self] callbackURL, error in
            await self?.complete(attemptID: attemptID, callbackURL: callbackURL, error: error)
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
        sessionStartedAt = nil
        redirectURI = nil
        onFinish = nil
        onReturn = nil
        gate.release(attemptID)
    }
}
