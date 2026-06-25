import SpoonjoyCore
import SwiftUI

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

struct SpoonjoyRootView: View {
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
        case .syncFailed(let contentState, let message):
            platformNavigation(contentState: contentState)
                .safeAreaInset(edge: .bottom) {
                    Text(message)
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.tomato)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
        }
    }

    @ViewBuilder private func signedOutContent(contentState: NativeShellContentState) -> some View {
        if navigation.route == .settings {
            SettingsView(
                viewModel: contentState.settingsViewModel,
                onDismissOfflineIndicator: liveStore.dismissOfflineIndicator
            )
            .safeAreaInset(edge: .bottom) {
                OfflineStatusView(display: contentState.offlineIndicatorState.display, onDismiss: liveStore.dismissOfflineIndicator)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .background(KitchenTableTheme.bone.opacity(0.94))
            }
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
            .overlay(alignment: .bottomLeading) {
                OfflineStatusView(display: contentState.offlineIndicatorState.display, onDismiss: liveStore.dismissOfflineIndicator)
                    .padding()
            }
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
                Task {
                    await liveStore.queueMutation(mutation)
                }
            },
            syncTriggerCoordinator: liveStore.syncTriggerCoordinator
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
        let route = SpotlightIndexPlan.route(uniqueIdentifier: uniqueIdentifier)
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
        let configuration = APIClientConfiguration.spoonjoyProduction
        let vault = KeychainTokenVault()
        let authRepository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
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
            }
        )
        let appDirectory = NativeAppStateLocation.defaultFileURL().deletingLastPathComponent()
        let cacheStore = NativeDurableCacheStore(
            fileURL: appDirectory.appendingPathComponent("native-durable-cache.json")
        )
        let syncStore = Self.defaultSyncStore(appDirectory: appDirectory)
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
            cacheEnvironment: .production,
            now: Date.init
        )
    }

    private static func defaultSyncStore(appDirectory: URL) -> any NativeSyncStore {
        do {
            return try FileBackedNativeSyncStore(
                fileURL: appDirectory.appendingPathComponent("native-sync-store.json"),
                mediaResolver: NativeStagedMediaDirectory(
                    directoryURL: appDirectory.appendingPathComponent("native-staged-media", isDirectory: true)
                )
            )
        } catch {
            return UnavailableNativeSyncStore(message: "Could not open Spoonjoy sync store: \(error)")
        }
    }
}

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
