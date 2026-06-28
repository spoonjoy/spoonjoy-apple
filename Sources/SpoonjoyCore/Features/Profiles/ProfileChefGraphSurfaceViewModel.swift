import Foundation

public enum ProfileSurfaceConnectivity: Equatable, Sendable {
    case online
    case offline
}

public enum ProfileSurfaceSectionID: Equatable, Sendable {
    case recipes
    case cookbooks
    case recentSpoons
    case fellowChefs
    case kitchenVisitors
}

public enum ProfileSurfaceActionID: Equatable, Sendable {
    case share
    case editProfile
}

public struct ProfileSurfaceContext: Equatable, Sendable {
    public let currentChefID: String?

    public init(currentChefID: String?) {
        self.currentChefID = currentChefID
    }
}

public struct ProfileSurfaceHeader: Equatable, Sendable {
    public let id: String
    public let username: String
    public let photoURL: URL?
    public let joinedLabel: String

    public init(profile: ProfileSummary) {
        id = profile.id
        username = profile.username
        photoURL = profile.photoURL
        joinedLabel = profile.joinedLabel
    }
}

public struct ProfileSurfaceOwnerActions: Equatable, Sendable {
    public let isVisible: Bool
    public let editProfileRoute: AppRoute?

    public init(isVisible: Bool, editProfileRoute: AppRoute?) {
        self.isVisible = isVisible
        self.editProfileRoute = editProfileRoute
    }
}

public struct ProfileSurfaceGraphLink: Equatable, Sendable {
    public let direction: ProfileGraphDirection
    public let title: String
    public let count: Int
    public let route: AppRoute

    public init(direction: ProfileGraphDirection, title: String, count: Int, route: AppRoute) {
        self.direction = direction
        self.title = title
        self.count = count
        self.route = route
    }
}

public struct ProfileSurfaceConflictBanner: Equatable, Sendable {
    public let localClientMutationID: String
    public let message: String
    public let actionTitle: String

    public init(localClientMutationID: String, message: String, actionTitle: String) {
        self.localClientMutationID = localClientMutationID
        self.message = message
        self.actionTitle = actionTitle
    }
}

public struct ProfileViewModel: Sendable {
    public let result: ProfileSurfaceResult
    public let context: ProfileSurfaceContext
    public let queuedMutations: [NativeQueuedMutation]
    public let conflicts: [NativeSyncConflict]
    public let connectivity: ProfileSurfaceConnectivity
    public let header: ProfileSurfaceHeader
    public let openRoute: AppRoute
    public let ownerActions: ProfileSurfaceOwnerActions
    public let availableActionIDs: [ProfileSurfaceActionID]
    public let sectionIDs: [ProfileSurfaceSectionID]
    public let unsupportedSocialSurfaces: [String]
    public let recipes: [ProfileRecipeSummary]
    public let cookbooks: [ProfileCookbookSummary]
    public let recentSpoons: [ProfileRecentSpoon]
    public let graphLinks: [ProfileSurfaceGraphLink]
    public let offlineIndicator: OfflineIndicatorState
    public let conflictBanner: ProfileSurfaceConflictBanner?

    private let now: @Sendable () -> Date
    private let timestamp: @Sendable () -> String

    public init(
        result: ProfileSurfaceResult,
        context: ProfileSurfaceContext,
        queuedMutations: [NativeQueuedMutation],
        conflicts: [NativeSyncConflict],
        connectivity: ProfileSurfaceConnectivity,
        now: @escaping @Sendable () -> Date,
        timestamp: @escaping @Sendable () -> String
    ) {
        self.result = result
        self.context = context
        self.queuedMutations = queuedMutations
        self.conflicts = conflicts
        self.connectivity = connectivity
        self.now = now
        self.timestamp = timestamp
        header = ProfileSurfaceHeader(profile: result.data.profile)
        openRoute = .profile(identifier: result.data.profile.username)
        let isOwner = result.data.isOwner || context.currentChefID == result.data.profile.id
        ownerActions = ProfileSurfaceOwnerActions(
            isVisible: isOwner,
            editProfileRoute: isOwner ? .settings : nil
        )
        availableActionIDs = isOwner ? [.share, .editProfile] : [.share]
        sectionIDs = [.recipes, .cookbooks, .recentSpoons, .fellowChefs, .kitchenVisitors]
        unsupportedSocialSurfaces = []
        recipes = result.data.recipes
        cookbooks = result.data.cookbooks
        recentSpoons = result.data.recentSpoons
        graphLinks = [
            ProfileSurfaceGraphLink(
                direction: .fellowChefs,
                title: "Fellow chefs",
                count: result.data.fellowChefsCount,
                route: .profileGraph(identifier: result.data.profile.username, direction: .fellowChefs, page: 1)
            ),
            ProfileSurfaceGraphLink(
                direction: .kitchenVisitors,
                title: "Kitchen visitors",
                count: result.data.kitchenVisitorsCount,
                route: .profileGraph(identifier: result.data.profile.username, direction: .kitchenVisitors, page: 1)
            )
        ]

        let profileMutations = Self.profileMutations(queuedMutations)
        let profileConflicts = Self.profileConflicts(conflicts, queuedMutations: profileMutations)
        conflictBanner = profileConflicts.first.map {
            ProfileSurfaceConflictBanner(
                localClientMutationID: $0.clientMutationID,
                message: $0.message,
                actionTitle: "Review profile conflict"
            )
        }
        if let conflict = profileConflicts.first {
            offlineIndicator = OfflineIndicatorState(
                display: .conflict(recordID: conflict.clientMutationID, mutationID: conflict.clientMutationID),
                dismissal: nil
            )
        } else if !profileMutations.isEmpty {
            offlineIndicator = OfflineIndicatorState(
                display: .queuedWork(count: profileMutations.count, oldestClientMutationID: profileMutations.first?.clientMutationID),
                dismissal: nil
            )
        } else if connectivity == .offline {
            offlineIndicator = OfflineIndicatorState(display: .offline, dismissal: nil)
        } else {
            offlineIndicator = result.offlineIndicator(now: now())
        }
        _ = timestamp
    }

    private static func profileMutations(_ mutations: [NativeQueuedMutation]) -> [NativeQueuedMutation] {
        mutations.filter { mutation in
            switch mutation.queueableKind {
            case .profileDisplayUpdate, .profilePhotoUpload, .profilePhotoRemove:
                true
            default:
                false
            }
        }
    }

    public static func queueableProfileSurfaceKinds(createdAt: String = "2026-06-16T00:00:00.000Z") -> [NativeQueuedMutationKind] {
        [
            NativeQueuedMutation.profileDisplayUpdate(
                email: "profile@example.com",
                username: "profile",
                clientMutationID: "cm_profile_surface_display",
                createdAt: createdAt
            ).queueableKind,
            NativeQueuedMutation.profilePhotoUpload(
                photo: NativeStagedMediaUpload(
                    localStageID: "profile-photo",
                    fileName: "profile.jpg",
                    contentType: "image/jpeg",
                    byteCount: 1
                ),
                clientMutationID: "cm_profile_surface_photo",
                createdAt: createdAt
            ).queueableKind,
            NativeQueuedMutation.profilePhotoRemove(
                clientMutationID: "cm_profile_surface_photo_remove",
                createdAt: createdAt
            ).queueableKind
        ]
    }

    private static func profileConflicts(
        _ conflicts: [NativeSyncConflict],
        queuedMutations: [NativeQueuedMutation]
    ) -> [NativeSyncConflict] {
        let mutationIDs = Set(queuedMutations.map(\.clientMutationID))
        return conflicts.filter { mutationIDs.contains($0.clientMutationID) }
    }
}

public struct ProfileGraphViewModel: Equatable, Sendable {
    public let page: ProfileGraphPage
    public let rows: [ProfileGraphRow]
    public let title: String
    public let emptyState: ProfileSurfaceEmptyState?
    public let offlineIndicator: OfflineIndicatorState

    public init(page: ProfileGraphPage) {
        self.page = page
        rows = page.rows
        title = page.direction == .fellowChefs ? "Fellow chefs" : "Kitchen visitors"
        emptyState = page.emptyState
        switch page.source {
        case .live:
            offlineIndicator = OfflineIndicatorState(display: .synced, dismissal: nil)
        case .cache:
            offlineIndicator = OfflineIndicatorState(display: .stale(domain: .profile(id: page.profile.id)), dismissal: nil)
        }
    }
}

@MainActor public final class ProfileChefGraphSurfaceViewModel {
    private let repository: any ProfileChefGraphSurfaceRepository
    private let context: ProfileSurfaceContext
    private let queuedMutations: [NativeQueuedMutation]
    private let conflicts: [NativeSyncConflict]
    private let connectivity: ProfileSurfaceConnectivity
    private let now: @Sendable () -> Date
    private let timestamp: @Sendable () -> String

    public private(set) var profile: ProfileViewModel?
    public private(set) var graph: ProfileGraphViewModel?

    public init(
        repository: any ProfileChefGraphSurfaceRepository,
        context: ProfileSurfaceContext,
        queuedMutations: [NativeQueuedMutation],
        conflicts: [NativeSyncConflict],
        connectivity: ProfileSurfaceConnectivity,
        now: @escaping @Sendable () -> Date = Date.init,
        timestamp: @escaping @Sendable () -> String
    ) {
        self.repository = repository
        self.context = context
        self.queuedMutations = queuedMutations
        self.conflicts = conflicts
        self.connectivity = connectivity
        self.now = now
        self.timestamp = timestamp
    }

    public func loadProfile(identifier: String) async throws {
        let result = try await repository.profile(identifier: identifier)
        profile = ProfileViewModel(
            result: result,
            context: context,
            queuedMutations: queuedMutations,
            conflicts: conflicts,
            connectivity: connectivity,
            now: now,
            timestamp: timestamp
        )
    }

    public func loadGraph(identifier: String, direction: ProfileGraphDirection, page: Int = 1, limit: Int = 50) async throws {
        let page = try await repository.graph(identifier: identifier, direction: direction, page: page, limit: limit)
        graph = ProfileGraphViewModel(page: page)
    }
}
