import SpoonjoyCore
import SwiftUI
import OSLog

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

struct SpoonjoyRootView: View {
    private static let appleSignInLogger = Logger(subsystem: "app.spoonjoy", category: "auth.apple")

    @State private var navigation = AppNavigationState()
    @State private var search = SearchState()
    @State private var hasAppliedRestoredRoute = false
    @StateObject private var liveStore: NativeLiveAppStore

    private let router: DeepLinkRouter

    init(
        router: DeepLinkRouter = .spoonjoy,
        liveStore: NativeLiveAppStore = NativeLiveAppStore(dependencies: Self.defaultDependencies())
    ) {
        self.router = router
        _liveStore = StateObject(wrappedValue: liveStore)
    }

    var body: some View {
        rootContent
            .task {
                await liveStore.bootstrap()
                applyRestoredRouteIfNeeded()
            }
            .onOpenURL { url in
                applyURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                if let url = userActivity.webpageURL {
                    applyURL(url)
                }
            }
#if canImport(CoreSpotlight)
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    applySpotlightIdentifier(uniqueIdentifier)
                }
            }
#endif
    }

    @ViewBuilder private var rootContent: some View {
        switch liveStore.bootstrapState {
        case .signedOut(let contentState):
            signedOutContent(contentState: contentState)
        case .restoringCache(let contentState):
            restoringCacheView(contentState: contentState)
        case .liveSynced(let contentState):
            platformNavigation(contentState: contentState)
        case .offlineStale(let contentState):
            platformNavigation(contentState: contentState)
        case .queuedWork(let contentState):
            platformNavigation(contentState: contentState)
        case .conflict(let contentState):
            platformNavigation(contentState: contentState)
        case .blocker(let contentState):
            platformNavigation(contentState: contentState)
        case .destructiveConfirmation(let contentState):
            platformNavigation(contentState: contentState)
        case .syncFailed(let contentState, _):
            platformNavigation(contentState: contentState)
        }
    }

    @ViewBuilder private func signedOutContent(contentState: NativeShellContentState) -> some View {
        if navigation.route == .settings {
            SettingsView(
                viewModel: contentState.settingsViewModel,
                settingsSurfaceViewModel: contentState.settingsSurfaceViewModel,
                shellOfflineIndicatorState: contentState.offlineIndicatorState,
                onDismissOfflineIndicator: liveStore.dismissOfflineIndicator
            )
        } else {
            SignedOutSetupView(
                authRepository: liveStore.authSessionRepository,
                pendingRoute: navigation.route,
                openSettings: { navigation.navigate(to: .settings) },
                onSignedIn: {
                    await liveStore.bootstrap()
                    applyRestoredRouteIfNeeded()
                }
            )
        }
    }

    private func platformNavigation(contentState: NativeShellContentState) -> some View {
        PlatformNavigationView(
            navigation: $navigation,
            search: $search,
            contentState: contentState,
            offlineIndicatorState: liveStore.offlineIndicatorState,
            dismissOfflineIndicator: liveStore.dismissOfflineIndicator,
            queueMutation: { mutation in
                try await liveStore.queueMutation(mutation)
            },
            queueMutations: { mutations, drainImmediately in
                try await liveStore.queueMutations(mutations, drainImmediately: drainImmediately)
            },
            discardQueuedMutation: { clientMutationID in
                try await liveStore.discardQueuedMutation(clientMutationID: clientMutationID)
            },
            executeRecipeEditorRequest: { request in
                try await liveStore.executeRecipeEditorRequest(request)
            },
            executeSettingsActionRequest: { request, responseHandling in
                try await liveStore.executeSettingsActionRequest(request, responseHandling: responseHandling)
            },
            executeCaptureImportRequest: { request in
                try await liveStore.executeCaptureImportRequest(request)
            },
            performSettingsSessionOperation: { operation in
                try await liveStore.performSettingsSessionOperation(operation)
            },
            requestNotificationPermission: {
                try await NotificationAPNsDeviceBridge.shared.requestPermission()
            },
            requestDeviceRegistrationAction: { clientMutationID in
                try await NotificationAPNsDeviceBridge.shared.registrationAction(clientMutationID: clientMutationID)
            },
            openNotificationSettings: {
                NotificationAPNsDeviceBridge.shared.openNotificationSettings()
            },
            recordNotificationAPNsBlocker: liveStore.recordNotificationAPNsBlocker,
            recordShoppingList: liveStore.recordShoppingList,
            recordCookProgress: liveStore.recordCookProgress,
            recordCaptureDraft: liveStore.recordCaptureDraft,
            discardCaptureDraft: liveStore.discardCaptureDraft,
            recordCaptureImportRetry: liveStore.recordCaptureImportRetry,
            recordCaptureImportBlocker: liveStore.recordCaptureImportBlocker,
            recordSpoonCookLogDraft: liveStore.recordSpoonCookLogDraft,
            recordSearchSurfacePage: { page, identity in
                try liveStore.recordSearchSurfacePage(page, expectedIdentity: identity)
            },
            searchSurfaceRepository: { context in
                liveStore.searchSurfaceRepository(context: context)
            },
            syncTriggerCoordinator: liveStore.syncTriggerCoordinator,
            purgeShoppingEntityIndexes: { request in
                await liveStore.purgeShoppingEntityIdentifiers(
                    request.identifiers,
                    domainIdentifiers: request.domainIdentifiers,
                    accountID: request.accountID,
                    environment: request.environment
                )
            },
            purgeSpoonEntityIndexes: { request in
                await liveStore.purgeSpoonEntityIdentifiers(
                    request.identifiers,
                    domainIdentifiers: request.domainIdentifiers,
                    accountID: request.accountID,
                    environment: request.environment
                )
            },
            purgeCaptureDraftEntityIndexes: { request in
                await liveStore.purgeCaptureDraftEntityIdentifiers(
                    request.identifiers,
                    domainIdentifiers: request.domainIdentifiers,
                    accountID: request.accountID,
                    environment: request.environment
                )
            },
            purgeChefProfileEntityIndexes: { request in
                await liveStore.purgeChefProfileEntityIdentifiers(
                    request.identifiers,
                    domainIdentifiers: request.domainIdentifiers,
                    accountID: request.accountID,
                    environment: request.environment
                )
            },
            purgeRecipeCookbookEntityIndexes: { request in
                await liveStore.purgeRecipeCookbookEntityIdentifiers(
                    request.identifiers,
                    domainIdentifiers: request.domainIdentifiers,
                    accountID: request.accountID,
                    environment: request.environment
                )
            }
        )
    }

    private func restoringCacheView(contentState: NativeShellContentState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
            Text("Restoring Spoonjoy")
                .font(.headline)
            OfflineStatusView(display: contentState.offlineIndicatorState.display, onDismiss: liveStore.dismissOfflineIndicator)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .background(KitchenTableTheme.bone)
    }

    private func applyURL(_ url: URL) {
        let route = router.route(for: url)
        search.apply(route: route)
        navigation.navigate(to: route)
        liveStore.recordingOpenedRoute(route)
    }

    private func applySpotlightIdentifier(_ uniqueIdentifier: String) {
        let route: AppRoute
        if let scope = liveStore.bootstrapState.contentState.spotlightIndexScope {
            route = SpotlightIndexPlan.route(uniqueIdentifier: uniqueIdentifier, scope: scope)
        } else {
            route = .unknownLink
        }
        search.apply(route: route)
        navigation.navigate(to: route)
        liveStore.recordingOpenedRoute(route)
    }

    private func applyRestoredRouteIfNeeded() {
        guard !hasAppliedRestoredRoute,
              navigation.route == .kitchen,
              let route = liveStore.restoredRoute else {
            return
        }

        hasAppliedRestoredRoute = true
        search.apply(route: route)
        navigation.navigate(to: route)
    }

    private static func defaultDependencies() -> NativeLiveAppStoreDependencies {
        let environment = ProcessInfo.processInfo.environment
        let configuration = Self.defaultAPIConfiguration(environment: environment)
        let appDirectory = NativeAppStateLocation.defaultFileURL().deletingLastPathComponent()
#if DEBUG
        let vault: any TokenVault = screenshotValidationTokenVault(environment: environment) ?? debugTokenVault(
            environment: environment,
            appDirectory: appDirectory
        )
        let bootstrapMode: NativeLiveAppBootstrapMode = screenshotRestoreCacheOnlyEnabled(environment: environment)
            ? .restoreCacheOnly
            : .liveFirst
#else
        let vault: any TokenVault = KeychainTokenVault()
        let bootstrapMode: NativeLiveAppBootstrapMode = .liveFirst
#endif
        let authRepository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            redirectURI: Self.defaultOAuthRedirectURI(environment: environment),
            registerClient: { clientName, redirectURI in
                let response: OAuthRegisterResponse = try await OAuthURLSessionSupport.sendDecoded(
                    try OAuthRequests.registerClient(clientName: clientName, redirectURIs: [redirectURI]),
                    configuration: configuration
                )
                return response.clientID
            },
            exchangeCode: { clientID, redirectURI, code, verifier in
                try await OAuthURLSessionSupport.sendDecoded(
                    try OAuthRequests.exchangeCode(
                        clientID: clientID,
                        redirectURI: redirectURI,
                        code: code,
                        codeVerifier: verifier
                    ),
                    configuration: configuration
                )
            },
            exchangeAppleCredential: { credential in
                Self.appleSignInLogger.info("phase=backend_request_started")
                do {
                    let response: OAuthTokenResponse = try await OAuthURLSessionSupport.sendDecoded(
                        try NativeAppleSignInRequests.exchangeCredential(credential),
                        configuration: configuration
                    )
                    Self.appleSignInLogger.info("phase=backend_request_succeeded")
                    return response
                } catch {
                    Self.appleSignInLogger.error("phase=backend_request_failed error_code=\(Self.nativeAppleExchangeDiagnosticCode(for: error), privacy: .public)")
                    throw error
                }
            },
            exchangePasswordCredential: { credential in
                try await OAuthURLSessionSupport.sendDecoded(
                    try NativePasswordSignInRequests.exchangeCredential(credential),
                    configuration: configuration
                )
            },
            refresh: { clientID, refreshToken in
                try await OAuthURLSessionSupport.sendDecoded(
                    OAuthRequests.refreshToken(clientID: clientID, refreshToken: refreshToken),
                    configuration: configuration
                )
            },
            revoke: { refreshToken, clientID in
                _ = try await OAuthURLSessionSupport.send(
                    OAuthRequests.revoke(refreshToken: refreshToken, clientID: clientID),
                    configuration: configuration
                )
            },
            reusesSavedClientID: Self.reusesSavedOAuthClientID(environment: environment)
        )
        let cacheStore = NativeDurableCacheStore(
            fileURL: appDirectory.appendingPathComponent("native-durable-cache.json")
        )
        let stagedMediaDirectory = NativeStagedMediaDirectory(
            directoryURL: appDirectory.appendingPathComponent("native-staged-media", isDirectory: true)
        )
        let syncStore = Self.defaultSyncStore(
            appDirectory: appDirectory,
            mediaResolver: stagedMediaDirectory
        )
        let syncEngine = NativeSyncEngine(store: syncStore, transport: URLSessionNativeSyncTransport())
        let syncTriggerCoordinator = NativeSyncTriggerCoordinator(runner: syncEngine, configuration: configuration)
        return NativeLiveAppStoreDependencies(
            authSessionRepository: authRepository,
            cacheStore: cacheStore,
            syncStore: syncStore,
            syncEngine: syncEngine,
            syncTriggerCoordinator: syncTriggerCoordinator,
            appStateStoreProvider: {
                NativeAppStateStore(fileURL: NativeAppStateLocation.defaultFileURL())
            },
            configuration: configuration,
            cacheEnvironment: Self.defaultCacheEnvironment(configuration: configuration),
            settingsSurfaceFetch: { accountID, environment, configuration, cache in
                try await LiveSettingsSurfaceRepository(
                    cache: cache,
                    configuration: configuration
                ).fetchSettingsSurface(accountID: accountID, environment: environment)
            },
            stagedMediaDirectory: stagedMediaDirectory,
            shoppingEntityIndexPurge: { request in
                await Self.purgeShoppingEntityIdentifiersIfAvailable(request)
            },
            spoonEntityIndexPurge: { request in
                await Self.purgeSpoonEntityIdentifiersIfAvailable(request)
            },
            captureDraftEntityIndexPurge: { request in
                await Self.purgeCaptureDraftEntityIdentifiersIfAvailable(request)
            },
            chefProfileEntityIndexPurge: { request in
                await Self.purgeChefProfileEntityIdentifiersIfAvailable(request)
            },
            recipeCookbookEntityIndexPurge: { request in
                await Self.purgeRecipeCookbookEntityIdentifiersIfAvailable(request)
            },
            bootstrapMode: bootstrapMode,
            now: Date.init
        )
    }

    private static func nativeAppleExchangeDiagnosticCode(for error: Error) -> String {
        if let transportError = error as? APITransportError {
            if let providerCode = providerCode(from: transportError.apiError) {
                return "provider_\(providerCode)"
            }
            if let apiError = transportError.apiError {
                return "api_\(apiError.code)_\(apiError.status)"
            }
            if let statusCode = transportError.statusCode {
                return "http_\(statusCode)"
            }
            return "transport_\(String(describing: transportError.kind))"
        }
        return "unexpected_\(String(describing: type(of: error)))"
    }

    private static func providerCode(from apiError: APIError?) -> String? {
        guard let providerCode = apiError?.details["providerCode"],
              case .string(let value) = providerCode,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func defaultAPIConfiguration(environment: [String: String]) -> APIClientConfiguration {
#if DEBUG
        if let rawURL = environment["SPOONJOY_API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawURL.isEmpty,
           let baseURL = URL(string: rawURL) {
            return APIClientConfiguration(baseURL: baseURL)
        }
#endif
        return .spoonjoyProduction
    }

    private static func defaultOAuthRedirectURI(environment: [String: String]) -> URL {
#if os(macOS) && DEBUG
        if environment["SPOONJOY_FORCE_HTTPS_OAUTH"] == "1" {
            return NativeAuthSession.redirectURI
        }
        return NativeAuthSession.localDogfoodRedirectURI
#else
        return NativeAuthSession.redirectURI
#endif
    }

    private static func defaultCacheEnvironment(configuration: APIClientConfiguration) -> NativeCacheEnvironment {
        let host = configuration.baseURL.host(percentEncoded: false)?.lowercased() ?? ""
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return .local
        }
        if host == "spoonjoy.app" || host == "www.spoonjoy.app" {
            return .production
        }
        return .preview(host: host)
    }

    private static func reusesSavedOAuthClientID(environment: [String: String]) -> Bool {
#if os(macOS) && DEBUG
        environment["SPOONJOY_FORCE_HTTPS_OAUTH"] == "1"
#else
        true
#endif
    }

    private static func purgeShoppingEntityIdentifiersIfAvailable(_ request: NativeShoppingEntityIndexPurgeRequest) async {
#if canImport(CoreSpotlight)
        if #available(iOS 27.0, macOS 27.0, *) {
            try? await SpoonjoySpotlightIndexer().delete(
                identifiers: request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
#endif
    }

    private static func purgeSpoonEntityIdentifiersIfAvailable(_ request: NativeSpoonEntityIndexPurgeRequest) async {
#if canImport(CoreSpotlight)
        if #available(iOS 27.0, macOS 27.0, *) {
            try? await SpoonjoySpotlightIndexer().delete(
                identifiers: request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
#endif
    }

    private static func purgeCaptureDraftEntityIdentifiersIfAvailable(_ request: NativeCaptureDraftEntityIndexPurgeRequest) async {
#if canImport(CoreSpotlight)
        if #available(iOS 27.0, macOS 27.0, *) {
            try? await SpoonjoySpotlightIndexer().delete(
                identifiers: request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
#endif
    }

    private static func purgeChefProfileEntityIdentifiersIfAvailable(_ request: NativeChefProfileEntityIndexPurgeRequest) async {
#if canImport(CoreSpotlight)
        if #available(iOS 27.0, macOS 27.0, *) {
            try? await SpoonjoySpotlightIndexer().delete(
                identifiers: request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
#endif
    }

    private static func purgeRecipeCookbookEntityIdentifiersIfAvailable(_ request: NativeRecipeCookbookEntityIndexPurgeRequest) async {
#if canImport(CoreSpotlight)
        if #available(iOS 27.0, macOS 27.0, *) {
            try? await SpoonjoySpotlightIndexer().delete(
                identifiers: request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
#endif
    }

#if DEBUG
    private static func screenshotValidationTokenVault(environment: [String: String]) -> (any TokenVault)? {
        guard truthy("SPOONJOY_SCREENSHOT_AUTH", in: environment) else {
            return nil
        }
        let accountID = environment["SPOONJOY_SCREENSHOT_ACCOUNT_ID"] ?? "chef_settings_capture"
        guard let session = try? AuthSession(
            clientID: "cm_screenshot_validation",
            accessToken: "screenshot_access_token",
            refreshToken: "screenshot_refresh_token",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000),
            scope: NativeAuthSession.defaultScope,
            accountID: accountID
        ) else {
            return nil
        }
        return SpoonjoyScreenshotValidationTokenVault(
            clientID: "cm_screenshot_validation",
            session: session
        )
    }

    private static func screenshotRestoreCacheOnlyEnabled(environment: [String: String]) -> Bool {
        truthy("SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY", in: environment)
    }

    private static func debugTokenVault(environment: [String: String], appDirectory: URL) -> any TokenVault {
        if truthy("SPOONJOY_DEBUG_KEYCHAIN_AUTH", in: environment) {
            return KeychainTokenVault(allowsUnsignedLocalFallback: true)
        }
        return FileBackedTokenVault(fileURL: appDirectory.appendingPathComponent("debug-auth-session.json"))
    }

    private static func truthy(_ key: String, in environment: [String: String]) -> Bool {
        switch environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            true
        default:
            false
        }
    }
#endif

    private static func defaultSyncStore(
        appDirectory: URL,
        mediaResolver: NativeStagedMediaDirectory
    ) -> any NativeSyncStore {
        do {
            return try FileBackedNativeSyncStore(
                fileURL: appDirectory.appendingPathComponent("native-sync-store.json"),
                mediaResolver: mediaResolver
            )
        } catch {
            return UnavailableNativeSyncStore(message: "Could not open Spoonjoy sync store: \(error)")
        }
    }
}

#if DEBUG
private actor SpoonjoyScreenshotValidationTokenVault: TokenVault {
    private var clientID: String?
    private var session: AuthSession?

    init(clientID: String, session: AuthSession) {
        self.clientID = clientID
        self.session = session
    }

    func loadClientID() async throws -> String? {
        clientID
    }

    func saveClientID(_ clientID: String) async throws {
        self.clientID = clientID
    }

    func clearClientID() async throws {
        clientID = nil
    }

    func loadSession() async throws -> AuthSession? {
        session
    }

    func saveSession(_ session: AuthSession) async throws {
        self.session = session
    }

    func clearSession() async throws {
        session = nil
    }
}
#endif

private enum OAuthURLSessionSupport {
    static func sendDecoded<Value: Decodable & Equatable>(
        _ builder: APIRequestBuilder,
        configuration: APIClientConfiguration
    ) async throws -> Value {
        let data = try await send(builder, configuration: configuration)
        if let envelope = try? APIEnvelope<Value>.decode(data) {
            return envelope.data
        }

        return try JSONDecoder().decode(Value.self, from: data)
    }

    static func send(_ builder: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> Data {
        let request = try builder.urlRequest(configuration: configuration)
        guard let url = url(from: request.url, queryItems: request.queryItems) else {
            throw URLError(.badURL)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APITransportError(
                kind: .nonHTTPResponse,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw httpError(data: data, response: httpResponse)
        }

        if !data.isEmpty && !isJSONResponse(httpResponse) {
            throw APITransportError(
                kind: .nonJSONResponse,
                requestID: requestID(from: httpResponse),
                statusCode: httpResponse.statusCode,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }
        return data
    }

    private static func url(from requestURL: APIRequestURL, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: requestURL.baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = requestURL.path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

    private static func httpError(data: Data, response: HTTPURLResponse) -> APITransportError {
        let retryAfterSeconds = retryAfterSeconds(from: response)
        let apiError: APIError
        if isJSONResponse(response),
           let decoded = try? APIEnvelope<JSONValue>.decodeResult(data),
           case .failure(let decodedError) = decoded {
            apiError = APIError(
                requestID: decodedError.requestID,
                code: decodedError.code,
                message: decodedError.message,
                status: decodedError.status,
                retryAfterSeconds: retryAfterSeconds ?? decodedError.retryAfterSeconds,
                details: decodedError.details
            )
        } else {
            apiError = APIError(
                requestID: requestID(from: response) ?? "unknown",
                code: "oauth_http_status_\(response.statusCode)",
                message: "OAuth request failed with HTTP \(response.statusCode).",
                status: response.statusCode,
                retryAfterSeconds: retryAfterSeconds
            )
        }

        return APITransportError(
            kind: isJSONResponse(response) ? .apiError : .nonJSONResponse,
            requestID: apiError.requestID,
            statusCode: response.statusCode,
            apiError: apiError,
            retryDecision: APIRetryPolicy.decision(for: apiError)
        )
    }

    private static func isJSONResponse(_ response: HTTPURLResponse) -> Bool {
        guard let contentType = headerValue("Content-Type", in: response) else {
            return false
        }
        let lowercased = contentType.lowercased()
        return lowercased.contains("application/json") || lowercased.contains("+json")
    }

    private static func requestID(from response: HTTPURLResponse) -> String? {
        headerValue("X-Request-Id", in: response)
    }

    private static func retryAfterSeconds(from response: HTTPURLResponse) -> Int? {
        guard let value = headerValue("Retry-After", in: response)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return Int(value).flatMap { $0 >= 0 ? $0 : nil }
    }

    private static func headerValue(_ name: String, in response: HTTPURLResponse) -> String? {
        let lowercasedName = name.lowercased()
        for (key, value) in response.allHeaderFields {
            guard String(describing: key).lowercased() == lowercasedName else {
                continue
            }
            return String(describing: value)
        }
        return nil
    }
}
