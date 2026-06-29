import Foundation

public struct NativeCapabilityMetadata: Codable, Equatable, Sendable {
    public let appIntents: [String]
    public let spotlightIndexedTypes: [String]
    public let searchableScopes: [String]
    public let shareActions: [String]
    public let offlineFlows: [String]
    public let associatedDomains: [String]
    public let urlSchemes: [String]
    public let deepLinkRoutes: [String]

    public init(
        appIntents: [String],
        spotlightIndexedTypes: [String],
        searchableScopes: [String],
        shareActions: [String],
        offlineFlows: [String],
        associatedDomains: [String],
        urlSchemes: [String],
        deepLinkRoutes: [String]
    ) {
        self.appIntents = appIntents
        self.spotlightIndexedTypes = spotlightIndexedTypes
        self.searchableScopes = searchableScopes
        self.shareActions = shareActions
        self.offlineFlows = offlineFlows
        self.associatedDomains = associatedDomains
        self.urlSchemes = urlSchemes
        self.deepLinkRoutes = deepLinkRoutes
    }

    public static let spoonjoy = NativeCapabilityMetadata(
        appIntents: [
            "OpenRecipeIntent",
            "StartCookModeIntent",
            "AddShoppingListItemIntent",
            "SetShoppingListItemCheckedIntent",
            "AddRecipeIngredientsToShoppingListIntent",
            "ClearCompletedShoppingItemsIntent",
            "ClearShoppingListIntent",
            "CaptureRecipeIntent",
            "SpoonjoyRecipeEntity",
            "SpoonjoyCookbookEntity",
            "SpoonjoyRecipeEntityQuery",
            "SpoonjoyCookbookEntityQuery"
        ],
        spotlightIndexedTypes: ["recipe", "cookbook", "shopping-list-item"],
        searchableScopes: ["all", "recipes", "cookbooks", "chefs", "shopping-list"],
        shareActions: [
            "capture-recipe-url",
            "capture-recipe-text",
            "capture-recipe-camera",
            "capture-recipe-photo-library",
            "capture-recipe-json-ld",
            "capture-recipe-video-url",
            "recipe-import-submit",
            "share-recipe",
            "share-cookbook"
        ],
        offlineFlows: [
            "fixture-offline-restore",
            "shopping-queue-replay",
            "cook-mode-progress-restore",
            "capture-draft-offline",
            "capture-import-offline-retry",
            "provider-secret-blocked-import"
        ],
        associatedDomains: DeepLinkManifest.associatedDomains,
        urlSchemes: DeepLinkManifest.urlSchemes,
        deepLinkRoutes: DeepLinkManifest.routes
    )

    public var scenarioCapabilities: ScenarioNativeCapabilities {
        ScenarioNativeCapabilities(
            appIntents: appIntents,
            spotlightIndexedTypes: spotlightIndexedTypes,
            searchableScopes: searchableScopes,
            shareActions: shareActions,
            offlineFlows: offlineFlows,
            associatedDomains: associatedDomains,
            urlSchemes: urlSchemes,
            deepLinkRoutes: deepLinkRoutes
        )
    }
}
