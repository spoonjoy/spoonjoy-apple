import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import UniformTypeIdentifiers
import CoreSpotlight
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCaptureDraftEntity: AppEntity, IndexedEntity, Transferable {
    typealias DefaultQuery = SpoonjoyCaptureDraftEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Capture Draft")
    static let defaultQuery = SpoonjoyCaptureDraftEntityQuery()

    // Only the app needs the descriptor's ids, route and the draft's contents, so they stay plain members, hidden from Siri.
    let descriptor: CaptureDraftEntityDescriptor

    // What a person asks about a capture draft. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Title", description: "The draft's working title.")
    var title: String
    @Property(title: "Source", description: "Where the draft came from, such as a photo, a web page or text.")
    var source: String
    @Property(title: "Ready to import", description: "Whether the draft can be turned into a recipe now, without reading text from a photo first.")
    var readyToImport: Bool
    #else
    @Property(title: "Title")
    var title: String
    @Property(title: "Source")
    var source: String
    @Property(title: "Ready to import")
    var readyToImport: Bool
    #endif

    var id: String { descriptor.id }
    var shareText: String { descriptor.transferValue.userVisibleSummary }
    var transferValue: CaptureDraftEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        self.init(descriptor: .placeholder)
    }

    init(descriptor: CaptureDraftEntityDescriptor) {
        self.descriptor = descriptor
        title = descriptor.title
        source = descriptor.source.label
        readyToImport = descriptor.importReadiness == .ready
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
            descriptor.importReadiness.rawValue,
            descriptor.hasPendingImport ? "pending import" : "ready import",
            "capture draft",
            "Spoonjoy"
        ]
        attributes.contentURL = deepLinkURL
        return attributes
    }

    // Spelled inline with a literal content type: Xcode 27.1's App Intents metadata recorded no content type for the
    // ProxyRepresentation this replaced, so Siri saw the entity as not Transferable. A draft lives only on this device, so
    // it has no spoonjoy.app link to carry.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { entity in Data(entity.shareText.utf8) }
    }

    func resolvedCaptureDraftID() throws -> String {
        guard !descriptor.isPlaceholder else {
            throw NativeIntentActionError.unresolvedCaptureDraftEntity
        }
        return descriptor.captureDraftID
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCaptureDraftEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpoonjoyCaptureDraftEntity] {
        try await IntentEntityQueryAccess.results {
            let inputs = try await catalogInputs()
            let catalog = try await CaptureDraftEntityCatalog.loading(
                appStateStore: inputs.appStateStore,
                cacheStore: inputs.cacheStore,
                currentAccountID: inputs.scope.accountID,
                environment: inputs.scope.environment
            )
            let descriptors = try await catalog.captureDraftEntities(for: identifiers)
            return descriptors.map(SpoonjoyCaptureDraftEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [SpoonjoyCaptureDraftEntity] {
        try await IntentEntityQueryAccess.results {
            let inputs = try await catalogInputs()
            let catalog = try await CaptureDraftEntityCatalog.loading(
                appStateStore: inputs.appStateStore,
                cacheStore: inputs.cacheStore,
                currentAccountID: inputs.scope.accountID,
                environment: inputs.scope.environment
            )
            let descriptors = try await catalog.captureDraftEntities(matching: string)
            return descriptors.map(SpoonjoyCaptureDraftEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SpoonjoyCaptureDraftEntity] {
        try await IntentEntityQueryAccess.results {
            let inputs = try await catalogInputs()
            let catalog = try await CaptureDraftEntityCatalog.loading(
                appStateStore: inputs.appStateStore,
                cacheStore: inputs.cacheStore,
                currentAccountID: inputs.scope.accountID,
                environment: inputs.scope.environment
            )
            let descriptors = try await catalog.suggestedCaptureDraftEntities()
            return descriptors.map(SpoonjoyCaptureDraftEntity.init)
        }
    }

    private func catalogInputs(
        fileURL: URL = NativeAppStateLocation.defaultFileURL()
    ) async throws -> (
        appStateStore: NativeAppStateStore,
        cacheStore: NativeDurableCacheStore,
        scope: (accountID: String, environment: NativeCacheEnvironment)
    ) {
        let appDirectory = fileURL.deletingLastPathComponent()
        let syncStore = NativeProcessSyncStore.shared(appDirectory: appDirectory)
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await SpoonjoyIntentScopeProvider(authVault: SpoonjoyAppTokenVault.current()).trustedIntentScope(from: syncSnapshot)
        let appStateStore = NativeAppStateStore(fileURL: fileURL)
        let cacheStore = NativeDurableCacheStore(fileURL: appDirectory.appendingPathComponent("native-durable-cache.json"))
        return (appStateStore, cacheStore, scope)
    }
}
#endif
