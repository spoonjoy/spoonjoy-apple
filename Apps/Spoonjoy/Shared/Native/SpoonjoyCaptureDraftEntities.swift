import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import CoreSpotlight
import CoreTransferable

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCaptureDraftEntity: AppEntity, IndexedEntity, Transferable {
    typealias DefaultQuery = SpoonjoyCaptureDraftEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Capture Draft")
    static let defaultQuery = SpoonjoyCaptureDraftEntityQuery()

    let descriptor: CaptureDraftEntityDescriptor

    var id: String { descriptor.id }
    var transferValue: CaptureDraftEntityTransferValue { descriptor.transferValue }
    var deepLinkURL: URL { DeepLinkURLBuilder.url(for: descriptor.route) }

    init() {
        descriptor = .placeholder
    }

    init(descriptor: CaptureDraftEntityDescriptor) {
        self.descriptor = descriptor
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

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.descriptor.transferValue.userVisibleSummary)
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

    func entities(matching string: String) async throws -> [SpoonjoyCaptureDraftEntity] {
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

    func suggestedEntities() async throws -> [SpoonjoyCaptureDraftEntity] {
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

    private func catalogInputs(
        fileURL: URL = NativeAppStateLocation.defaultFileURL()
    ) async throws -> (
        appStateStore: NativeAppStateStore,
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
        let appStateStore = NativeAppStateStore(fileURL: fileURL)
        let cacheStore = NativeDurableCacheStore(fileURL: appDirectory.appendingPathComponent("native-durable-cache.json"))
        return (appStateStore, cacheStore, scope)
    }
}
#endif
