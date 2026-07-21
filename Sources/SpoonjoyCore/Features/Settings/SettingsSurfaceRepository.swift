import Foundation

public enum SettingsAuthProvider: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case google
    case github
    case apple
}

public struct SettingsLinkedProvider: Codable, Equatable, Hashable, Sendable {
    public let provider: SettingsAuthProvider
    public let providerUsername: String?

    public init(provider: SettingsAuthProvider, providerUsername: String?) {
        self.provider = provider
        self.providerUsername = providerUsername
    }
}

public struct SettingsPasskeySummary: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let transports: String?
    public let createdAt: String?

    public init(id: String, name: String, transports: String?, createdAt: String?) {
        self.id = id
        self.name = name
        self.transports = transports
        self.createdAt = createdAt
    }
}

public struct SettingsAccountProfile: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let email: String
    public let username: String
    public let photoURL: URL?
    public let hasPassword: Bool
    public let linkedProviders: [SettingsLinkedProvider]
    public let passkeys: [SettingsPasskeySummary]

    public init(
        id: String,
        email: String,
        username: String,
        photoURL: URL?,
        hasPassword: Bool,
        linkedProviders: [SettingsLinkedProvider],
        passkeys: [SettingsPasskeySummary]
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.photoURL = photoURL
        self.hasPassword = hasPassword
        self.linkedProviders = linkedProviders
        self.passkeys = passkeys
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case photoURL = "photoUrl"
        case hasPassword
        case linkedProviders = "oauthAccounts"
        case passkeys
    }
}

public struct SettingsNotificationPreferences: Codable, Equatable, Hashable, Sendable {
    public let notifySpoonOnMyRecipe: Bool
    public let notifyForkOfMyRecipe: Bool
    public let notifyCookbookSaveOfMine: Bool
    public let notifyFellowChefOriginCook: Bool

    public init(
        notifySpoonOnMyRecipe: Bool,
        notifyForkOfMyRecipe: Bool,
        notifyCookbookSaveOfMine: Bool,
        notifyFellowChefOriginCook: Bool
    ) {
        self.notifySpoonOnMyRecipe = notifySpoonOnMyRecipe
        self.notifyForkOfMyRecipe = notifyForkOfMyRecipe
        self.notifyCookbookSaveOfMine = notifyCookbookSaveOfMine
        self.notifyFellowChefOriginCook = notifyFellowChefOriginCook
    }

    public static let disabled = SettingsNotificationPreferences(
        notifySpoonOnMyRecipe: false,
        notifyForkOfMyRecipe: false,
        notifyCookbookSaveOfMine: false,
        notifyFellowChefOriginCook: false
    )
}

public struct SettingsAPITokenSummary: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let tokenPrefix: String
    public let scopes: [String]
    public let createdAt: String
    public let updatedAt: String
    public let lastUsedAt: String?
    public let revokedAt: String?
    public let expiresAt: String?

    public var revealedSecret: String? { nil }

    public var displayIdentifier: String {
        guard let component = tokenPrefix.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).last,
              component.count >= 4 else {
            return "Access key"
        }
        return "Key ID \(component.suffix(4))"
    }

    public init(
        id: String,
        name: String,
        tokenPrefix: String,
        scopes: [String],
        createdAt: String,
        updatedAt: String,
        lastUsedAt: String?,
        revokedAt: String?,
        expiresAt: String?
    ) {
        self.id = id
        self.name = name
        self.tokenPrefix = tokenPrefix
        self.scopes = scopes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.revokedAt = revokedAt
        self.expiresAt = expiresAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tokenPrefix
        case scopes
        case createdAt
        case updatedAt
        case lastUsedAt
        case revokedAt
        case expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tokenPrefix = try container.decode(String.self, forKey: .tokenPrefix)
        scopes = try container.decodeIfPresent([String].self, forKey: .scopes) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
        lastUsedAt = try container.decodeIfPresent(String.self, forKey: .lastUsedAt)
        revokedAt = try container.decodeIfPresent(String.self, forKey: .revokedAt)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
    }
}

public struct SettingsAPITokenListResponse: Decodable, Equatable, Sendable {
    public let tokens: [SettingsAPITokenSummary]

    public init(tokens: [SettingsAPITokenSummary]) {
        self.tokens = tokens
    }

    private enum CodingKeys: String, CodingKey {
        case tokens
        case credentials
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try container.decodeIfPresent([SettingsAPITokenSummary].self, forKey: .tokens)
            ?? container.decodeIfPresent([SettingsAPITokenSummary].self, forKey: .credentials)
            ?? []
    }
}

public struct SettingsCreatedAPIToken: Decodable, Equatable, Sendable {
    public let token: String
    public let credential: SettingsAPITokenSummary

    public init(token: String, credential: SettingsAPITokenSummary) {
        self.token = token
        self.credential = credential
    }
}

public struct SettingsOAuthConnectionSummary: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let clientID: String
    public let clientName: String
    public let resource: String?
    public let scopes: [String]
    public let createdAt: String
    public let refreshTokenCount: Int
    public let accessTokenCount: Int

    public init(
        id: String,
        clientID: String,
        clientName: String,
        resource: String?,
        scopes: [String],
        createdAt: String,
        refreshTokenCount: Int,
        accessTokenCount: Int
    ) {
        self.id = id
        self.clientID = clientID
        self.clientName = clientName
        self.resource = resource
        self.scopes = scopes
        self.createdAt = createdAt
        self.refreshTokenCount = refreshTokenCount
        self.accessTokenCount = accessTokenCount
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case clientID = "clientId"
        case clientName
        case resource
        case scopes
        case createdAt
        case refreshTokenCount
        case accessTokenCount
    }
}

public struct SettingsOAuthConnectionListResponse: Decodable, Equatable, Sendable {
    public let connections: [SettingsOAuthConnectionSummary]

    public init(connections: [SettingsOAuthConnectionSummary]) {
        self.connections = connections
    }

    private enum CodingKeys: String, CodingKey {
        case connections
        case oauthConnections
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        connections = try container.decodeIfPresent([SettingsOAuthConnectionSummary].self, forKey: .connections)
            ?? container.decodeIfPresent([SettingsOAuthConnectionSummary].self, forKey: .oauthConnections)
            ?? []
    }
}

public enum SettingsSurfaceDataSource: Equatable, Sendable {
    case live(requestID: String, validatedAt: Date)
    case cache(lastValidatedAt: Date)
}

public enum SettingsTokenManagementAvailability: Equatable, Sendable {
    case available
    case unavailableMissingScope
}

public enum SettingsSurfaceComponent: String, Equatable, Hashable, Sendable {
    case notificationPreferences = "notification_preferences"
    case apiTokens = "api_tokens"
    case oauthConnections = "oauth_connections"

    public var userFacingName: String {
        switch self {
        case .notificationPreferences:
            "Notifications"
        case .apiTokens:
            "Agent access"
        case .oauthConnections:
            "Connections"
        }
    }
}

public struct SettingsSurfaceFailureDiagnostic: Equatable, Sendable {
    public let errorType: String
    public let requestID: String?
    public let status: Int?
    public let apiCode: String?
    public let retry: String?

    public init(
        errorType: String,
        requestID: String?,
        status: Int?,
        apiCode: String?,
        retry: String?
    ) {
        self.errorType = errorType
        self.requestID = requestID
        self.status = status
        self.apiCode = apiCode
        self.retry = retry
    }

    public init(error: Error) {
        if let transportError = error as? APITransportError {
            self.init(
                errorType: String(describing: Swift.type(of: transportError)),
                requestID: transportError.requestID ?? transportError.apiError?.requestID,
                status: transportError.statusCode ?? transportError.apiError?.status,
                apiCode: transportError.apiError?.code,
                retry: Self.retryDescription(transportError.retryDecision)
            )
        } else {
            self.init(
                errorType: String(describing: Swift.type(of: error)),
                requestID: nil,
                status: nil,
                apiCode: nil,
                retry: nil
            )
        }
    }

    private static func retryDescription(_ decision: APIRetryDecision) -> String {
        switch decision {
        case .retrySameRequest(let seconds):
            "retry_same_request:\(seconds.map(String.init) ?? "unspecified")"
        case .refreshAuthentication:
            "refresh_authentication"
        case .doNotRetry:
            "do_not_retry"
        }
    }
}

public struct SettingsSurfacePartialFailure: Equatable, Sendable {
    public let component: SettingsSurfaceComponent
    public let diagnostic: SettingsSurfaceFailureDiagnostic

    public init(component: SettingsSurfaceComponent, diagnostic: SettingsSurfaceFailureDiagnostic) {
        self.component = component
        self.diagnostic = diagnostic
    }

    public init(component: SettingsSurfaceComponent, error: Error) {
        self.init(component: component, diagnostic: SettingsSurfaceFailureDiagnostic(error: error))
    }
}

public struct SettingsSurfaceData: Equatable, Sendable {
    public let account: SettingsAccountProfile?
    public let notifications: SettingsNotificationPreferences?
    public let apiTokens: [SettingsAPITokenSummary]
    public let oauthConnections: [SettingsOAuthConnectionSummary]
    public let environment: NativeCacheEnvironment
    public let offline: OfflineState
    public let source: SettingsSurfaceDataSource
    public let tokenManagementAvailability: SettingsTokenManagementAvailability
    public let partialFailures: [SettingsSurfacePartialFailure]

    public init(
        account: SettingsAccountProfile?,
        notifications: SettingsNotificationPreferences?,
        apiTokens: [SettingsAPITokenSummary],
        oauthConnections: [SettingsOAuthConnectionSummary],
        environment: NativeCacheEnvironment,
        offline: OfflineState,
        source: SettingsSurfaceDataSource,
        tokenManagementAvailability: SettingsTokenManagementAvailability = .available,
        partialFailures: [SettingsSurfacePartialFailure] = []
    ) {
        self.account = account
        self.notifications = notifications
        self.apiTokens = apiTokens
        self.oauthConnections = oauthConnections
        self.environment = environment
        self.offline = offline
        self.source = source
        self.tokenManagementAvailability = tokenManagementAvailability
        self.partialFailures = partialFailures
    }
}

public struct SettingsSurfaceResult: Equatable, Sendable {
    public let data: SettingsSurfaceData
    public let persistedRecords: [NativeCacheRecord]

    public init(data: SettingsSurfaceData, persistedRecords: [NativeCacheRecord]) {
        self.data = data
        self.persistedRecords = persistedRecords
    }
}

public struct SettingsTransportEnvelope<Value: Equatable & Sendable>: Equatable, Sendable {
    public let requestID: String
    public let data: Value
    public let validatedAt: Date

    public init(requestID: String, data: Value, validatedAt: Date) {
        self.requestID = requestID
        self.data = data
        self.validatedAt = validatedAt
    }
}

public protocol SettingsSurfaceTransport: Sendable {
    func fetchAccount(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<SettingsAccountProfile>
    func fetchNotificationPreferences(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<SettingsNotificationPreferences>
    func fetchAPITokens(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<[SettingsAPITokenSummary]>
    func fetchOAuthConnections(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<[SettingsOAuthConnectionSummary]>
}

public struct URLSessionSettingsSurfaceTransport: SettingsSurfaceTransport {
    private let transport: any SpoonjoyAPITransport
    private let now: @Sendable () -> Date

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transport = transport
        self.now = now
    }

    public func fetchAccount(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<SettingsAccountProfile> {
        let envelope = try await transport.send(request, configuration: configuration, decode: SettingsAccountProfile.self)
        return SettingsTransportEnvelope(requestID: envelope.requestID, data: envelope.data, validatedAt: now())
    }

    public func fetchNotificationPreferences(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<SettingsNotificationPreferences> {
        let envelope = try await transport.send(request, configuration: configuration, decode: SettingsNotificationPreferences.self)
        return SettingsTransportEnvelope(requestID: envelope.requestID, data: envelope.data, validatedAt: now())
    }

    public func fetchAPITokens(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<[SettingsAPITokenSummary]> {
        let envelope = try await transport.send(request, configuration: configuration, decode: SettingsAPITokenListResponse.self)
        return SettingsTransportEnvelope(requestID: envelope.requestID, data: envelope.data.tokens, validatedAt: now())
    }

    public func fetchOAuthConnections(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<[SettingsOAuthConnectionSummary]> {
        let envelope = try await transport.send(request, configuration: configuration, decode: SettingsOAuthConnectionListResponse.self)
        return SettingsTransportEnvelope(requestID: envelope.requestID, data: envelope.data.connections, validatedAt: now())
    }
}

public protocol SettingsSurfaceRepository: Sendable {}

public struct LiveSettingsSurfaceRepository: SettingsSurfaceRepository {
    private let transport: any SettingsSurfaceTransport
    private let cache: NativeDurableCache
    private let configuration: APIClientConfiguration

    public init(
        transport: any SettingsSurfaceTransport = URLSessionSettingsSurfaceTransport(),
        cache: NativeDurableCache = NativeDurableCache(),
        configuration: APIClientConfiguration
    ) {
        self.transport = transport
        self.cache = cache
        self.configuration = configuration
    }

    public func fetchSettingsSurface(accountID: String, environment: NativeCacheEnvironment) async throws -> SettingsSurfaceResult {
        try await fetchSettingsSurface(
            accountID: accountID,
            environment: environment,
            grantedScopes: Set(NativeAuthSession.firstPartyTokenScopes)
        )
    }

    public func fetchSettingsSurface(
        accountID: String,
        environment: NativeCacheEnvironment,
        grantedScopes: Set<String>
    ) async throws -> SettingsSurfaceResult {
        let account = try await transport.fetchAccount(PrivateAccountRequests.currentAccount(), configuration: configuration)
        let notifications = try await optionalFetch(.notificationPreferences) {
            try await transport.fetchNotificationPreferences(PrivateAccountRequests.notificationPreferences(), configuration: configuration)
        }
        let canReadTokenManagement = grantedScopes.contains("tokens:read")
        let tokens = canReadTokenManagement
            ? try await optionalFetch(.apiTokens) {
                try await transport.fetchAPITokens(TokenCredentialRequests.listTokens(), configuration: configuration)
            }
            : nil
        let connections = canReadTokenManagement
            ? try await optionalFetch(.oauthConnections) {
                try await transport.fetchOAuthConnections(PrivateAccountRequests.connections(), configuration: configuration)
            }
            : nil
        let partialFailures = [
            notifications.failure,
            tokens?.failure,
            connections?.failure
        ].compactMap { $0 }
        let validatedAt = [
            notifications.value?.validatedAt,
            tokens?.value?.validatedAt,
            connections?.value?.validatedAt
        ]
        .compactMap { $0 }
        .reduce(account.validatedAt, max)
        let tokenManagementAvailability: SettingsTokenManagementAvailability = canReadTokenManagement
            ? .available
            : .unavailableMissingScope

        let data = SettingsSurfaceData(
            account: account.data,
            notifications: notifications.value?.data,
            apiTokens: tokens?.value?.data ?? [],
            oauthConnections: connections?.value?.data ?? [],
            environment: environment,
            offline: .available(snapshotCount: max(1, cache.records.count), lastRestoredAt: nil),
            source: .live(requestID: "req_settings_surface", validatedAt: validatedAt),
            tokenManagementAvailability: tokenManagementAvailability,
            partialFailures: partialFailures
        )

        return SettingsSurfaceResult(
            data: data,
            persistedRecords: try Self.persistedRecords(
                account: account.data,
                notifications: notifications.value?.data,
                apiTokens: tokens?.value?.data,
                oauthConnections: connections?.value?.data,
                accountID: accountID,
                environment: environment,
                fetchedAt: validatedAt
            )
        )
    }

    private func optionalFetch<Value: Equatable & Sendable>(
        _ component: SettingsSurfaceComponent,
        _ operation: @Sendable () async throws -> SettingsTransportEnvelope<Value>
    ) async throws -> (value: SettingsTransportEnvelope<Value>?, failure: SettingsSurfacePartialFailure?) {
        do {
            return (try await operation(), nil)
        } catch {
            if error is CancellationError {
                throw error
            }
            return (nil, SettingsSurfacePartialFailure(component: component, error: error))
        }
    }

    private static func persistedRecords(
        account: SettingsAccountProfile,
        notifications: SettingsNotificationPreferences?,
        apiTokens: [SettingsAPITokenSummary]?,
        oauthConnections: [SettingsOAuthConnectionSummary]?,
        accountID: String,
        environment: NativeCacheEnvironment,
        fetchedAt: Date
    ) throws -> [NativeCacheRecord] {
        var records = [
            try record(
                accountID: accountID,
                environment: environment,
                domain: NativeCacheDomain.settings,
                sourceEndpoint: "/api/v1/me",
                fetchedAt: fetchedAt,
                payload: .settings(account: account)
            )
        ]
        if let notifications {
            records.append(try record(
                accountID: accountID,
                environment: environment,
                domain: NativeCacheDomain.notificationPreferences,
                sourceEndpoint: "/api/v1/me/notification-preferences",
                fetchedAt: fetchedAt,
                payload: .notificationPreferenceState(notifications)
            ))
        }
        if let apiTokens {
            records.append(try record(
                accountID: accountID,
                environment: environment,
                domain: NativeCacheDomain.tokenMetadata,
                sourceEndpoint: "/api/v1/tokens",
                fetchedAt: fetchedAt,
                payload: NativeCachePayload.tokenMetadata(credentials: apiTokens.map(NativeTokenMetadata.init(settingsToken:)))
            ))
        }
        if let oauthConnections {
            records.append(try record(
                accountID: accountID,
                environment: environment,
                domain: NativeCacheDomain.connectionStatus,
                sourceEndpoint: "/api/v1/me/connections",
                fetchedAt: fetchedAt,
                payload: NativeCachePayload.connectionStatus(connections: oauthConnections.map(NativeConnectionStatus.init(settingsConnection:)))
            ))
        }
        return records
    }

    private static func record(
        accountID: String,
        environment: NativeCacheEnvironment,
        domain: NativeCacheDomain,
        sourceEndpoint: String,
        fetchedAt: Date,
        payload: NativeCachePayload
    ) throws -> NativeCacheRecord {
        try NativeCacheRecord(
            id: domain.stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: accountID,
                environment: environment,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: domain,
                fetchedAt: fetchedAt,
                lastValidatedAt: fetchedAt,
                sourceEndpoint: sourceEndpoint,
                serverRevision: nil
            ),
            payload: payload
        )
    }
}

public struct SettingsSurfaceCacheSnapshot: Equatable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment
    public let records: [NativeCacheRecord]

    public init(accountID: String, environment: NativeCacheEnvironment, records: [NativeCacheRecord]) {
        self.accountID = accountID
        self.environment = environment
        self.records = records
    }
}

public struct SnapshotSettingsSurfaceRepository: SettingsSurfaceRepository {
    private let snapshot: SettingsSurfaceCacheSnapshot

    public init(snapshot: SettingsSurfaceCacheSnapshot) {
        self.snapshot = snapshot
    }

    public func fetchSettingsSurface() throws -> SettingsSurfaceResult {
        let account = snapshot.records.compactMap { record -> SettingsAccountProfile? in
            guard case .settings(let account) = record.payload else { return nil }
            return account
        }.first
        let notifications = snapshot.records.compactMap { record -> SettingsNotificationPreferences? in
            switch record.payload {
            case .notificationPreferenceState(let preferences):
                return preferences
            case .notificationPreferences(let marketingEnabled, let cookingRemindersEnabled):
                return SettingsNotificationPreferences(
                    notifySpoonOnMyRecipe: marketingEnabled,
                    notifyForkOfMyRecipe: cookingRemindersEnabled,
                    notifyCookbookSaveOfMine: marketingEnabled,
                    notifyFellowChefOriginCook: cookingRemindersEnabled
                )
            default:
                return nil
            }
        }.first
        let tokens = snapshot.records.flatMap { record -> [SettingsAPITokenSummary] in
            guard case .tokenMetadata(let credentials) = record.payload else { return [] }
            return credentials.map(SettingsAPITokenSummary.init(nativeToken:))
        }
        let connections = snapshot.records.flatMap { record -> [SettingsOAuthConnectionSummary] in
            guard case .connectionStatus(let connections) = record.payload else { return [] }
            return connections.map(SettingsOAuthConnectionSummary.init(nativeConnection:))
        }
        let lastValidatedAt = snapshot.records.map(\.metadata.lastValidatedAt).max() ?? .distantPast
        let data = SettingsSurfaceData(
            account: account,
            notifications: notifications,
            apiTokens: tokens,
            oauthConnections: connections,
            environment: snapshot.environment,
            offline: .available(snapshotCount: snapshot.records.count, lastRestoredAt: nil),
            source: .cache(lastValidatedAt: lastValidatedAt)
        )
        return SettingsSurfaceResult(data: data, persistedRecords: snapshot.records)
    }
}

private extension NativeTokenMetadata {
    init(settingsToken token: SettingsAPITokenSummary) {
        self.init(
            id: token.id,
            name: token.name,
            tokenPrefix: token.tokenPrefix,
            scopes: token.scopes,
            createdAt: token.createdAt,
            updatedAt: token.updatedAt,
            lastUsedAt: token.lastUsedAt,
            revokedAt: token.revokedAt,
            expiresAt: token.expiresAt
        )
    }
}

private extension NativeConnectionStatus {
    init(settingsConnection connection: SettingsOAuthConnectionSummary) {
        self.init(
            id: connection.id,
            provider: connection.clientName,
            status: .connected,
            clientID: connection.clientID,
            clientName: connection.clientName,
            resource: connection.resource,
            scopes: connection.scopes,
            createdAt: connection.createdAt,
            refreshTokenCount: connection.refreshTokenCount,
            accessTokenCount: connection.accessTokenCount
        )
    }
}

private extension SettingsAPITokenSummary {
    init(nativeToken token: NativeTokenMetadata) {
        self.init(
            id: token.id,
            name: token.name,
            tokenPrefix: token.tokenPrefix.isEmpty ? token.id : token.tokenPrefix,
            scopes: token.scopes,
            createdAt: token.createdAt ?? "",
            updatedAt: token.updatedAt ?? token.createdAt ?? "",
            lastUsedAt: token.lastUsedAt,
            revokedAt: token.revokedAt,
            expiresAt: token.expiresAt
        )
    }
}

private extension SettingsOAuthConnectionSummary {
    init(nativeConnection connection: NativeConnectionStatus) {
        self.init(
            id: connection.id,
            clientID: connection.clientID.isEmpty ? connection.id : connection.clientID,
            clientName: connection.clientName.isEmpty ? connection.provider : connection.clientName,
            resource: connection.resource,
            scopes: connection.scopes,
            createdAt: connection.createdAt ?? "",
            refreshTokenCount: connection.refreshTokenCount,
            accessTokenCount: connection.accessTokenCount
        )
    }
}
