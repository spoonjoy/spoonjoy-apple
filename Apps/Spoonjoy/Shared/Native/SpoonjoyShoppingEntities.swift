import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyShoppingListEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoyShoppingListEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shopping List")
    static let defaultQuery = SpoonjoyShoppingListEntityQuery()

    let descriptor: ShoppingListEntityDescriptor

    var id: String { descriptor.id }
    var transferValue: ShoppingEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: ShoppingListEntityDescriptor) {
        self.descriptor = descriptor
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "\(descriptor.subtitle) - \(descriptor.disambiguationLabel)"
        return DisplayRepresentation(title: "\(descriptor.title)", subtitle: "\(subtitle)")
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.descriptor.transferValue.userVisibleSummary)
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyShoppingItemEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoyShoppingItemEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shopping Item")
    static let defaultQuery = SpoonjoyShoppingItemEntityQuery()

    let descriptor: ShoppingItemEntityDescriptor

    var id: String { descriptor.id }
    var transferValue: ShoppingEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: ShoppingItemEntityDescriptor) {
        self.descriptor = descriptor
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "\(descriptor.subtitle) - \(descriptor.disambiguationLabel)"
        return DisplayRepresentation(title: "\(descriptor.title)", subtitle: "\(subtitle)")
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.descriptor.transferValue.userVisibleSummary)
    }

    func resolvedShoppingItemID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedShoppingItemEntity
        }
        return descriptor.itemID
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyShoppingListEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyShoppingListEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptor = try await catalog.shoppingListEntity()
        guard identifiers.isEmpty || identifiers.contains(descriptor.id) else {
            return []
        }
        return [SpoonjoyShoppingListEntity(descriptor: descriptor)]
    }

    func suggestedEntities() async throws -> [SpoonjoyShoppingListEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        return [SpoonjoyShoppingListEntity(descriptor: try await catalog.shoppingListEntity())]
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

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyShoppingItemEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyShoppingItemEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.shoppingItemEntities(for: identifiers)
        return descriptors.map(SpoonjoyShoppingItemEntity.init)
    }

    func entities(matching string: String) async throws -> [SpoonjoyShoppingItemEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.shoppingItemEntities(matching: string)
        return descriptors.map(SpoonjoyShoppingItemEntity.init)
    }

    func suggestedEntities() async throws -> [SpoonjoyShoppingItemEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.suggestedShoppingItemEntities()
        return descriptors.map(SpoonjoyShoppingItemEntity.init)
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
