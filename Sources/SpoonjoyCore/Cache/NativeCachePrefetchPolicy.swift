import Foundation

public enum NativeCachePrefetchRead: Equatable, Hashable, Sendable {
    case currentAccount
    case kitchen
    case notificationPreferences
    case tokenMetadata
    case connectionStatus
    case apnsStatus
    case cookbookList
    case shoppingList
    case recipeDetail(id: String)
    case cookModeBackingData(recipeID: String)
    case profile(id: String)
}

public enum NativeCacheOnlineOnlyAction: String, Equatable, Hashable, Sendable {
    case tokenCreate
    case tokenRevoke
    case oauthDisconnect
    case logout
    case apnsPermissionPrompt
    case apnsDeviceTokenAcquisition
}

public enum NativeCachePrefetchScenario: Equatable, Sendable {
    case signedInLaunch(
        accountID: String,
        environment: NativeCacheEnvironment,
        recentlyViewedRecipeIDs: [String],
        activeCookModeRecipeIDs: [String],
        viewedProfileIDs: [String]
    )
}

public struct NativeCachePrefetchPlan: Equatable, Sendable {
    public let requiredReads: [NativeCachePrefetchRead]
    public let revalidateOn: [NativeCacheRevalidationTrigger]
    public let onlineOnlyActionsQueued: [NativeCacheOnlineOnlyAction]

    public var containsOnlineOnlyActions: Bool {
        !onlineOnlyActionsQueued.isEmpty
    }
}

public struct NativeCachePrefetchPolicy: Equatable, Sendable {
    public static let offlineProductContract = NativeCachePrefetchPolicy()

    public let onlineOnlyActions: [NativeCacheOnlineOnlyAction] = [
        .tokenCreate,
        .tokenRevoke,
        .oauthDisconnect,
        .logout,
        .apnsPermissionPrompt,
        .apnsDeviceTokenAcquisition
    ]

    public init() {}

    public func plan(for scenario: NativeCachePrefetchScenario) -> NativeCachePrefetchPlan {
        switch scenario {
        case .signedInLaunch(_, _, let recentlyViewedRecipeIDs, let activeCookModeRecipeIDs, let viewedProfileIDs):
            var requiredReads: [NativeCachePrefetchRead] = [
                .currentAccount,
                .kitchen,
                .notificationPreferences,
                .tokenMetadata,
                .connectionStatus,
                .apnsStatus,
                .cookbookList,
                .shoppingList
            ]
            requiredReads.append(contentsOf: recentlyViewedRecipeIDs.map { .recipeDetail(id: $0) })
            requiredReads.append(contentsOf: activeCookModeRecipeIDs.map { .cookModeBackingData(recipeID: $0) })
            requiredReads.append(contentsOf: viewedProfileIDs.map { .profile(id: $0) })

            return NativeCachePrefetchPlan(
                requiredReads: requiredReads,
                revalidateOn: [.launch, .foreground, .networkRecovered, .visibleSurfaceOpened],
                onlineOnlyActionsQueued: []
            )
        }
    }
}
