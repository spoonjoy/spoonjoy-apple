import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import UniformTypeIdentifiers
import CoreSpotlight
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoySpoonEntity: AppEntity, IndexedEntity, Transferable {
    typealias DefaultQuery = SpoonjoySpoonEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cook Log")
    static let defaultQuery = SpoonjoySpoonEntityQuery()

    // Only the app needs the descriptor's ids, route and photo URL, so they stay plain members, hidden from Siri.
    let descriptor: SpoonEntityDescriptor

    // What a person asks about a cook log. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Recipe", description: "The recipe that was cooked.")
    var recipe: String
    @Property(title: "Chef", description: "The username of the chef who cooked it.")
    var chef: String
    @Property(title: "Cooked", description: "When it was cooked.")
    var cooked: Date?
    @Property(title: "Note", description: "What the cook wrote about how it went.")
    var note: String?
    @Property(title: "Next time", description: "What the cook wants to change next time.")
    var nextTime: String?
    @Property(title: "Link", description: "The cooked recipe's page on spoonjoy.app.")
    var link: URL
    #else
    @Property(title: "Recipe")
    var recipe: String
    @Property(title: "Chef")
    var chef: String
    @Property(title: "Cooked")
    var cooked: Date?
    @Property(title: "Note")
    var note: String?
    @Property(title: "Next time")
    var nextTime: String?
    @Property(title: "Link")
    var link: URL
    #endif

    var id: String { descriptor.id }
    var shareText: String { "\(descriptor.transferValue.userVisibleSummary)\n\(link.absoluteString)" }
    var transferValue: SpoonEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: SpoonEntityDescriptor) {
        self.descriptor = descriptor
        recipe = descriptor.recipeTitle
        chef = descriptor.chefUsername
        cooked = descriptor.cookedDate
        note = descriptor.note
        nextTime = descriptor.nextTime
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
            descriptor.recipeTitle,
            descriptor.chefUsername,
            descriptor.subtitle,
            "cook log",
            "spoon",
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
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await SpoonEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.spoonEntities(for: identifiers)
            return descriptors.map(SpoonjoySpoonEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [SpoonjoySpoonEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await SpoonEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.spoonEntities(matching: string)
            return descriptors.map(SpoonjoySpoonEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SpoonjoySpoonEntity] {
        try await IntentEntityQueryAccess.results {
            let syncStore = try syncStore()
            let scope = try await scope(syncStore: syncStore)
            let catalog = try await SpoonEntityCatalog.loading(syncStore: syncStore, currentAccountID: scope.accountID, environment: scope.environment)
            let descriptors = try await catalog.suggestedSpoonEntities()
            return descriptors.map(SpoonjoySpoonEntity.init)
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
