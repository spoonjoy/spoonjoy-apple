import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents

private let spoonjoySettingsAuthProviderOptionContract = "struct SpoonjoySettingsAuthProviderOption: AppEnum"

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyAPITokenEntity: AppEntity {
    typealias DefaultQuery = SpoonjoyAPITokenEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "API Token")
    static let defaultQuery = SpoonjoyAPITokenEntityQuery()

    let descriptor: APITokenEntityDescriptor

    var id: String { descriptor.id }
    var tokenPrefix: String { descriptor.tokenPrefix }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: APITokenEntityDescriptor) {
        self.descriptor = descriptor
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(descriptor.name)",
            subtitle: "\(descriptor.subtitle)"
        )
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
        let descriptors = try await SpoonjoySettingsEntitySource().apiTokenDescriptors()
        let descriptorsByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
        return identifiers.compactMap { descriptorsByID[$0].map(SpoonjoyAPITokenEntity.init) }
    }

    func entities(matching string: String) async throws -> [SpoonjoyAPITokenEntity] {
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

    func suggestedEntities() async throws -> [SpoonjoyAPITokenEntity] {
        try await SpoonjoySettingsEntitySource()
            .apiTokenDescriptors()
            .map(SpoonjoyAPITokenEntity.init)
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyAccountConnectionEntity: AppEntity {
    typealias DefaultQuery = SpoonjoyAccountConnectionEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Account Connection")
    static let defaultQuery = SpoonjoyAccountConnectionEntityQuery()

    let descriptor: AccountConnectionEntityDescriptor

    var id: String { descriptor.id }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: AccountConnectionEntityDescriptor) {
        self.descriptor = descriptor
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(descriptor.clientName)",
            subtitle: "\(descriptor.subtitle)"
        )
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
        let descriptors = try await SpoonjoySettingsEntitySource().accountConnectionDescriptors()
        let descriptorsByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
        return identifiers.compactMap { descriptorsByID[$0].map(SpoonjoyAccountConnectionEntity.init) }
    }

    func entities(matching string: String) async throws -> [SpoonjoyAccountConnectionEntity] {
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

    func suggestedEntities() async throws -> [SpoonjoyAccountConnectionEntity] {
        try await SpoonjoySettingsEntitySource()
            .accountConnectionDescriptors()
            .map(SpoonjoyAccountConnectionEntity.init)
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
            .apple: DisplayRepresentation(title: "Apple")
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
        let syncStore = try FileBackedNativeSyncStore(
            fileURL: appDirectory.appendingPathComponent("native-sync-store.json"),
            mediaResolver: NativeStagedMediaDirectory(
                directoryURL: appDirectory.appendingPathComponent("native-staged-media", isDirectory: true)
            )
        )
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await SpoonjoyIntentScopeProvider(authVault: KeychainTokenVault()).trustedIntentScope(from: syncSnapshot)
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
