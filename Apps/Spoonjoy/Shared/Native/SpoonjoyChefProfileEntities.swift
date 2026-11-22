import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import UniformTypeIdentifiers
import CoreSpotlight
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyChefProfileEntity: AppEntity, IndexedEntity, Transferable {
    typealias DefaultQuery = SpoonjoyChefProfileEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Chef Profile")
    static let defaultQuery = SpoonjoyChefProfileEntityQuery()

    // Only the app needs the descriptor's ids, route and photo URL, so they stay plain members, hidden from Siri.
    let descriptor: ChefProfileEntityDescriptor

    // What a person asks about a chef. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Username", description: "The chef's Spoonjoy username.")
    var username: String
    @Property(title: "Fellow chefs", description: "How many chefs this chef has cooked, forked or saved recipes from.")
    var fellowChefs: Int
    @Property(title: "Kitchen visitors", description: "How many chefs have cooked, forked or saved this chef's recipes.")
    var kitchenVisitors: Int
    @Property(title: "Link", description: "The chef's profile page on spoonjoy.app.")
    var link: URL
    #else
    @Property(title: "Username")
    var username: String
    @Property(title: "Fellow chefs")
    var fellowChefs: Int
    @Property(title: "Kitchen visitors")
    var kitchenVisitors: Int
    @Property(title: "Link")
    var link: URL
    #endif

    var id: String { descriptor.id }
    var shareText: String { "\(descriptor.transferValue.userVisibleSummary)\n\(link.absoluteString)" }
    var transferValue: ChefProfileEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: ChefProfileEntityDescriptor) {
        self.descriptor = descriptor
        username = descriptor.username
        fellowChefs = descriptor.fellowChefsCount
        kitchenVisitors = descriptor.kitchenVisitorsCount
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
            descriptor.username,
            descriptor.subtitle,
            descriptor.interactionSummary ?? "",
            "\(descriptor.fellowChefsCount) fellow chefs",
            "\(descriptor.kitchenVisitorsCount) kitchen visitors",
            "chef profile",
            "Spoonjoy"
        ].filter { !$0.isEmpty }
        attributes.contentURL = deepLinkURL
        return attributes
    }

    // Spelled inline with a literal content type: Xcode 27.1's App Intents metadata recorded no content type for the
    // ProxyRepresentation this replaced, so Siri saw the entity as not Transferable.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { entity in Data(entity.shareText.utf8) }
        ProxyRepresentation(exporting: \.link)
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
        try await IntentEntityQueryAccess.results {
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
    }

    func entities(matching string: String) async throws -> [SpoonjoyChefProfileEntity] {
        try await IntentEntityQueryAccess.results {
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
    }

    func suggestedEntities() async throws -> [SpoonjoyChefProfileEntity] {
        try await IntentEntityQueryAccess.results {
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
    }

    private func catalogInputs(
        fileURL: URL = NativeAppStateLocation.defaultFileURL()
    ) async throws -> (
        syncStore: any NativeSyncStore,
        cacheStore: NativeDurableCacheStore,
        scope: (accountID: String, environment: NativeCacheEnvironment)
    ) {
        let appDirectory = fileURL.deletingLastPathComponent()
        let syncStore = NativeProcessSyncStore.shared(appDirectory: appDirectory)
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await SpoonjoyIntentScopeProvider(authVault: SpoonjoyAppTokenVault.current()).trustedIntentScope(from: syncSnapshot)
        let cacheStore = NativeDurableCacheStore(fileURL: appDirectory.appendingPathComponent("native-durable-cache.json"))
        return (syncStore, cacheStore, scope)
    }
}
#endif
