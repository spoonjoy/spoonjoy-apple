import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import CoreTransferable
import UniformTypeIdentifiers

private let spoonjoySettingsAuthProviderOptionContract = "struct SpoonjoySettingsAuthProviderOption: AppEnum"

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyAPITokenEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoyAPITokenEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Access Key")
    static let defaultQuery = SpoonjoyAPITokenEntityQuery()

    // Only the app needs the descriptor's ids, credential id and key prefix, so they stay plain members, hidden from Siri.
    let descriptor: APITokenEntityDescriptor

    // What a person asks about an access key. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Name", description: "The name given to the access key when it was made.")
    var name: String
    @Property(title: "Permissions", description: "What the access key lets an agent do, such as read recipes.")
    var scopes: [String]
    @Property(title: "Link", description: "The settings page on spoonjoy.app where access keys are managed.")
    var link: URL
    #else
    @Property(title: "Name")
    var name: String
    @Property(title: "Permissions")
    var scopes: [String]
    @Property(title: "Link")
    var link: URL
    #endif

    var id: String { descriptor.id }
    var shareText: String { "Spoonjoy access key \(descriptor.name)\n\(link.absoluteString)" }
    var tokenPrefix: String { descriptor.tokenPrefix }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: APITokenEntityDescriptor) {
        self.descriptor = descriptor
        name = descriptor.name
        scopes = descriptor.scopes
        link = NativeEntityWebLink.url(for: descriptor.route)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(descriptor.name)",
            subtitle: "\(descriptor.subtitle)"
        )
    }

    // Carries the name and the settings page only: never the key or a token, which must not leave the app.
    // Spelled inline with a literal content type, which Xcode 27.1's App Intents metadata records.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { entity in Data(entity.shareText.utf8) }
        ProxyRepresentation(exporting: \.link)
    }

    func resolvedCredentialID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedAPITokenEntity
        }
        return descriptor.credentialID
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyAPITokenEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyAPITokenEntity] {
        try await IntentEntityQueryAccess.results {
            let descriptors = try await SpoonjoySettingsEntitySource().apiTokenDescriptors()
            let descriptorsByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
            return identifiers.compactMap { descriptorsByID[$0].map(SpoonjoyAPITokenEntity.init) }
        }
    }

    func entities(matching string: String) async throws -> [SpoonjoyAPITokenEntity] {
        try await IntentEntityQueryAccess.results {
            let descriptors = try await SpoonjoySettingsEntitySource().apiTokenDescriptors()
            let query = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else {
                return descriptors.map(SpoonjoyAPITokenEntity.init)
            }
            return descriptors
                .filter { descriptor in
                    [
                        descriptor.name,
                        descriptor.tokenPrefix,
                        descriptor.subtitle,
                        descriptor.scopes.joined(separator: " ")
                    ].contains { $0.lowercased().contains(query) }
                }
                .map(SpoonjoyAPITokenEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SpoonjoyAPITokenEntity] {
        try await IntentEntityQueryAccess.results {
            try await SpoonjoySettingsEntitySource()
                .apiTokenDescriptors()
                .map(SpoonjoyAPITokenEntity.init)
        }
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyAccountConnectionEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoyAccountConnectionEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Account Connection")
    static let defaultQuery = SpoonjoyAccountConnectionEntityQuery()

    // Only the app needs the descriptor's ids and connection id, so they stay plain members, hidden from Siri.
    let descriptor: AccountConnectionEntityDescriptor

    // What a person asks about an account connection. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "App", description: "The app or agent connected to the Spoonjoy account.")
    var app: String
    @Property(title: "Resource", description: "What the connection was granted access to, when it names one.")
    var resource: String?
    @Property(title: "Permissions", description: "What the connection lets the app do, such as read recipes.")
    var scopes: [String]
    @Property(title: "Link", description: "The settings page on spoonjoy.app where connections are managed.")
    var link: URL
    #else
    @Property(title: "App")
    var app: String
    @Property(title: "Resource")
    var resource: String?
    @Property(title: "Permissions")
    var scopes: [String]
    @Property(title: "Link")
    var link: URL
    #endif

    var id: String { descriptor.id }
    var shareText: String { "Spoonjoy connection \(descriptor.clientName)\n\(link.absoluteString)" }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: AccountConnectionEntityDescriptor) {
        self.descriptor = descriptor
        app = descriptor.clientName
        resource = descriptor.resource
        scopes = descriptor.scopes
        link = NativeEntityWebLink.url(for: descriptor.route)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(descriptor.clientName)",
            subtitle: "\(descriptor.subtitle)"
        )
    }

    // Carries the name and the settings page only: never the key or a token, which must not leave the app.
    // Spelled inline with a literal content type, which Xcode 27.1's App Intents metadata records.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { entity in Data(entity.shareText.utf8) }
        ProxyRepresentation(exporting: \.link)
    }

    func resolvedConnectionID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedAccountConnectionEntity
        }
        return descriptor.connectionID
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyAccountConnectionEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyAccountConnectionEntity] {
        try await IntentEntityQueryAccess.results {
            let descriptors = try await SpoonjoySettingsEntitySource().accountConnectionDescriptors()
            let descriptorsByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
            return identifiers.compactMap { descriptorsByID[$0].map(SpoonjoyAccountConnectionEntity.init) }
        }
    }

    func entities(matching string: String) async throws -> [SpoonjoyAccountConnectionEntity] {
        try await IntentEntityQueryAccess.results {
            let descriptors = try await SpoonjoySettingsEntitySource().accountConnectionDescriptors()
            let query = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else {
                return descriptors.map(SpoonjoyAccountConnectionEntity.init)
            }
            return descriptors
                .filter { descriptor in
                    [
                        descriptor.clientName,
                        descriptor.resource ?? "",
                        descriptor.subtitle,
                        descriptor.scopes.joined(separator: " ")
                    ].contains { $0.lowercased().contains(query) }
                }
                .map(SpoonjoyAccountConnectionEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SpoonjoyAccountConnectionEntity] {
        try await IntentEntityQueryAccess.results {
            try await SpoonjoySettingsEntitySource()
                .accountConnectionDescriptors()
                .map(SpoonjoyAccountConnectionEntity.init)
        }
    }
}

@available(iOS 27.0, macOS 27.0, *)
enum SpoonjoySettingsAuthProviderOption: String, AppEnum {
    case google
    case github
    case apple

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Provider")
    }

    static var caseDisplayRepresentations: [SpoonjoySettingsAuthProviderOption: DisplayRepresentation] {
        [
            .google: DisplayRepresentation(title: "Google"),
            .github: DisplayRepresentation(title: "GitHub"),
            .apple: DisplayRepresentation(title: "Device Sign-In")
        ]
    }

    var authProvider: SettingsAuthProvider {
        switch self {
        case .google:
            .google
        case .github:
            .github
        case .apple:
            .apple
        }
    }
}

private struct SpoonjoySettingsEntitySource {
    private typealias SettingsScope = (accountID: String, environment: NativeCacheEnvironment)

    func apiTokenDescriptors(fileURL: URL = NativeAppStateLocation.defaultFileURL()) async throws -> [APITokenEntityDescriptor] {
        let inputs = try await settingsData(fileURL: fileURL)
        return inputs.data.apiTokens.map { token in
            let scopeSummary = settingsDisambiguation(scope: inputs.scope)
            let scopeList = token.scopes.isEmpty ? "No scopes" : token.scopes.joined(separator: ", ")
            let prefix = token.tokenPrefix.isEmpty ? "No prefix" : token.tokenPrefix
            return APITokenEntityDescriptor(
                id: scopedIdentifier(kind: "api-token", rawID: token.id, scope: inputs.scope),
                credentialID: token.id,
                name: token.name,
                tokenPrefix: token.tokenPrefix,
                scopes: token.scopes,
                subtitle: "\(prefix) - \(scopeList)",
                disambiguationLabel: scopeSummary
            )
        }
    }

    func accountConnectionDescriptors(fileURL: URL = NativeAppStateLocation.defaultFileURL()) async throws -> [AccountConnectionEntityDescriptor] {
        let inputs = try await settingsData(fileURL: fileURL)
        return inputs.data.oauthConnections.map { connection in
            let resource = connection.resource ?? "Spoonjoy"
            let scopeList = connection.scopes.isEmpty ? "No scopes" : connection.scopes.joined(separator: ", ")
            return AccountConnectionEntityDescriptor(
                id: scopedIdentifier(kind: "account-connection", rawID: connection.id, scope: inputs.scope),
                connectionID: connection.id,
                clientName: connection.clientName,
                resource: connection.resource,
                scopes: connection.scopes,
                subtitle: "\(resource) - \(scopeList)",
                disambiguationLabel: settingsDisambiguation(scope: inputs.scope)
            )
        }
    }

    private func settingsData(
        fileURL: URL
    ) async throws -> (
        data: SettingsSurfaceData,
        scope: SettingsScope
    ) {
        let appDirectory = fileURL.deletingLastPathComponent()
        let syncStore = NativeProcessSyncStore.shared(appDirectory: appDirectory)
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await SpoonjoyIntentScopeProvider(authVault: SpoonjoyAppTokenVault.current()).trustedIntentScope(from: syncSnapshot)
        let cacheStore = NativeDurableCacheStore(fileURL: appDirectory.appendingPathComponent("native-durable-cache.json"))
        let fallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: scope.accountID,
            environment: scope.environment,
            createdAt: Date.distantPast,
            records: [],
            dismissedIndicators: []
        )
        let cacheSnapshot = try cacheStore.loadOrRecover(fallback: fallback).value
        guard cacheSnapshot.accountID == scope.accountID,
              cacheSnapshot.environment == scope.environment else {
            return (emptySettingsData(scope: scope), scope)
        }
        let snapshot = SettingsSurfaceCacheSnapshot(
            accountID: scope.accountID,
            environment: scope.environment,
            records: cacheSnapshot.records
        )
        let result = try SnapshotSettingsSurfaceRepository(snapshot: snapshot).fetchSettingsSurface()
        return (result.data, scope)
    }

    private func emptySettingsData(scope: SettingsScope) -> SettingsSurfaceData {
        SettingsSurfaceData(
            account: nil,
            notifications: nil,
            apiTokens: [],
            oauthConnections: [],
            environment: scope.environment,
            offline: .available(snapshotCount: 0, lastRestoredAt: nil),
            source: .cache(lastValidatedAt: .distantPast)
        )
    }

    private func scopedIdentifier(kind: String, rawID: String, scope: SettingsScope) -> String {
        "\(scope.environment.rawValue)|schema\(NativeDurableCacheSnapshot.currentSchemaVersion)|\(scope.accountID)|\(kind)|\(rawID)"
    }

    private func settingsDisambiguation(scope: SettingsScope) -> String {
        "\(scope.environment.rawValue) Spoonjoy account"
    }
}
#endif
