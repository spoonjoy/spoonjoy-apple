import Foundation

public struct NativeCapabilityMetadata: Codable, Equatable, Sendable {
    public let appIntents: [String]
    public let appIntentTelemetryEvents: [String]
    public let spotlightIndexedTypes: [String]
    public let searchableScopes: [String]
    public let shareActions: [String]
    public let offlineFlows: [String]
    public let associatedDomains: [String]
    public let urlSchemes: [String]
    public let deepLinkRoutes: [String]

    public init(
        appIntents: [String],
        appIntentTelemetryEvents: [String],
        spotlightIndexedTypes: [String],
        searchableScopes: [String],
        shareActions: [String],
        offlineFlows: [String],
        associatedDomains: [String],
        urlSchemes: [String],
        deepLinkRoutes: [String]
    ) {
        self.appIntents = appIntents
        self.appIntentTelemetryEvents = appIntentTelemetryEvents
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
            "OpenCookbookIntent",
            "OpenProfileIntent",
            "OpenSettingsIntent",
            "ReadNotificationPreferencesIntent",
            "UpdateNotificationPreferencesIntent",
            "OpenNotificationAPNsStatusIntent",
            "UpdateProfileDisplayIntent",
            "UpdateProfilePhotoIntent",
            "RemoveProfilePhotoIntent",
            "OpenAPITokensIntent",
            "CreateAPITokenIntent",
            "RevokeAPITokenIntent",
            "OpenAccountConnectionsIntent",
            "DisconnectAccountConnectionIntent",
            "OpenPasskeysIntent",
            "OpenPasswordIntent",
            "LinkProviderIntent",
            "LogoutIntent",
            "RevokeCurrentSessionIntent",
            "SearchSpoonjoyIntent",
            "ShareRecipeIntent",
            "ShareCookbookIntent",
            "ShareShoppingListIntent",
            "StartCookModeIntent",
            "ContinueCookModeIntent",
            "ForkRecipeIntent",
            "CreateCookbookIntent",
            "RenameCookbookIntent",
            "DeleteCookbookIntent",
            "AddRecipeToCookbookIntent",
            "SaveRecipeToCookbookIntent",
            "RemoveRecipeFromCookbookIntent",
            "DeleteRecipeIntent",
            "LogCookIntent",
            "EditCookLogIntent",
            "DeleteCookLogIntent",
            "CreateCoverFromSpoonIntent",
            "AddShoppingListItemIntent",
            "SetShoppingListItemCheckedIntent",
            "RemoveShoppingListItemIntent",
            "AddRecipeIngredientsToShoppingListIntent",
            "ClearCompletedShoppingItemsIntent",
            "ClearShoppingListIntent",
            "CaptureRecipeIntent",
            "SubmitCaptureImportIntent",
            "OpenCaptureDraftIntent",
            "DiscardCaptureDraftIntent",
            "SpoonjoyAppShortcuts",
            "SpoonjoyInteractionDonor",
            "SpoonjoyRecipeEntity",
            "SpoonjoyCookbookEntity",
            "SpoonjoyRecipeEntityQuery",
            "SpoonjoyCookbookEntityQuery",
            "SpoonjoyShoppingListEntity",
            "SpoonjoyShoppingItemEntity",
            "SpoonjoyShoppingListEntityQuery",
            "SpoonjoyShoppingItemEntityQuery",
            "SpoonjoySpoonEntity",
            "SpoonjoySpoonEntityQuery",
            "SpoonjoyCaptureDraftEntity",
            "SpoonjoyCaptureDraftEntityQuery",
            "SpoonjoyChefProfileEntity",
            "SpoonjoyChefProfileEntityQuery",
            "SpoonjoyAPITokenEntity",
            "SpoonjoyAPITokenEntityQuery",
            "SpoonjoyAccountConnectionEntity",
            "SpoonjoyAccountConnectionEntityQuery"
        ],
        appIntentTelemetryEvents: [
            "app_intent_completed",
            "app_intent_failed"
        ],
        spotlightIndexedTypes: ["recipe", "cookbook", "shopping-list-item", "spoon", "capture-draft", "chef-profile"],
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
            "share-cookbook",
            "native-shopping-list-transfer"
        ],
        offlineFlows: [
            "offline-cache-restore",
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
            appIntentTelemetryEvents: appIntentTelemetryEvents,
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
