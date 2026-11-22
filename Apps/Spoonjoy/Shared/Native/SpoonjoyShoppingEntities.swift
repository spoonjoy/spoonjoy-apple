import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import UniformTypeIdentifiers
import CoreSpotlight
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyShoppingListEntity: AppEntity, IndexedEntity, Transferable {
    typealias DefaultQuery = SpoonjoyShoppingListEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shopping List")
    static let defaultQuery = SpoonjoyShoppingListEntityQuery()

    // Only the app needs the descriptor's ids and route, so they stay plain members, hidden from Siri.
    let descriptor: ShoppingListEntityDescriptor

    // What a person asks about a shopping list. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Title", description: "The shopping list's name.")
    var title: String
    @Property(title: "Items to buy", description: "How many items on the list aren't checked off yet.")
    var activeItemCount: Int
    @Property(title: "Link", description: "The shopping list's page on spoonjoy.app, which only its owner can open.")
    var link: URL
    #else
    @Property(title: "Title")
    var title: String
    @Property(title: "Items to buy")
    var activeItemCount: Int
    @Property(title: "Link")
    var link: URL
    #endif

    var id: String { descriptor.id }
    var shareText: String { "\(descriptor.transferValue.userVisibleSummary)\n\(link.absoluteString)" }
    var transferValue: ShoppingEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: ShoppingListEntityDescriptor) {
        self.descriptor = descriptor
        title = descriptor.title
        activeItemCount = descriptor.activeItemCount
        link = NativeEntityWebLink.url(for: descriptor.route)
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "\(descriptor.subtitle) - \(descriptor.disambiguationLabel)"
        return DisplayRepresentation(title: "\(descriptor.title)", subtitle: "\(subtitle)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = descriptor.title
        attributes.contentDescription = descriptor.transferValue.userVisibleSummary
        attributes.keywords = [
            descriptor.title,
            descriptor.subtitle,
            "\(descriptor.activeItemCount) active items",
            "shopping list",
            "Spoonjoy"
        ]
        attributes.contentURL = deepLinkURL
        return attributes
    }

    // Spelled inline with a literal content type: Xcode 27.1's App Intents metadata recorded no content type for the
    // ProxyRepresentation this replaced, so Siri saw the entity as not Transferable.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { entity in Data(entity.shareText.utf8) }
        ProxyRepresentation(exporting: \.link)
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyShoppingItemEntity: AppEntity, IndexedEntity, Transferable {
    typealias DefaultQuery = SpoonjoyShoppingItemEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shopping Item")
    static let defaultQuery = SpoonjoyShoppingItemEntityQuery()

    // Only the app needs the descriptor's ids and route, so they stay plain members, hidden from Siri.
    let descriptor: ShoppingItemEntityDescriptor

    // What a person asks about a shopping item. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Name", description: "The item to buy, such as eggs or flour.")
    var name: String
    @Property(title: "Amount", description: "How much to buy, such as 2 cups.")
    var amount: String
    @Property(title: "Checked", description: "Whether the item is checked off the list.")
    var checked: Bool
    @Property(title: "Link", description: "The shopping list's page on spoonjoy.app, which only its owner can open.")
    var link: URL
    #else
    @Property(title: "Name")
    var name: String
    @Property(title: "Amount")
    var amount: String
    @Property(title: "Checked")
    var checked: Bool
    @Property(title: "Link")
    var link: URL
    #endif

    var id: String { descriptor.id }
    var shareText: String { "\(descriptor.transferValue.userVisibleSummary)\n\(link.absoluteString)" }
    var transferValue: ShoppingEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: ShoppingItemEntityDescriptor) {
        self.descriptor = descriptor
        name = descriptor.title
        amount = descriptor.subtitle
        checked = descriptor.checked
        link = NativeEntityWebLink.url(for: descriptor.route)
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "\(descriptor.subtitle) - \(descriptor.disambiguationLabel)"
        return DisplayRepresentation(title: "\(descriptor.title)", subtitle: "\(subtitle)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = descriptor.title
        attributes.contentDescription = descriptor.transferValue.userVisibleSummary
        attributes.keywords = [
            descriptor.title,
            descriptor.subtitle,
            descriptor.checked ? "checked shopping item" : "active shopping item",
            "shopping item",
            "Spoonjoy"
        ]
        attributes.contentURL = deepLinkURL
        return attributes
    }

    // Spelled inline with a literal content type: Xcode 27.1's App Intents metadata recorded no content type for the
    // ProxyRepresentation this replaced, so Siri saw the entity as not Transferable.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { entity in Data(entity.shareText.utf8) }
        ProxyRepresentation(exporting: \.link)
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
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptor = try await catalog.shoppingListEntity()
            guard identifiers.isEmpty || identifiers.contains(descriptor.id) else {
                return []
            }
            return [SpoonjoyShoppingListEntity(descriptor: descriptor)]
        }
    }

    func suggestedEntities() async throws -> [SpoonjoyShoppingListEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            return [SpoonjoyShoppingListEntity(descriptor: try await catalog.shoppingListEntity())]
        }
    }

    private func syncStore(fileURL: URL = NativeAppStateLocation.defaultFileURL()) throws -> any NativeSyncStore {
        let appDirectory = fileURL.deletingLastPathComponent()
        return NativeProcessSyncStore.shared(appDirectory: appDirectory)
    }

    private func scope(syncStore: any NativeSyncStore) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        let syncSnapshot = try await syncStore.loadSnapshot()
        return try await SpoonjoyIntentScopeProvider(authVault: SpoonjoyAppTokenVault.current()).trustedIntentScope(from: syncSnapshot)
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyShoppingItemEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyShoppingItemEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.shoppingItemEntities(for: identifiers)
            return descriptors.map(SpoonjoyShoppingItemEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [SpoonjoyShoppingItemEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.shoppingItemEntities(matching: string)
            return descriptors.map(SpoonjoyShoppingItemEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SpoonjoyShoppingItemEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await ShoppingEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.suggestedShoppingItemEntities()
            return descriptors.map(SpoonjoyShoppingItemEntity.init)
        }
    }

    private func syncStore(fileURL: URL = NativeAppStateLocation.defaultFileURL()) throws -> any NativeSyncStore {
        let appDirectory = fileURL.deletingLastPathComponent()
        return NativeProcessSyncStore.shared(appDirectory: appDirectory)
    }

    private func scope(syncStore: any NativeSyncStore) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        let syncSnapshot = try await syncStore.loadSnapshot()
        return try await SpoonjoyIntentScopeProvider(authVault: SpoonjoyAppTokenVault.current()).trustedIntentScope(from: syncSnapshot)
    }
}
#endif
