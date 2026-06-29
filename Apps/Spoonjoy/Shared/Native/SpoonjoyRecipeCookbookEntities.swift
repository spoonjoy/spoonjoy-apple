import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyRecipeEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoyRecipeEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
    static let defaultQuery = SpoonjoyRecipeEntityQuery()

    let descriptor: RecipeEntityDescriptor

    var id: String { descriptor.id }
    var transferValue: RecipeCookbookEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: RecipeEntityDescriptor) {
        self.descriptor = descriptor
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "\(descriptor.subtitle) - \(descriptor.disambiguationLabel)"
        return DisplayRepresentation(title: "\(descriptor.title)", subtitle: "\(subtitle)")
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.descriptor.transferValue.userVisibleSummary)
    }

    func resolvedRecipeID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedRecipeEntity
        }
        return descriptor.id
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCookbookEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoyCookbookEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cookbook")
    static let defaultQuery = SpoonjoyCookbookEntityQuery()

    let descriptor: CookbookEntityDescriptor

    var id: String { descriptor.id }
    var transferValue: RecipeCookbookEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: CookbookEntityDescriptor) {
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
struct SpoonjoyRecipeEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyRecipeEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.recipeEntities(for: identifiers)
        return descriptors.map(SpoonjoyRecipeEntity.init)
    }

    func entities(matching string: String) async throws -> [SpoonjoyRecipeEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.recipeEntities(matching: string)
        return descriptors.map(SpoonjoyRecipeEntity.init)
    }

    func suggestedEntities() async throws -> [SpoonjoyRecipeEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.suggestedRecipeEntities()
        return descriptors.map(SpoonjoyRecipeEntity.init)
    }

    private func syncStore() throws -> any NativeSyncStore {
        try SpoonjoyIntentSyncStoreFactory.syncStore()
    }

    private func scope(syncStore: any NativeSyncStore) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        let syncSnapshot = try await syncStore.loadSnapshot()
        return try await SpoonjoyIntentScopeProvider(authVault: KeychainTokenVault()).trustedIntentScope(from: syncSnapshot)
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCookbookEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyCookbookEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.cookbookEntities(for: identifiers)
        return descriptors.map(SpoonjoyCookbookEntity.init)
    }

    func entities(matching string: String) async throws -> [SpoonjoyCookbookEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.cookbookEntities(matching: string)
        return descriptors.map(SpoonjoyCookbookEntity.init)
    }

    func suggestedEntities() async throws -> [SpoonjoyCookbookEntity] {
        let syncStore = try syncStore()
        let scope = try await scope(syncStore: syncStore)
        let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
        let descriptors = try await catalog.suggestedCookbookEntities()
        return descriptors.map(SpoonjoyCookbookEntity.init)
    }

    private func syncStore() throws -> any NativeSyncStore {
        try SpoonjoyIntentSyncStoreFactory.syncStore()
    }

    private func scope(syncStore: any NativeSyncStore) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        let syncSnapshot = try await syncStore.loadSnapshot()
        return try await SpoonjoyIntentScopeProvider(authVault: KeychainTokenVault()).trustedIntentScope(from: syncSnapshot)
    }
}

struct SpoonjoyIntentSyncStoreFactory {
    static func syncStore(fileURL: URL = NativeAppStateLocation.defaultFileURL()) throws -> any NativeSyncStore {
        let appDirectory = fileURL.deletingLastPathComponent()
        return try FileBackedNativeSyncStore(
            fileURL: appDirectory.appendingPathComponent("native-sync-store.json"),
            mediaResolver: NativeStagedMediaDirectory(
                directoryURL: appDirectory.appendingPathComponent("native-staged-media", isDirectory: true)
            )
        )
    }
}

struct SpoonjoyIntentScopeProvider {
    private let authVault: (any TokenVault)?

    init(authVault: (any TokenVault)? = KeychainTokenVault()) {
        self.authVault = authVault
    }

    func trustedIntentScope(from syncSnapshot: NativeSyncSnapshot) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        guard let session = try await authVault?.loadSession(),
              let accountID = session.accountID else {
            throw NativeIntentActionError.authRequired
        }
        let environment = syncSnapshot.accountID == accountID
            ? (syncSnapshot.environment ?? .production)
            : .production
        return (accountID: accountID, environment: environment)
    }
}
#endif
