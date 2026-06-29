import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyChefProfileEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoyChefProfileEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Chef Profile")
    static let defaultQuery = SpoonjoyChefProfileEntityQuery()

    let descriptor: ChefProfileEntityDescriptor

    var id: String { descriptor.id }
    var transferValue: ChefProfileEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: ChefProfileEntityDescriptor) {
        self.descriptor = descriptor
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "\(descriptor.subtitle) - \(descriptor.disambiguationLabel)"
        return DisplayRepresentation(title: "\(descriptor.title)", subtitle: "\(subtitle)")
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.descriptor.transferValue.userVisibleSummary)
    }

    func resolvedChefProfileID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedChefProfileEntity
        }
        return descriptor.profileID
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyChefProfileEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyChefProfileEntity] {
        let inputs = try await catalogInputs()
        let catalog = try await ChefProfileEntityCatalog.loading(
            syncStore: inputs.syncStore,
            cacheStore: inputs.cacheStore,
            currentAccountID: inputs.scope.accountID,
            environment: inputs.scope.environment
        )
        let descriptors = try await catalog.chefProfileEntities(for: identifiers)
        return descriptors.map(SpoonjoyChefProfileEntity.init)
    }

    func entities(matching string: String) async throws -> [SpoonjoyChefProfileEntity] {
        let inputs = try await catalogInputs()
        let catalog = try await ChefProfileEntityCatalog.loading(
            syncStore: inputs.syncStore,
            cacheStore: inputs.cacheStore,
            currentAccountID: inputs.scope.accountID,
            environment: inputs.scope.environment
        )
        let descriptors = try await catalog.chefProfileEntities(matching: string)
        return descriptors.map(SpoonjoyChefProfileEntity.init)
    }

    func suggestedEntities() async throws -> [SpoonjoyChefProfileEntity] {
        let inputs = try await catalogInputs()
        let catalog = try await ChefProfileEntityCatalog.loading(
            syncStore: inputs.syncStore,
            cacheStore: inputs.cacheStore,
            currentAccountID: inputs.scope.accountID,
            environment: inputs.scope.environment
        )
        let descriptors = try await catalog.suggestedChefProfileEntities()
        return descriptors.map(SpoonjoyChefProfileEntity.init)
    }

    private func catalogInputs(
        fileURL: URL = NativeAppStateLocation.defaultFileURL()
    ) async throws -> (
        syncStore: any NativeSyncStore,
        cacheStore: NativeDurableCacheStore,
        scope: (accountID: String, environment: NativeCacheEnvironment)
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
        return (syncStore, cacheStore, scope)
    }
}
#endif
