import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoySpoonEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoySpoonEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cook Log")
    static let defaultQuery = SpoonjoySpoonEntityQuery()

    let descriptor: SpoonEntityDescriptor

    var id: String { descriptor.id }
    var transferValue: SpoonEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: SpoonEntityDescriptor) {
        self.descriptor = descriptor
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "\(descriptor.subtitle) - \(descriptor.disambiguationLabel)"
        return DisplayRepresentation(title: "\(descriptor.title)", subtitle: "\(subtitle)")
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.descriptor.transferValue.userVisibleSummary)
    }

    func resolvedSpoonID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedSpoonEntity
        }
        return descriptor.spoonID
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoySpoonEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoySpoonEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await SpoonEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.spoonEntities(for: identifiers)
        return descriptors.map(SpoonjoySpoonEntity.init)
    }

    func entities(matching string: String) async throws -> [SpoonjoySpoonEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await SpoonEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.spoonEntities(matching: string)
        return descriptors.map(SpoonjoySpoonEntity.init)
    }

    func suggestedEntities() async throws -> [SpoonjoySpoonEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await SpoonEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.suggestedSpoonEntities()
        return descriptors.map(SpoonjoySpoonEntity.init)
    }

    private func syncStore(fileURL: URL = NativeAppStateLocation.defaultFileURL()) throws -> any NativeSyncStore {
        let appDirectory = fileURL.deletingLastPathComponent()
        return try FileBackedNativeSyncStore(
            fileURL: appDirectory.appendingPathComponent("native-sync-store.json"),
            mediaResolver: NativeStagedMediaDirectory(
                directoryURL: appDirectory.appendingPathComponent("native-staged-media", isDirectory: true)
            )
        )
    }

    private func scope(syncStore: any NativeSyncStore) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        let syncSnapshot = try await syncStore.loadSnapshot()
        return try await SpoonjoyIntentScopeProvider(authVault: KeychainTokenVault()).trustedIntentScope(from: syncSnapshot)
    }
}
#endif
