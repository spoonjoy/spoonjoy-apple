import Foundation

public enum CaptureDraftEntityKind: String, Codable, Equatable, Sendable {
    case captureDraft
}

public enum CaptureDraftEntityCatalogError: Error, Equatable, Sendable {
    case invalidIdentifier(String)
    case unavailableForScope(accountID: String?, environment: NativeCacheEnvironment?)
    case captureDraftNotFound(String)
}

public struct CaptureDraftEntityScope: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment

    public init(accountID: String, environment: NativeCacheEnvironment) {
        self.accountID = accountID
        self.environment = environment
    }

    public var domainIdentifier: String {
        "capture-draft:\(environment.rawValue):\(accountID)"
    }
}

public struct CaptureDraftEntityTransferValue: Codable, Equatable, Sendable {
    public let kind: CaptureDraftEntityKind
    public let rawResourceID: String
    public let title: String
    public let routeIdentifier: String
    public let publicURL: URL?
    public let privateTransferValue: String
    public let userVisibleSummary: String
    public let debugFields: [String]

    public init(
        kind: CaptureDraftEntityKind,
        rawResourceID: String,
        title: String,
        routeIdentifier: String,
        publicURL: URL?,
        privateTransferValue: String,
        userVisibleSummary: String,
        debugFields: [String] = []
    ) {
        self.kind = kind
        self.rawResourceID = rawResourceID
        self.title = title
        self.routeIdentifier = routeIdentifier
        self.publicURL = publicURL
        self.privateTransferValue = privateTransferValue
        self.userVisibleSummary = userVisibleSummary
        self.debugFields = debugFields
    }
}

public struct CaptureDraftEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let captureDraftID: String
    public let scope: CaptureDraftEntityScope
    public let title: String
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let source: CaptureDraftSource
    public let importReadiness: CaptureDraftImportReadiness
    public let hasPendingImport: Bool
    public let importableDraft: CaptureDraft?
    public let pendingImport: NativeQueuedMutation?
    public let transferValue: CaptureDraftEntityTransferValue
    public var isPlaceholder: Bool { id == Self.placeholder.id }

    public static let placeholder = CaptureDraftEntityDescriptor(
        id: "capture-draft-placeholder",
        captureDraftID: "capture-draft-placeholder",
        scope: CaptureDraftEntityScope(accountID: "placeholder", environment: .production),
        title: "Capture Draft",
        subtitle: "Spoonjoy capture draft",
        disambiguationLabel: "Spoonjoy capture draft",
        route: .capture,
        source: .text,
        importReadiness: .ready,
        hasPendingImport: false,
        importableDraft: nil,
        pendingImport: nil,
        transferValue: CaptureDraftEntityTransferValue(
            kind: .captureDraft,
            rawResourceID: "capture-draft-placeholder",
            title: "Capture Draft",
            routeIdentifier: AppRoute.capture.stateIdentifier,
            publicURL: nil,
            privateTransferValue: "schema=app.spoonjoy.capture-draft-entity.v1;domain=capture-draft;title=Capture Draft",
            userVisibleSummary: "Capture Draft"
        )
    )

    public init(
        draft: CaptureDraft,
        scope: CaptureDraftEntityScope,
        hasPendingImport: Bool,
        pendingImport: NativeQueuedMutation? = nil
    ) {
        let payload = NativeSharePayload.privateCaptureDraft(draft)
        let title = payload.title
        let subtitle = Self.subtitle(for: draft, hasPendingImport: hasPendingImport)
        self.init(
            id: CaptureDraftEntityCatalog.captureDraftEntityIdentifier(
                draftID: draft.id,
                accountID: scope.accountID,
                environment: scope.environment
            ),
            captureDraftID: draft.id,
            scope: scope,
            title: title,
            subtitle: subtitle,
            disambiguationLabel: "\(title) from capture",
            route: .capture,
            source: draft.source,
            importReadiness: draft.importReadiness,
            hasPendingImport: hasPendingImport,
            importableDraft: draft,
            pendingImport: pendingImport,
            transferValue: CaptureDraftEntityTransferValue(
                kind: .captureDraft,
                rawResourceID: draft.id,
                title: title,
                routeIdentifier: AppRoute.capture.stateIdentifier,
                publicURL: nil,
                privateTransferValue: payload.serializedTransferValue,
                userVisibleSummary: title
            )
        )
    }

    public init(
        id: String,
        captureDraftID: String,
        scope: CaptureDraftEntityScope,
        title: String,
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute,
        source: CaptureDraftSource,
        importReadiness: CaptureDraftImportReadiness,
        hasPendingImport: Bool,
        importableDraft: CaptureDraft?,
        pendingImport: NativeQueuedMutation?,
        transferValue: CaptureDraftEntityTransferValue
    ) {
        self.id = id
        self.captureDraftID = captureDraftID
        self.scope = scope
        self.title = title
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.source = source
        self.importReadiness = importReadiness
        self.hasPendingImport = hasPendingImport
        self.importableDraft = importableDraft
        self.pendingImport = pendingImport
        self.transferValue = transferValue
    }

    private static func subtitle(for draft: CaptureDraft, hasPendingImport: Bool) -> String {
        let base = "\(sourceLabel(for: draft.source)) draft"
        return hasPendingImport ? "\(base) - pending import" : base
    }

    private static func sourceLabel(for source: CaptureDraftSource) -> String {
        switch source {
        case .text:
            "Text"
        case .url:
            "URL"
        case .image:
            "Image"
        case .cameraImage:
            "Camera image"
        case .photoLibraryImage:
            "Photo library image"
        case .shareSheetURL:
            "Share sheet URL"
        case .jsonLD:
            "JSON-LD"
        case .videoURL:
            "Video URL"
        }
    }
}

public struct CaptureDraftEntityIndexPurgePlan: Equatable, Sendable {
    public enum Reason: String, Codable, Equatable, Sendable {
        case accountScopeChanged
        case cacheDeleted
        case draftDiscarded
    }

    public let identifiers: [String]
    public let domainIdentifiers: [String]
    public let reason: Reason

    public init(identifiers: [String], domainIdentifiers: [String], reason: Reason) {
        self.identifiers = identifiers
        self.domainIdentifiers = domainIdentifiers
        self.reason = reason
    }

    public static func accountScopePurge(
        appSnapshot: NativeAppSnapshot?,
        cacheSnapshot: NativeDurableCacheSnapshot?,
        accountID: String?,
        environment: NativeCacheEnvironment?
    ) -> CaptureDraftEntityIndexPurgePlan {
        let appDraftIDs = appSnapshot?.captureDraft.map { [$0.id] } ?? []
        let cacheDraftIDs = cacheSnapshot?.records.compactMap { record -> String? in
            guard case NativeCacheDomain.captureDraft(let id) = record.metadata.domain else {
                return nil
            }
            return id
        } ?? []
        return scopedPlan(
            accountID: accountID,
            environment: environment,
            draftIDs: appDraftIDs + cacheDraftIDs,
            includeDomain: true,
            reason: .accountScopeChanged
        )
    }

    public static func cacheDeletePurge(
        deletedRecordDomains: [NativeCacheDomain],
        accountID: String?,
        environment: NativeCacheEnvironment?
    ) -> CaptureDraftEntityIndexPurgePlan {
        let draftIDs = deletedRecordDomains.compactMap { domain -> String? in
            guard case .captureDraft(let id) = domain else {
                return nil
            }
            return id
        }
        return scopedPlan(
            accountID: accountID,
            environment: environment,
            draftIDs: draftIDs,
            includeDomain: false,
            reason: .cacheDeleted
        )
    }

    public static func draftDiscardPurge(
        draftID: String,
        accountID: String?,
        environment: NativeCacheEnvironment?
    ) -> CaptureDraftEntityIndexPurgePlan {
        scopedPlan(
            accountID: accountID,
            environment: environment,
            draftIDs: [draftID],
            includeDomain: false,
            reason: .draftDiscarded
        )
    }

    private static func scopedPlan(
        accountID: String?,
        environment: NativeCacheEnvironment?,
        draftIDs: [String],
        includeDomain: Bool,
        reason: Reason
    ) -> CaptureDraftEntityIndexPurgePlan {
        guard let accountID,
              let environment else {
            return CaptureDraftEntityIndexPurgePlan(identifiers: [], domainIdentifiers: [], reason: reason)
        }

        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        let identifiers = CaptureDraftEntityCatalog.uniquePreservingOrder(draftIDs).map { draftID in
            SpotlightIndexPlan.captureDraftUniqueIdentifier(draftID: draftID, scope: spotlightScope)
        }
        let domainIdentifiers = includeDomain ? [SpotlightIndexPlan.captureDraftDomainIdentifier(scope: spotlightScope)] : []
        return CaptureDraftEntityIndexPurgePlan(
            identifiers: identifiers,
            domainIdentifiers: domainIdentifiers,
            reason: reason
        )
    }
}

public struct CaptureDraftEntityCatalog: Sendable {
    private let scope: CaptureDraftEntityScope?
    private let records: [CaptureDraftRecord]

    public init(
        appSnapshot: NativeAppSnapshot?,
        cacheSnapshot: NativeDurableCacheSnapshot?,
        currentAccountID: String?,
        environment: NativeCacheEnvironment
    ) {
        guard let currentAccountID else {
            scope = nil
            records = []
            return
        }

        scope = CaptureDraftEntityScope(accountID: currentAccountID, environment: environment)
        var keyedRecords: [String: CaptureDraftRecord] = [:]

        if let appSnapshot,
           appSnapshot.isScoped(accountID: currentAccountID, environment: environment),
           let draft = appSnapshot.captureDraft {
            let hasProviderBlocker = appSnapshot.captureImportProviderBlocker?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            let pendingImport = Self.pendingImport(appSnapshot.pendingCaptureImport, matches: draft)
            let hasPendingImport = pendingImport != nil || hasProviderBlocker
            keyedRecords[draft.id] = CaptureDraftRecord(draft: draft, hasPendingImport: hasPendingImport, pendingImport: pendingImport)
        }

        if let cacheSnapshot,
           cacheSnapshot.accountID == currentAccountID,
           cacheSnapshot.environment == environment {
            for record in cacheSnapshot.records {
                guard record.metadata.accountID == currentAccountID,
                      record.metadata.environment == environment,
                      case NativeCachePayload.captureDraft(let id, let source) = record.payload,
                      keyedRecords[id] == nil,
                      let draft = Self.captureDraft(id: id, source: source, fetchedAt: record.metadata.fetchedAt) else {
                    continue
                }
                keyedRecords[id] = CaptureDraftRecord(draft: draft, hasPendingImport: false, pendingImport: nil)
            }
        }

        records = keyedRecords.values.sorted { left, right in
            if left.draft.createdAt == right.draft.createdAt {
                return left.draft.id < right.draft.id
            }
            return left.draft.createdAt > right.draft.createdAt
        }
    }

    public static func loading(
        appStateStore: NativeAppStateStore,
        cacheStore: NativeDurableCacheStore,
        currentAccountID: String?,
        environment: NativeCacheEnvironment,
        now: Date = Date()
    ) async throws -> CaptureDraftEntityCatalog {
        let savedAt = isoString(now)
        let appFallback = NativeAppSnapshot
            .bootstrap(
                shoppingList: nil,
                accountID: currentAccountID,
                environment: environment,
                savedAt: savedAt
            )
            .completingFirstRun(savedAt: savedAt)
        let appSnapshot = try appStateStore.loadOrCreate(fallback: appFallback).value
        let cacheFallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: currentAccountID ?? "signed-out",
            environment: environment,
            createdAt: now,
            records: [],
            dismissedIndicators: []
        )
        let cacheSnapshot = try cacheStore.loadOrRecover(fallback: cacheFallback).value
        return CaptureDraftEntityCatalog(
            appSnapshot: appSnapshot,
            cacheSnapshot: cacheSnapshot,
            currentAccountID: currentAccountID,
            environment: environment
        )
    }

    public func captureDraftEntity(id: String) async throws -> CaptureDraftEntityDescriptor {
        let scope = try ensureScopeAvailable()
        let draftID = try canonicalRawCaptureDraftIdentifier(id, scope: scope)
        guard let record = records.first(where: { $0.draft.id == draftID }) else {
            throw CaptureDraftEntityCatalogError.captureDraftNotFound(draftID)
        }
        return CaptureDraftEntityDescriptor(draft: record.draft, scope: scope, hasPendingImport: record.hasPendingImport, pendingImport: record.pendingImport)
    }

    public func captureDraftEntities(for identifiers: [String]) async throws -> [CaptureDraftEntityDescriptor] {
        let scope = try ensureScopeAvailable()
        var entities: [CaptureDraftEntityDescriptor] = []
        for identifier in identifiers {
            guard let draftID = try? Self.resolvedCaptureDraftID(
                from: identifier,
                accountID: scope.accountID,
                environment: scope.environment
            ),
            let record = records.first(where: { $0.draft.id == draftID }) else {
                continue
            }
            entities.append(CaptureDraftEntityDescriptor(draft: record.draft, scope: scope, hasPendingImport: record.hasPendingImport, pendingImport: record.pendingImport))
        }
        return entities
    }

    public func captureDraftEntities(matching string: String) async throws -> [CaptureDraftEntityDescriptor] {
        guard let scope else {
            return []
        }
        let query = normalizedQuery(string)
        let matches = query.isEmpty ? records : records.filter { record in
            let descriptor = CaptureDraftEntityDescriptor(
                draft: record.draft,
                scope: scope,
                hasPendingImport: record.hasPendingImport,
                pendingImport: record.pendingImport
            )
            return descriptor.title.localizedCaseInsensitiveContains(query) ||
                descriptor.subtitle.localizedCaseInsensitiveContains(query) ||
                descriptor.source.rawValue.localizedCaseInsensitiveContains(query)
        }
        return matches.map { CaptureDraftEntityDescriptor(draft: $0.draft, scope: scope, hasPendingImport: $0.hasPendingImport, pendingImport: $0.pendingImport) }
    }

    public func suggestedCaptureDraftEntities(limit: Int = 10) async throws -> [CaptureDraftEntityDescriptor] {
        guard let scope else {
            return []
        }
        return records.prefix(max(0, limit)).map { record in
            CaptureDraftEntityDescriptor(draft: record.draft, scope: scope, hasPendingImport: record.hasPendingImport, pendingImport: record.pendingImport)
        }
    }

    public static func captureDraftEntityIdentifier(
        draftID: String,
        accountID: String,
        environment: NativeCacheEnvironment
    ) -> String {
        "capture-draft:\(environment.rawValue):\(accountID):\(draftID)"
    }

    public static func resolvedCaptureDraftID(
        from identifier: String,
        accountID: String,
        environment: NativeCacheEnvironment
    ) throws -> String {
        let parts = identifier.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4,
              parts[0] == "capture-draft",
              parts[1] == environment.rawValue,
              parts[2] == accountID,
              !parts[3].isEmpty else {
            throw CaptureDraftEntityCatalogError.invalidIdentifier(identifier)
        }
        return parts[3]
    }

    public static func purgeEntityIdentifiers(
        accountID: String,
        environment: NativeCacheEnvironment,
        plan: CaptureDraftEntityIndexPurgePlan
    ) -> [String] {
        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        let expectedPrefix = "\(spotlightScope.identifierPrefix)|\(SpotlightIndexType.captureDraft.rawValue)|"
        guard plan.identifiers.allSatisfy({ $0.hasPrefix(expectedPrefix) }) else {
            return []
        }
        return plan.identifiers
    }

    public static func purgeDomainIdentifiers(
        accountID: String,
        environment: NativeCacheEnvironment,
        plan: CaptureDraftEntityIndexPurgePlan
    ) -> [String] {
        let expectedDomain = SpotlightIndexPlan.captureDraftDomainIdentifier(
            scope: SpotlightIndexScope(accountID: accountID, environment: environment)
        )
        return plan.domainIdentifiers.filter { $0 == expectedDomain }
    }

    public static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func ensureScopeAvailable() throws -> CaptureDraftEntityScope {
        guard let scope else {
            throw CaptureDraftEntityCatalogError.unavailableForScope(accountID: nil, environment: nil)
        }
        return scope
    }

    private func canonicalRawCaptureDraftIdentifier(_ rawValue: String, scope: CaptureDraftEntityScope) throws -> String {
        if let draftID = try? Self.resolvedCaptureDraftID(
            from: rawValue,
            accountID: scope.accountID,
            environment: scope.environment
        ) {
            return draftID
        }

        let id = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !id.isEmpty,
            !id.contains("/"),
            !id.contains("\\"),
            !id.contains(".."),
            id != ".",
            id != "..",
            id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else {
            throw CaptureDraftEntityCatalogError.invalidIdentifier(rawValue)
        }
        return id
    }

    private func normalizedQuery(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func pendingImport(_ mutation: NativeQueuedMutation?, matches draft: CaptureDraft) -> NativeQueuedMutation? {
        guard let mutation,
              let draftImportSource = try? draft.importSource() else {
            return nil
        }
        return mutation.recipeImportSource == draftImportSource ? mutation : nil
    }

    private static func captureDraft(
        id: String,
        source: NativeCaptureDraftCacheSource,
        fetchedAt: Date
    ) -> CaptureDraft? {
        let createdAt = isoString(fetchedAt)
        switch source {
        case .shareSheetURL(let rawURL):
            guard let url = URL(string: rawURL) else {
                return nil
            }
            return try? CaptureDraft.shareSheetURL(id: id, url: url, createdAt: createdAt)
        case .text(let text):
            return try? CaptureDraft.localText(id: id, rawText: text, createdAt: createdAt)
        case .imageAsset:
            return nil
        }
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

private struct CaptureDraftRecord: Sendable {
    let draft: CaptureDraft
    let hasPendingImport: Bool
    let pendingImport: NativeQueuedMutation?
}
