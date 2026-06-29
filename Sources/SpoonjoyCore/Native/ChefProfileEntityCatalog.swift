import Foundation

public enum ChefProfileEntityKind: String, Codable, Equatable, Sendable {
    case chefProfile = "chef-profile"
}

public enum ChefProfileEntityCatalogError: Error, Equatable, Sendable {
    case invalidIdentifier(String)
    case unavailableForScope(accountID: String?, environment: NativeCacheEnvironment?)
    case profileNotFound(String)
    case undecodableRecord(kind: NativeSyncEntryKind, resourceID: String)
}

public struct ChefProfileEntityScope: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment

    public init(accountID: String, environment: NativeCacheEnvironment) {
        self.accountID = accountID
        self.environment = environment
    }
}

public struct ChefProfileEntityTransferValue: Codable, Equatable, Sendable {
    public let kind: ChefProfileEntityKind
    public let profileID: String
    public let username: String
    public let title: String
    public let routeIdentifier: String
    public let canonicalURL: URL
    public let photoURL: URL?
    public let userVisibleSummary: String
    public let debugFields: [String]

    public init(
        kind: ChefProfileEntityKind,
        profileID: String,
        username: String,
        title: String,
        routeIdentifier: String,
        canonicalURL: URL,
        photoURL: URL?,
        userVisibleSummary: String,
        debugFields: [String] = []
    ) {
        self.kind = kind
        self.profileID = profileID
        self.username = username
        self.title = title
        self.routeIdentifier = routeIdentifier
        self.canonicalURL = canonicalURL
        self.photoURL = photoURL
        self.userVisibleSummary = userVisibleSummary
        self.debugFields = debugFields
    }
}

public struct ChefProfileEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let profileID: String
    public let username: String
    public let title: String
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let canonicalURL: URL
    public let photoURL: URL?
    public let fellowChefsCount: Int
    public let kitchenVisitorsCount: Int
    public let interactionSummary: String?
    public let transferValue: ChefProfileEntityTransferValue
    public var isPlaceholder: Bool { id == Self.placeholder.id }

    public static let placeholder = ChefProfileEntityDescriptor(
        id: "chef-profile-placeholder",
        profileID: "chef-profile-placeholder",
        username: "Spoonjoy",
        title: "Chef Profile",
        subtitle: "Spoonjoy chef profile",
        disambiguationLabel: "Spoonjoy chef profile",
        route: .profile(identifier: "Spoonjoy"),
        canonicalURL: URL(string: "https://spoonjoy.app/users/Spoonjoy")!,
        photoURL: nil,
        fellowChefsCount: 0,
        kitchenVisitorsCount: 0,
        interactionSummary: nil,
        transferValue: ChefProfileEntityTransferValue(
            kind: .chefProfile,
            profileID: "chef-profile-placeholder",
            username: "Spoonjoy",
            title: "Chef Profile",
            routeIdentifier: AppRoute.profile(identifier: "Spoonjoy").stateIdentifier,
            canonicalURL: URL(string: "https://spoonjoy.app/users/Spoonjoy")!,
            photoURL: nil,
            userVisibleSummary: "Spoonjoy chef profile"
        )
    )

    fileprivate init(record: ChefProfileRecord) {
        let profile = record.profile.withNormalizedProfileLink()
        let route = AppRoute.profile(identifier: profile.username)
        let summary = "\(profile.username) on Spoonjoy"
        let subtitle = record.relationship.map { "\($0.title) - \(record.interactionSummary ?? "No interactions yet")" } ?? profile.joinedLabel
        _ = DeepLinkURLBuilder.url(for: route)

        self.init(
            id: profile.id,
            profileID: profile.id,
            username: profile.username,
            title: profile.username,
            subtitle: subtitle,
            disambiguationLabel: summary,
            route: route,
            canonicalURL: profile.canonicalURL,
            photoURL: profile.photoURL,
            fellowChefsCount: record.fellowChefsCount,
            kitchenVisitorsCount: record.kitchenVisitorsCount,
            interactionSummary: record.interactionSummary,
            transferValue: ChefProfileEntityTransferValue(
                kind: .chefProfile,
                profileID: profile.id,
                username: profile.username,
                title: profile.username,
                routeIdentifier: route.stateIdentifier,
                canonicalURL: profile.canonicalURL,
                photoURL: profile.photoURL,
                userVisibleSummary: summary
            )
        )
    }

    public init(
        id: String,
        profileID: String,
        username: String,
        title: String,
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute,
        canonicalURL: URL,
        photoURL: URL?,
        fellowChefsCount: Int,
        kitchenVisitorsCount: Int,
        interactionSummary: String?,
        transferValue: ChefProfileEntityTransferValue
    ) {
        self.id = id
        self.profileID = profileID
        self.username = username
        self.title = title
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.canonicalURL = canonicalURL
        self.photoURL = photoURL
        self.fellowChefsCount = fellowChefsCount
        self.kitchenVisitorsCount = kitchenVisitorsCount
        self.interactionSummary = interactionSummary
        self.transferValue = transferValue
    }
}

public struct ChefProfileEntityCatalog: Sendable {
    private let scope: ChefProfileEntityScope?
    private let records: [ChefProfileRecord]

    public init(
        syncSnapshot: NativeSyncSnapshot,
        cacheSnapshot: NativeDurableCacheSnapshot? = nil,
        currentAccountID: String?,
        environment: NativeCacheEnvironment
    ) {
        guard syncSnapshot.accountID == currentAccountID,
              syncSnapshot.environment == environment,
              let accountID = currentAccountID else {
            scope = nil
            records = []
            return
        }

        let scope = ChefProfileEntityScope(accountID: accountID, environment: environment)
        self.scope = scope
        let tombstones: [NativeSyncTombstone] = syncSnapshot.tombstones
        let tombstonedProfiles = Set(tombstones.compactMap { tombstone in
            tombstone.resourceType == NativeSyncResourceType.profile ? tombstone.resourceID : nil
        })
        let tombstonedRecipes = Set(tombstones.compactMap { tombstone in
            tombstone.resourceType == NativeSyncResourceType.recipe ? tombstone.resourceID : nil
        })
        let profileRecords = syncSnapshot.cachedRecords.filter { $0.kind == NativeSyncEntryKind.profile }
            .filter { !tombstonedProfiles.contains($0.resourceID) }
        let recipes = syncSnapshot.cachedRecords
            .filter { $0.kind == NativeSyncEntryKind.recipe }
            .filter { !tombstonedRecipes.contains($0.resourceID) }
            .compactMap { Self.decode(Recipe.self, from: $0) }
        let cachedProfileRecords = Self.cacheProfileRecords(
            cacheSnapshot: cacheSnapshot,
            accountID: accountID,
            environment: environment
        ).filter { !tombstonedProfiles.contains($0.profile.id) }
        var orderedIDs: [String] = []
        var recordsByID: [String: ChefProfileRecord] = [:]

        func upsert(_ record: ChefProfileRecord) {
            if var existing = recordsByID[record.profile.id] {
                existing.merge(record)
                recordsByID[record.profile.id] = existing
            } else {
                orderedIDs.append(record.profile.id)
                recordsByID[record.profile.id] = record
            }
        }

        for record in profileRecords.compactMap(Self.profileRecord(syncRecord:)) {
            upsert(record)
        }
        for record in profileRecords.flatMap({ Self.profileGraphRecords(syncRecord: $0, tombstonedProfileIDs: tombstonedProfiles) }) {
            upsert(record)
        }
        for record in cachedProfileRecords {
            upsert(record)
        }
        for record in Self.profileGraphRecords(
            recipes: recipes,
            ownerProfileID: Self.ownerProfileID(recordsByID.values),
            tombstonedProfileIDs: tombstonedProfiles
        ) {
            upsert(record)
        }

        records = orderedIDs.compactMap { recordsByID[$0] }
    }

    public static func loading(
        syncStore: any NativeSyncStore,
        cacheStore: NativeDurableCacheStore,
        currentAccountID: String?,
        environment: NativeCacheEnvironment
    ) async throws -> ChefProfileEntityCatalog {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let cacheFallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: currentAccountID ?? "signed-out",
            environment: environment,
            createdAt: Date(),
            records: [],
            dismissedIndicators: []
        )
        let cacheSnapshot = try cacheStore.loadOrRecover(fallback: cacheFallback).value
        return ChefProfileEntityCatalog(
            syncSnapshot: syncSnapshot,
            cacheSnapshot: cacheSnapshot,
            currentAccountID: currentAccountID,
            environment: environment
        )
    }

    public func chefProfileEntity(id: String) async throws -> ChefProfileEntityDescriptor {
        _ = try ensureScopeAvailable()
        let identifier = try canonicalProfileIdentifier(id)
        guard let record = record(matching: identifier) else {
            throw ChefProfileEntityCatalogError.profileNotFound(identifier)
        }
        return ChefProfileEntityDescriptor(record: record)
    }

    public func chefProfileEntities(for identifiers: [String]) async throws -> [ChefProfileEntityDescriptor] {
        guard scope != nil else {
            return []
        }
        return identifiers.compactMap { identifier in
            guard let canonical = try? canonicalProfileIdentifier(identifier),
                  let record = record(matching: canonical) else {
                return nil
            }
            return ChefProfileEntityDescriptor(record: record)
        }
    }

    public func chefProfileEntities(matching string: String) async throws -> [ChefProfileEntityDescriptor] {
        guard scope != nil else {
            return []
        }
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? records : records.filter { record in
            record.profile.id.localizedCaseInsensitiveContains(query) ||
                record.profile.username.localizedCaseInsensitiveContains(query) ||
                record.profile.joinedLabel.localizedCaseInsensitiveContains(query) ||
                record.interactionSummary?.localizedCaseInsensitiveContains(query) == true
        }
        return matches.map(ChefProfileEntityDescriptor.init)
    }

    public func suggestedChefProfileEntities(limit: Int = 10) async throws -> [ChefProfileEntityDescriptor] {
        guard scope != nil else {
            return []
        }
        return records.prefix(max(0, limit)).map(ChefProfileEntityDescriptor.init)
    }

    public static func resolvedChefProfileID(from identifier: String) throws -> String {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AppRoute.isSafeProfileIdentifier(id) else {
            throw ChefProfileEntityCatalogError.invalidIdentifier(identifier)
        }
        return id
    }

    private func ensureScopeAvailable() throws -> ChefProfileEntityScope {
        guard let scope else {
            throw ChefProfileEntityCatalogError.unavailableForScope(accountID: nil, environment: nil)
        }
        return scope
    }

    private func canonicalProfileIdentifier(_ identifier: String) throws -> String {
        try Self.resolvedChefProfileID(from: identifier)
    }

    private func record(matching identifier: String) -> ChefProfileRecord? {
        records.first { record in
            record.profile.id.caseInsensitiveCompare(identifier) == .orderedSame ||
                record.profile.username.caseInsensitiveCompare(identifier) == .orderedSame
        }
    }

    private static func cacheProfileRecords(
        cacheSnapshot: NativeDurableCacheSnapshot?,
        accountID: String,
        environment: NativeCacheEnvironment
    ) -> [ChefProfileRecord] {
        guard let cacheSnapshot,
              cacheSnapshot.accountID == accountID,
              cacheSnapshot.environment == environment else {
            return []
        }
        return cacheSnapshot.records.compactMap { record in
            guard record.metadata.accountID == accountID,
                  record.metadata.environment == environment,
                  case NativeCachePayload.profile(let id, let username) = record.payload else {
                return nil
            }
            return ChefProfileRecord(profile: profileSummary(id: id, username: username))
        }
    }

    private static func profileRecord(syncRecord record: NativeSyncCachedRecord) -> ChefProfileRecord? {
        if let result = decode(ProfileSurfaceResult.self, from: record) {
            return ChefProfileRecord(
                profile: result.data.profile,
                fellowChefsCount: result.data.fellowChefsCount,
                kitchenVisitorsCount: result.data.kitchenVisitorsCount,
                isOwner: result.data.isOwner
            )
        }
        if let data = decode(ProfileSurfaceData.self, from: record) {
            return ChefProfileRecord(
                profile: data.profile,
                fellowChefsCount: data.fellowChefsCount,
                kitchenVisitorsCount: data.kitchenVisitorsCount,
                isOwner: data.isOwner
            )
        }
        if let profile = decode(ProfileSummary.self, from: record) {
            return ChefProfileRecord(profile: profile)
        }
        return profileSummary(resourceID: record.resourceID, payload: record.payload).map { ChefProfileRecord(profile: $0) }
    }

    private static func profileGraphRecords(
        syncRecord record: NativeSyncCachedRecord,
        tombstonedProfileIDs: Set<String>
    ) -> [ChefProfileRecord] {
        guard let page = decode(ProfileGraphPage.self, from: record) else {
            return []
        }
        let relationship: ChefProfileRelationship = page.direction == .fellowChefs ? .fellowChefs : .kitchenVisitors
        return graphRows(from: page).filter { !tombstonedProfileIDs.contains($0.chefID) }.map { row in
            ChefProfileRecord(
                profile: ProfileSummary(
                    id: row.chefID,
                    username: row.username,
                    photoURL: row.photoURL,
                    joinedLabel: "Joined Spoonjoy",
                    href: row.href,
                    canonicalURL: row.canonicalURL
                ),
                relationship: relationship,
                interactionSummary: row.interactionSummary == "No interactions yet" ? nil : row.interactionSummary
            )
        }
    }

    private static func profileGraphRecords(
        recipes: [Recipe],
        ownerProfileID: String?,
        tombstonedProfileIDs: Set<String>
    ) -> [ChefProfileRecord] {
        guard let ownerProfileID else {
            return []
        }
        var fellowChefs: [String: ChefProfileInteractionAggregate] = [:]
        var kitchenVisitors: [String: ChefProfileInteractionAggregate] = [:]

        for recipe in recipes {
            for spoon in recipe.recentSpoons where spoon.deletedAt == nil {
                if recipe.chef.id != ownerProfileID,
                   spoon.chef.id == ownerProfileID,
                   !tombstonedProfileIDs.contains(recipe.chef.id) {
                    fellowChefs[recipe.chef.id, default: ChefProfileInteractionAggregate(chef: recipe.chef)].record(spoon: spoon)
                }
                if recipe.chef.id == ownerProfileID,
                   spoon.chef.id != ownerProfileID,
                   !tombstonedProfileIDs.contains(spoon.chef.id) {
                    kitchenVisitors[spoon.chef.id, default: ChefProfileInteractionAggregate(chef: spoon.chef)].record(spoon: spoon)
                }
            }
        }

        return records(
            from: fellowChefs.values,
            relationship: .fellowChefs
        ) + records(
            from: kitchenVisitors.values,
            relationship: .kitchenVisitors
        )
    }

    private static func records(
        from aggregates: Dictionary<String, ChefProfileInteractionAggregate>.Values,
        relationship: ChefProfileRelationship
    ) -> [ChefProfileRecord] {
        let graphDirection = relationship.graphDirection
        let normalizedRelationship: ChefProfileRelationship = graphDirection == ProfileGraphDirection.fellowChefs ? .fellowChefs : .kitchenVisitors
        return aggregates
            .sorted { lhs, rhs in
                if lhs.latestInteractionAt == rhs.latestInteractionAt {
                    return lhs.chef.id < rhs.chef.id
                }
                return lhs.latestInteractionAt > rhs.latestInteractionAt
            }
            .map { aggregate in
                let row = ProfileGraphRow(
                    chefID: aggregate.chef.id,
                    username: aggregate.chef.username,
                    photoURL: aggregate.chef.photoURL,
                    href: "/users/\(AppRoute.encodedProfileIdentifier(aggregate.chef.username))",
                    canonicalURL: profileURL(username: aggregate.chef.username),
                    interactionCounts: ProfileGraphInteractionCounts(
                        spoons: aggregate.spoons,
                        forks: 0,
                        cookbookSaves: 0
                    ),
                    latestInteractionAt: aggregate.latestInteractionAt
                )
                return ChefProfileRecord(
                    profile: ProfileSummary(
                        id: row.chefID,
                        username: row.username,
                        photoURL: row.photoURL,
                        joinedLabel: "Joined Spoonjoy",
                        href: row.href,
                        canonicalURL: row.canonicalURL
                    ),
                    relationship: normalizedRelationship,
                    interactionSummary: row.interactionSummary
                )
            }
    }

    private static func ownerProfileID(_ records: Dictionary<String, ChefProfileRecord>.Values) -> String? {
        records.first(where: \.isOwner)?.profile.id
    }

    private static func profileSummary(resourceID: String, payload: JSONValue) -> ProfileSummary? {
        guard case .object(let fields) = payload,
              case .string(let username)? = fields["username"],
              !resourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              AppRoute.isSafeProfileIdentifier(username) else {
            return nil
        }
        let photoURL: URL?
        if case .string(let photoURLRaw)? = fields["photoUrl"] {
            photoURL = URL(string: photoURLRaw)
        } else {
            photoURL = nil
        }
        let joinedLabel: String
        if case .string(let rawJoinedLabel)? = fields["joinedLabel"],
           !rawJoinedLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            joinedLabel = rawJoinedLabel
        } else {
            joinedLabel = "Joined Spoonjoy"
        }
        return profileSummary(id: resourceID, username: username, photoURL: photoURL, joinedLabel: joinedLabel)
    }

    private static func profileSummary(
        id: String,
        username: String,
        photoURL: URL? = nil,
        joinedLabel: String = "Joined Spoonjoy"
    ) -> ProfileSummary {
        ProfileSummary(
            id: id,
            username: username,
            photoURL: photoURL,
            joinedLabel: joinedLabel,
            href: "/users/\(AppRoute.encodedProfileIdentifier(username))",
            canonicalURL: profileURL(username: username)
        )
    }

    private static func profileURL(username: String) -> URL {
        URL(string: "https://spoonjoy.app/users/\(AppRoute.encodedProfileIdentifier(username))")!
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from record: NativeSyncCachedRecord) -> Value? {
        try? JSONDecoder().decode(type, from: JSONEncoder().encode(record.payload))
    }

    private static func graphRows(from page: ProfileGraphPage) -> [ProfileGraphRow] {
        page.rows
    }
}

private enum ChefProfileRelationship: Sendable {
    case fellowChefs
    case kitchenVisitors

    var title: String {
        switch self {
        case .fellowChefs:
            "Fellow chef"
        case .kitchenVisitors:
            "Kitchen visitor"
        }
    }

    var graphDirection: ProfileGraphDirection {
        switch self {
        case .fellowChefs:
            ProfileGraphDirection.fellowChefs
        case .kitchenVisitors:
            ProfileGraphDirection.kitchenVisitors
        }
    }
}

private struct ChefProfileRecord: Sendable {
    var profile: ProfileSummary
    var fellowChefsCount: Int
    var kitchenVisitorsCount: Int
    var isOwner: Bool
    var relationship: ChefProfileRelationship?
    var interactionSummary: String?

    init(
        profile: ProfileSummary,
        fellowChefsCount: Int = 0,
        kitchenVisitorsCount: Int = 0,
        isOwner: Bool = false,
        relationship: ChefProfileRelationship? = nil,
        interactionSummary: String? = nil
    ) {
        self.profile = profile.withNormalizedProfileLink()
        self.fellowChefsCount = fellowChefsCount
        self.kitchenVisitorsCount = kitchenVisitorsCount
        self.isOwner = isOwner
        self.relationship = relationship
        self.interactionSummary = interactionSummary
    }

    mutating func merge(_ other: ChefProfileRecord) {
        profile = other.profile
        fellowChefsCount = max(fellowChefsCount, other.fellowChefsCount)
        kitchenVisitorsCount = max(kitchenVisitorsCount, other.kitchenVisitorsCount)
        isOwner = isOwner || other.isOwner
        relationship = other.relationship ?? relationship
        interactionSummary = other.interactionSummary ?? interactionSummary
    }
}

private struct ChefProfileInteractionAggregate: Sendable {
    let chef: ChefSummary
    private(set) var spoons: Int = 0
    private(set) var latestInteractionAt: String = ""

    mutating func record(spoon: RecipeDetailRecentSpoon) {
        spoons += 1
        let candidate = spoon.cookedAt ?? spoon.updatedAt
        if candidate > latestInteractionAt {
            latestInteractionAt = candidate
        }
    }
}
