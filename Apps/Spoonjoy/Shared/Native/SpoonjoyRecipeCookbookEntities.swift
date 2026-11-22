import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import CoreSpotlight
import CoreTransferable
import UniformTypeIdentifiers

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyRecipeEntity: AppEntity, IndexedEntity, Transferable {
    typealias DefaultQuery = SpoonjoyRecipeEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
    static let defaultQuery = SpoonjoyRecipeEntityQuery()

    // Only the app needs the descriptor's ids, route and cover URL, so they stay plain members, hidden from Siri.
    let descriptor: RecipeEntityDescriptor

    // What a person asks about a recipe. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Title", description: "The recipe's name.")
    var title: String
    @Property(title: "Chef", description: "The username of the chef who wrote the recipe.")
    var chef: String
    @Property(title: "Servings", description: "How many people the recipe serves, as the chef wrote it.")
    var servings: String?
    @Property(title: "Steps", description: "How many steps the recipe has.")
    var stepCount: Int
    @Property(title: "Cookbooks", description: "The cookbooks the recipe is in.")
    var cookbooks: [String]
    @Property(title: "Link", description: "The recipe's page on spoonjoy.app.")
    var link: URL
    #else
    @Property(title: "Title")
    var title: String
    @Property(title: "Chef")
    var chef: String
    @Property(title: "Servings")
    var servings: String?
    @Property(title: "Steps")
    var stepCount: Int
    @Property(title: "Cookbooks")
    var cookbooks: [String]
    @Property(title: "Link")
    var link: URL
    #endif

    var id: String { descriptor.entityIdentifier }
    var transferValue: RecipeCookbookEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }
    var shareText: String { "\(descriptor.transferValue.userVisibleSummary)\n\(link.absoluteString)" }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: RecipeEntityDescriptor) {
        self.descriptor = descriptor
        title = descriptor.title
        chef = descriptor.chefUsername
        servings = descriptor.servings
        stepCount = descriptor.stepCount
        cookbooks = descriptor.cookbookTitles
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
            descriptor.chefUsername,
            descriptor.subtitle,
            "recipe",
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

    func resolvedRecipeID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedRecipeEntity
        }
        return descriptor.id
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCookbookEntity: AppEntity, IndexedEntity, Transferable {
    typealias DefaultQuery = SpoonjoyCookbookEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cookbook")
    static let defaultQuery = SpoonjoyCookbookEntityQuery()

    // Only the app needs the descriptor's ids, route and cover URL, so they stay plain members, hidden from Siri.
    let descriptor: CookbookEntityDescriptor

    // What a person asks about a cookbook. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Title", description: "The cookbook's name.")
    var title: String
    @Property(title: "Chef", description: "The username of the chef whose cookbook it is.")
    var chef: String
    @Property(title: "Recipes", description: "How many recipes the cookbook holds.")
    var recipeCount: Int
    @Property(title: "Link", description: "The cookbook's page on spoonjoy.app.")
    var link: URL
    #else
    @Property(title: "Title")
    var title: String
    @Property(title: "Chef")
    var chef: String
    @Property(title: "Recipes")
    var recipeCount: Int
    @Property(title: "Link")
    var link: URL
    #endif

    var id: String { descriptor.entityIdentifier }
    var transferValue: RecipeCookbookEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }
    var shareText: String { "\(descriptor.transferValue.userVisibleSummary)\n\(link.absoluteString)" }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: CookbookEntityDescriptor) {
        self.descriptor = descriptor
        title = descriptor.title
        chef = descriptor.chefUsername
        recipeCount = descriptor.recipeCount
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
            descriptor.chefUsername,
            descriptor.subtitle,
            "\(descriptor.recipeCount) recipes",
            "cookbook",
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

    func resolvedCookbookID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedCookbookEntity
        }
        return descriptor.id
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyRecipeEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyRecipeEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.recipeEntities(for: identifiers)
            return descriptors.map(SpoonjoyRecipeEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [SpoonjoyRecipeEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.recipeEntities(matching: string)
            return descriptors.map(SpoonjoyRecipeEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SpoonjoyRecipeEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.suggestedRecipeEntities()
            return descriptors.map(SpoonjoyRecipeEntity.init)
        }
    }

    private func syncStore() throws -> any NativeSyncStore {
        try SpoonjoyIntentSyncStoreFactory.syncStore()
    }

    private func scope(syncStore: any NativeSyncStore) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        let syncSnapshot = try await syncStore.loadSnapshot()
        return try await SpoonjoyIntentScopeProvider(authVault: SpoonjoyAppTokenVault.current()).trustedIntentScope(from: syncSnapshot)
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCookbookEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyCookbookEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.cookbookEntities(for: identifiers)
            return descriptors.map(SpoonjoyCookbookEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [SpoonjoyCookbookEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.cookbookEntities(matching: string)
            return descriptors.map(SpoonjoyCookbookEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SpoonjoyCookbookEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await RecipeCookbookEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.suggestedCookbookEntities()
            return descriptors.map(SpoonjoyCookbookEntity.init)
        }
    }

    private func syncStore() throws -> any NativeSyncStore {
        try SpoonjoyIntentSyncStoreFactory.syncStore()
    }

    private func scope(syncStore: any NativeSyncStore) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        let syncSnapshot = try await syncStore.loadSnapshot()
        return try await SpoonjoyIntentScopeProvider(authVault: SpoonjoyAppTokenVault.current()).trustedIntentScope(from: syncSnapshot)
    }
}

struct SpoonjoyIntentSyncStoreFactory {
    static func syncStore(fileURL: URL = NativeAppStateLocation.defaultFileURL()) throws -> any NativeSyncStore {
        let appDirectory = fileURL.deletingLastPathComponent()
        return NativeProcessSyncStore.shared(appDirectory: appDirectory)
    }
}

struct SpoonjoyIntentScopeProvider {
    private let authVault: (any TokenVault)?

    init(authVault: (any TokenVault)? = SpoonjoyAppTokenVault.current()) {
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
