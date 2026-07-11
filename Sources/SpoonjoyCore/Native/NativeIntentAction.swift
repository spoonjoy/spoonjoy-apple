import Foundation

public enum NativeIntentActionError: Error, Equatable, CustomStringConvertible {
    case invalidRecipeID(String)
    case invalidCookbookID(String)
    case invalidProfileIdentifier(String)
    case invalidShoppingItemID(String)
    case invalidSpoonID(String)
    case invalidScaleFactor(Double)
    case emptyShoppingItem
    case emptyCaptureSource
    case emptySpoonLog
    case emptyCookbookTitle
    case authRequired
    case recipeOwnershipRequired(recipeID: String)
    case cookbookOwnershipRequired(cookbookID: String)
    case spoonOwnershipRequired(spoonID: String)
    case spoonPhotoRequired(spoonID: String)
    case captureDraftOwnershipRequired(draftID: String)
    case captureImportNeedsTextRecognition(draftID: String)
    case captureImportQueueUnavailable(draftID: String)
    case unresolvedRecipeEntity
    case unresolvedCookbookEntity
    case unresolvedShoppingListEntity
    case unresolvedShoppingItemEntity
    case unresolvedSpoonEntity
    case unresolvedCaptureDraftEntity
    case unresolvedChefProfileEntity
    case unresolvedAPITokenEntity
    case unresolvedAccountConnectionEntity
    case settingsProfilePhotoRejected(String)
    case settingsActionUnavailable(String)
    case shareUnavailable(AppRoute)

    public var description: String {
        switch self {
        case .invalidRecipeID(let recipeID):
            "Recipe ID \(recipeID) is not safe for a native route."
        case .invalidCookbookID(let cookbookID):
            "Cookbook ID \(cookbookID) is not safe for a native route."
        case .invalidProfileIdentifier(let profileIdentifier):
            "Profile identifier \(profileIdentifier) is not safe for a native route."
        case .invalidShoppingItemID(let itemID):
            "Shopping item ID \(itemID) is not safe for a native route."
        case .invalidSpoonID(let spoonID):
            "Cook log ID \(spoonID) is not safe for a native route."
        case .invalidScaleFactor(let scaleFactor):
            "Scale factor \(scaleFactor) must be greater than zero."
        case .emptyShoppingItem:
            "Shopping item name must be non-empty."
        case .emptyCaptureSource:
            "Capture source must include text or a URL."
        case .emptySpoonLog:
            "Add a note or next-time thought before logging this cook from Siri."
        case .emptyCookbookTitle:
            "Add a cookbook title before queueing this Siri action."
        case .authRequired:
            "Sign in to Spoonjoy before queueing this Siri action."
        case .recipeOwnershipRequired(let recipeID):
            "Only the recipe owner can update \(recipeID) from Siri."
        case .cookbookOwnershipRequired(let cookbookID):
            "Only the cookbook owner can update \(cookbookID) from Siri."
        case .spoonOwnershipRequired(let spoonID):
            "Only the cook who logged \(spoonID) can update it from Siri."
        case .spoonPhotoRequired(let spoonID):
            "Choose a cook log with a photo before making \(spoonID) a recipe cover."
        case .captureDraftOwnershipRequired(let draftID):
            "Only the capture draft owner can update \(draftID) from Siri."
        case .captureImportNeedsTextRecognition(let draftID):
            "Capture draft \(draftID) needs text recognition before Siri can submit it."
        case .captureImportQueueUnavailable(let draftID):
            "Capture draft \(draftID) could not be queued for import from Siri."
        case .unresolvedRecipeEntity:
            "Choose a Spoonjoy recipe before running this Siri action."
        case .unresolvedCookbookEntity:
            "Choose a Spoonjoy cookbook before running this Siri action."
        case .unresolvedShoppingListEntity:
            "Choose a Spoonjoy shopping list before running this Siri action."
        case .unresolvedShoppingItemEntity:
            "Choose a Spoonjoy shopping item before running this Siri action."
        case .unresolvedSpoonEntity:
            "Choose a Spoonjoy cook log before running this Siri action."
        case .unresolvedCaptureDraftEntity:
            "Choose a Spoonjoy capture draft before running this Siri action."
        case .unresolvedChefProfileEntity:
            "Choose a Spoonjoy chef profile before running this Siri action."
        case .unresolvedAPITokenEntity:
            "Choose a Spoonjoy access key before running this Siri action."
        case .unresolvedAccountConnectionEntity:
            "Choose a Spoonjoy account connection before running this Siri action."
        case .settingsProfilePhotoRejected(let reason):
            "Spoonjoy could not use that profile photo: \(reason)."
        case .settingsActionUnavailable(let reason):
            reason
        case .shareUnavailable(let route):
            "Spoonjoy cannot create a native share value for \(route.stateIdentifier)."
        }
    }
}

public enum NativeIntentAction: Equatable {
    case openRoute(AppRoute, url: URL)
    case addShoppingListItem(QueuedMutation, route: AppRoute, url: URL)
    case nativeMutation(NativeQueuedMutation, route: AppRoute, url: URL)
    case settingsAction(SettingsActionPlan, route: AppRoute, url: URL)
    case shoppingMutation(NativeQueuedMutation, route: AppRoute, url: URL)
    case captureDraft(CaptureDraft, route: AppRoute, url: URL)
    case captureDraftDiscard(NativeQueuedMutation, draftID: String, draftImportSource: NativeMutationSource?, route: AppRoute, url: URL)

    public var route: AppRoute {
        switch self {
        case .openRoute(let route, _),
             .addShoppingListItem(_, let route, _),
             .nativeMutation(_, let route, _),
             .settingsAction(_, let route, _),
             .shoppingMutation(_, let route, _),
             .captureDraft(_, let route, _),
             .captureDraftDiscard(_, _, _, let route, _):
            route
        }
    }

    public var url: URL {
        switch self {
        case .openRoute(_, let url),
             .addShoppingListItem(_, _, let url),
             .nativeMutation(_, _, let url),
             .settingsAction(_, _, let url),
             .shoppingMutation(_, _, let url),
             .captureDraft(_, _, let url),
             .captureDraftDiscard(_, _, _, _, let url):
            url
        }
    }

    public var queuedMutation: QueuedMutation? {
        switch self {
        case .addShoppingListItem(let mutation, _, _):
            mutation
        case .openRoute, .nativeMutation, .settingsAction, .shoppingMutation, .captureDraft, .captureDraftDiscard:
            nil
        }
    }

    public var nativeQueuedMutation: NativeQueuedMutation? {
        switch self {
        case .addShoppingListItem(let mutation, _, _):
            try? NativeQueuedMutation.intentMutation(from: mutation)
        case .nativeMutation(let mutation, _, _):
            mutation
        case .settingsAction:
            nil
        case .shoppingMutation(let mutation, _, _):
            mutation
        case .captureDraftDiscard(let mutation, _, _, _, _):
            mutation
        case .openRoute, .captureDraft:
            nil
        }
    }

    public var captureDraft: CaptureDraft? {
        switch self {
        case .captureDraft(let draft, _, _):
            draft
        case .openRoute, .addShoppingListItem, .nativeMutation, .settingsAction, .shoppingMutation, .captureDraftDiscard:
            nil
        }
    }

    public var telemetryActionKind: String {
        switch self {
        case .openRoute:
            "open-route"
        case .addShoppingListItem:
            "legacy-shopping-mutation"
        case .nativeMutation:
            "native-mutation"
        case .settingsAction:
            "settings-action"
        case .shoppingMutation:
            "shopping-mutation"
        case .captureDraft:
            "capture-draft"
        case .captureDraftDiscard:
            "capture-draft-discard"
        }
    }

    public func telemetryDescriptor(intentName: String,
        outcome: NativeIntentTelemetryOutcome = .completed,
        returnsValue: Bool,
        error: Error? = nil
    ) -> NativeIntentTelemetryDescriptor {
        let queuedMutation: NativeQueuedMutation?
        switch self {
        case .settingsAction(let plan, _, _):
            queuedMutation = plan.queuedMutation ?? plan.offlineFallbackMutation
        default:
            queuedMutation = nativeQueuedMutation
        }
        return NativeIntentTelemetryDescriptor(
            intentName: intentName,
            actionKind: telemetryActionKind,
            outcome: outcome,
            route: route.stateIdentifier,
            opensURL: url.absoluteString,
            returnsValue: returnsValue,
            queuedMutationID: queuedMutation?.clientMutationID,
            queuedMutationKind: queuedMutation?.queueableKind.rawValue,
            errorType: error.map { String(reflecting: Swift.type(of: $0)) }
        )
    }
}

public enum NativeIntentTelemetryOutcome: String, Equatable, Sendable {
    case completed
    case failed

    public var eventName: NativeTelemetryEvent.Name {
        switch self {
        case .completed:
            .appIntentCompleted
        case .failed:
            .appIntentFailed
        }
    }
}

public struct NativeIntentTelemetryDescriptor: Equatable, Sendable {
    public let intentName: String
    public let actionKind: String
    public let outcome: NativeIntentTelemetryOutcome
    public let route: String?
    public let opensURL: String?
    public let returnsValue: Bool
    public let queuedMutationID: String?
    public let queuedMutationKind: String?
    public let errorType: String?

    public init(
        intentName: String,
        actionKind: String,
        outcome: NativeIntentTelemetryOutcome,
        route: String?,
        opensURL: String?,
        returnsValue: Bool,
        queuedMutationID: String? = nil,
        queuedMutationKind: String? = nil,
        errorType: String? = nil
    ) {
        self.intentName = intentName
        self.actionKind = actionKind
        self.outcome = outcome
        self.route = route
        self.opensURL = opensURL
        self.returnsValue = returnsValue
        self.queuedMutationID = queuedMutationID
        self.queuedMutationKind = queuedMutationKind
        self.errorType = errorType
    }

    public func telemetryEvent(environment: String, metadata: NativeTelemetryAppMetadata) -> NativeTelemetryEvent {
        NativeTelemetryEvent(
            name: outcome.eventName,
            stage: "app_intent.\(intentName).\(actionKind)",
            environment: environment,
            metadata: metadata,
            route: route,
            errorType: errorType,
            intentName: intentName,
            intentActionKind: actionKind,
            intentOutcome: outcome.rawValue,
            intentReturnsValue: returnsValue,
            intentQueuedMutationID: queuedMutationID,
            intentQueuedMutationKind: queuedMutationKind,
            intentOpensURL: opensURL
        )
    }

    public static func failed(intentName: String, error: Error) -> NativeIntentTelemetryDescriptor {
        NativeIntentTelemetryDescriptor(
            intentName: intentName,
            actionKind: "perform",
            outcome: .failed,
            route: nil,
            opensURL: nil,
            returnsValue: false,
            errorType: String(reflecting: Swift.type(of: error))
        )
    }
}

public struct NativeIntentShareValue: Equatable, Sendable {
    public let domain: NativeShareDomain
    public let kind: NativeSharePayloadKind
    public let publicURL: URL?
    public let route: AppRoute?
    public let title: String
    public let subtitle: String
    public let privateTransferValue: String?

    public init(
        domain: NativeShareDomain,
        kind: NativeSharePayloadKind,
        publicURL: URL?,
        route: AppRoute?,
        title: String,
        subtitle: String,
        privateTransferValue: String?
    ) {
        self.domain = domain
        self.kind = kind
        self.publicURL = publicURL
        self.route = route
        self.title = title
        self.subtitle = subtitle
        self.privateTransferValue = privateTransferValue
    }

    public var isPublicURL: Bool {
        kind == NativeSharePayloadKind.publicURL
    }

    public var isPrivateTransfer: Bool {
        kind == NativeSharePayloadKind.privateTransfer
    }

    public var telemetryActionKind: String {
        "share.\(domain.rawValue).\(kind.rawValue)"
    }

    public func telemetryDescriptor(
        intentName: String,
        outcome: NativeIntentTelemetryOutcome = .completed,
        returnsValue: Bool,
        error: Error? = nil
    ) -> NativeIntentTelemetryDescriptor {
        NativeIntentTelemetryDescriptor(
            intentName: intentName,
            actionKind: telemetryActionKind,
            outcome: outcome,
            route: route?.stateIdentifier,
            opensURL: publicURL?.absoluteString,
            returnsValue: returnsValue,
            errorType: error.map { String(reflecting: Swift.type(of: $0)) }
        )
    }
}

public struct APITokenEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let credentialID: String
    public let name: String
    public let tokenPrefix: String
    public let scopes: [String]
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let isPlaceholder: Bool

    public init(
        id: String,
        credentialID: String,
        name: String,
        tokenPrefix: String,
        scopes: [String],
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute = .settings,
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.credentialID = credentialID
        self.name = name
        self.tokenPrefix = tokenPrefix
        self.scopes = scopes
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.isPlaceholder = isPlaceholder
    }

    public static let placeholder = APITokenEntityDescriptor(
        id: "api-token-placeholder",
        credentialID: "",
        name: "Access Key",
        tokenPrefix: "",
        scopes: [],
        subtitle: "Choose an access key",
        disambiguationLabel: "Spoonjoy settings",
        isPlaceholder: true
    )
}

public struct AccountConnectionEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let connectionID: String
    public let clientName: String
    public let resource: String?
    public let scopes: [String]
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let isPlaceholder: Bool

    public init(
        id: String,
        connectionID: String,
        clientName: String,
        resource: String?,
        scopes: [String],
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute = .settings,
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.connectionID = connectionID
        self.clientName = clientName
        self.resource = resource
        self.scopes = scopes
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.isPlaceholder = isPlaceholder
    }

    public static let placeholder = AccountConnectionEntityDescriptor(
        id: "account-connection-placeholder",
        connectionID: "",
        clientName: "Connection",
        resource: nil,
        scopes: [],
        subtitle: "Choose a connection",
        disambiguationLabel: "Spoonjoy settings",
        isPlaceholder: true
    )
}

public struct NativeIntentSettingsAction: Equatable, Sendable {
    public let plan: SettingsActionPlan
    public let route: AppRoute
    public let url: URL

    public init(plan: SettingsActionPlan, route: AppRoute, url: URL) {
        self.plan = plan
        self.route = route
        self.url = url
    }

    public var onlineOnlyReason: SettingsOnlineOnlyReason? {
        plan.onlineOnlyReason
    }
}

public struct NativeIntentSettingsHandoffPlan: Equatable, Sendable {
    public let plan: SettingsActionPlan
    public let route: AppRoute
    public let url: URL
    public let secureHandoff: SettingsSecureHandoff

    public init(plan: SettingsActionPlan, route: AppRoute, url: URL, secureHandoff: SettingsSecureHandoff) {
        self.plan = plan
        self.route = route
        self.url = url
        self.secureHandoff = secureHandoff
    }

    public var onlineOnlyReason: SettingsOnlineOnlyReason? {
        plan.onlineOnlyReason
    }
}

public struct NativeIntentNotificationPreferencesSummary: Equatable, Sendable {
    public let preferences: SettingsNotificationPreferences
    public let value: String

    public init(preferences: SettingsNotificationPreferences) {
        self.preferences = preferences
        value = [
            "Spoons: \(Self.status(preferences.notifySpoonOnMyRecipe))",
            "Forks: \(Self.status(preferences.notifyForkOfMyRecipe))",
            "Cookbook saves: \(Self.status(preferences.notifyCookbookSaveOfMine))",
            "Fellow-chef cooks: \(Self.status(preferences.notifyFellowChefOriginCook))"
        ].joined(separator: ", ")
    }

    private static func status(_ enabled: Bool) -> String {
        enabled ? "on" : "off"
    }
}

public struct NativeIntentNotificationAction: Equatable, Sendable {
    public let plan: NotificationAPNsActionPlan
    public let route: AppRoute
    public let url: URL
    public let blockerState: APNsDeliveryBlockerState
    public let blockerArtifactFileName: String

    public init(
        plan: NotificationAPNsActionPlan,
        route: AppRoute,
        url: URL,
        blockerState: APNsDeliveryBlockerState,
        blockerArtifactFileName: String
    ) {
        self.plan = plan
        self.route = route
        self.url = url
        self.blockerState = blockerState
        self.blockerArtifactFileName = blockerArtifactFileName
    }

    public var deliveryBlocker: AppleDeveloperProgramBlocker? {
        plan.deliveryBlocker
    }

    public var onlineOnlyReason: NotificationAPNsOnlineOnlyReason? {
        plan.onlineOnlyReason
    }
}

public struct NativeIntentActionResolver {
    private let settingsSecureHandoffRoutes: SettingsSecureHandoffRoutes
    private let settingsPlanBuilder: @Sendable (
        SettingsAction,
        SettingsSurfaceConnectivity,
        (@Sendable () -> String)?
    ) throws -> SettingsActionPlan

    public init(settingsSecureHandoffRoutes: SettingsSecureHandoffRoutes = .spoonjoyApp) {
        self.init(settingsSecureHandoffRoutes: settingsSecureHandoffRoutes) { action, connectivity, now in
            try SettingsActionPlanner(
                connectivity: connectivity,
                secureHandoffRoutes: settingsSecureHandoffRoutes,
                now: now
            ).plan(action)
        }
    }

    init(
        settingsSecureHandoffRoutes: SettingsSecureHandoffRoutes,
        settingsPlanBuilder: @escaping @Sendable (
            SettingsAction,
            SettingsSurfaceConnectivity,
            (@Sendable () -> String)?
        ) throws -> SettingsActionPlan
    ) {
        self.settingsSecureHandoffRoutes = settingsSecureHandoffRoutes
        self.settingsPlanBuilder = settingsPlanBuilder
    }

    public func openRecipe(recipeID: String) throws -> NativeIntentAction {
        let id = try canonicalRecipeID(recipeID)
        return openRoute(.recipeDetail(id: id, presentation: .detail))
    }

    public func openRecipe(recipe: RecipeEntityDescriptor) throws -> NativeIntentAction {
        try openRoute(recipeDetailRoute(recipe, presentation: .detail))
    }

    public func openCookbook(cookbook: CookbookEntityDescriptor) throws -> NativeIntentAction {
        try openRoute(cookbookDetailRoute(cookbook))
    }

    public func openProfile(profile: ChefProfileEntityDescriptor) throws -> NativeIntentAction {
        try openRoute(profileRoute(profile))
    }

    public func openSettings() -> NativeIntentAction {
        let target: (route: AppRoute, url: URL) = (route: .settings, url: DeepLinkURLBuilder.url(for: .settings))
        return .openRoute(target.route, url: target.url)
    }

    public func readNotificationPreferences(
        data: NotificationAPNsSurfaceData,
        hasCachedPreferences: Bool,
        connectivity: NotificationAPNsSurfaceConnectivity
    ) throws -> NativeIntentNotificationPreferencesSummary {
        if case .cache = data.source, !hasCachedPreferences {
            switch connectivity {
            case .offline:
                throw NativeIntentActionError.settingsActionUnavailable("Notification preferences are unavailable offline until Spoonjoy has cached them.")
            case .online:
                throw NativeIntentActionError.settingsActionUnavailable("Notification preferences are unavailable until Spoonjoy refreshes or caches them.")
            }
        }
        let preferences: SettingsNotificationPreferences = data.preferences
        _ = preferences.notifySpoonOnMyRecipe
        _ = preferences.notifyForkOfMyRecipe
        _ = preferences.notifyCookbookSaveOfMine
        _ = preferences.notifyFellowChefOriginCook
        return NativeIntentNotificationPreferencesSummary(preferences: preferences)
    }

    public func updateNotificationPreferences(
        preferences: SettingsNotificationPreferences,
        connectivity: NotificationAPNsSurfaceConnectivity,
        deliveryCapability: APNsDeliveryCapability = .developmentOnly(blocker: .localValidation),
        createdAt: String
    ) throws -> NativeIntentNotificationAction {
        let notificationPreferences: SettingsNotificationPreferences = preferences
        _ = notificationPreferences
        let mutationID = "intent-notification-preferences-\(stableToken(createdAt))"
        let plan = try NotificationAPNsActionPlanner(connectivity: connectivity, deliveryCapability: deliveryCapability, now: { createdAt }).plan(.updatePreferences(preferences, clientMutationID: mutationID))
        return NativeIntentNotificationAction(
            plan: plan,
            route: .settings,
            url: DeepLinkURLBuilder.url(for: .settings),
            blockerState: deliveryCapability.blockerState,
            blockerArtifactFileName: AppleDeveloperProgramBlocker.artifactFileName
        )
    }

    public func updateNotificationPreferences(
        currentPreferences: SettingsNotificationPreferences,
        spoons: Bool?,
        forks: Bool?,
        cookbookSaves: Bool?,
        fellowChefCooks: Bool?,
        connectivity: NotificationAPNsSurfaceConnectivity,
        deliveryCapability: APNsDeliveryCapability = .developmentOnly(blocker: .localValidation),
        createdAt: String
    ) throws -> NativeIntentNotificationAction {
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: spoons ?? currentPreferences.notifySpoonOnMyRecipe,
            notifyForkOfMyRecipe: forks ?? currentPreferences.notifyForkOfMyRecipe,
            notifyCookbookSaveOfMine: cookbookSaves ?? currentPreferences.notifyCookbookSaveOfMine,
            notifyFellowChefOriginCook: fellowChefCooks ?? currentPreferences.notifyFellowChefOriginCook
        )
        return try updateNotificationPreferences(
            preferences: preferences,
            connectivity: connectivity,
            deliveryCapability: deliveryCapability,
            createdAt: createdAt
        )
    }

    public func openNotificationAPNsStatus(data: NotificationAPNsSurfaceData) -> NativeIntentNotificationAction {
        let surfaceData: NotificationAPNsSurfaceData = data
        let blockerState: APNsDeliveryBlockerState = surfaceData.deliveryCapability.blockerState
        let plan = NotificationAPNsActionPlan(
            deliveryBlocker: surfaceData.deliveryCapability.productionBlocker,
            userFacingMessage: surfaceData.deliveryCapability.productionBlocker?.ownerAction
        )
        return NativeIntentNotificationAction(
            plan: plan,
            route: .settings,
            url: DeepLinkURLBuilder.url(for: .settings),
            blockerState: blockerState,
            blockerArtifactFileName: AppleDeveloperProgramBlocker.artifactFileName
        )
    }

    public func updateProfileDisplay(
        email: String,
        username: String,
        connectivity: SettingsSurfaceConnectivity,
        createdAt: String
    ) throws -> NativeIntentAction {
        let mutationID = "intent-settings-profile-display-\(stableToken(email))-\(stableToken(username))-\(stableToken(createdAt))"
        let plan = try settingsPlan(
            .updateProfile(email: email, username: username, clientMutationID: mutationID),
            connectivity: connectivity,
            now: { createdAt }
        )
        _ = try settingsMutation(from: plan, expectedKind: .profileDisplayUpdate)
        let target: (route: AppRoute, url: URL) = (route: .settings, url: DeepLinkURLBuilder.url(for: .settings))
        return .settingsAction(plan, route: target.route, url: target.url)
    }

    public func updateProfilePhoto(
        photo: NativeStagedMediaUpload,
        connectivity: SettingsSurfaceConnectivity,
        createdAt: String
    ) throws -> NativeIntentAction {
        let stagedPhoto = photo
        let stagedResult = SettingsProfilePhotoStagingPolicy.webProfileParity.stageReplacement(
            existing: nil,
            candidate: stagedPhoto
        )
        if let rejection = stagedResult.rejection {
            throw NativeIntentActionError.settingsProfilePhotoRejected("\(rejection)")
        }
        let mutationID = "intent-settings-profile-photo-\(stableToken(stagedPhoto.localStageID))-\(stableToken(createdAt))"
        let plan = try settingsPlan(
            .uploadProfilePhoto(photo: stagedPhoto, clientMutationID: mutationID),
            connectivity: connectivity,
            now: { createdAt }
        )
        _ = try settingsMutation(from: plan, expectedKind: .profilePhotoUpload)
        let target: (route: AppRoute, url: URL) = (route: .settings, url: DeepLinkURLBuilder.url(for: .settings))
        return .settingsAction(plan, route: target.route, url: target.url)
    }

    public func removeProfilePhoto(
        connectivity: SettingsSurfaceConnectivity,
        createdAt: String
    ) throws -> NativeIntentAction {
        let mutationID = "intent-settings-profile-photo-remove-\(stableToken(createdAt))"
        let plan = try settingsPlan(
            .removeProfilePhoto(clientMutationID: mutationID),
            connectivity: connectivity,
            now: { createdAt }
        )
        _ = try settingsMutation(from: plan, expectedKind: .profilePhotoRemove)
        let target: (route: AppRoute, url: URL) = (route: .settings, url: DeepLinkURLBuilder.url(for: .settings))
        return .settingsAction(plan, route: target.route, url: target.url)
    }

    public func openAPITokens() -> NativeIntentAction {
        let target: (route: AppRoute, url: URL) = (route: .settings, url: DeepLinkURLBuilder.url(for: .settings))
        return .openRoute(target.route, url: target.url)
    }

    public func createAPIToken(
        name: String,
        scopes: [String],
        connectivity: SettingsSurfaceConnectivity
    ) throws -> NativeIntentSettingsAction {
        _ = try TokenCredentialRequests.createToken(name: name, scopes: scopes)
        let plan = try settingsPlan(.createAPIToken(name: name, scopes: scopes), connectivity: connectivity)
        let target: (route: AppRoute, url: URL) = (route: .settings, url: DeepLinkURLBuilder.url(for: .settings))
        if plan.onlineOnlyReason != nil {
            return NativeIntentSettingsAction(
                plan: plan,
                route: target.route,
                url: target.url
            )
        }
        return NativeIntentSettingsAction(
            plan: SettingsActionPlan(userFacingMessage: "Open Spoonjoy settings to create the access key so the one-time credential is shown in the app."),
            route: target.route,
            url: target.url
        )
    }

    public func revokeAPIToken(
        token: APITokenEntityDescriptor,
        connectivity: SettingsSurfaceConnectivity
    ) throws -> NativeIntentSettingsAction {
        let credentialID = try tokenIDForMutation(token)
        _ = TokenCredentialRequests.revokeToken(credentialID: credentialID)
        let plan = try settingsPlan(.revokeAPIToken(credentialID: credentialID), connectivity: connectivity)
        guard plan.onlineOnlyReason == nil || plan.onlineOnlyReason == SettingsOnlineOnlyReason.apiTokenRevoke else {
            throw NativeIntentActionError.settingsActionUnavailable("Unexpected access key revoke plan.")
        }
        return NativeIntentSettingsAction(
            plan: plan,
            route: .settings,
            url: DeepLinkURLBuilder.url(for: .settings)
        )
    }

    public func openAccountConnections() -> NativeIntentAction {
        let target: (route: AppRoute, url: URL) = (route: .settings, url: DeepLinkURLBuilder.url(for: .settings))
        return .openRoute(target.route, url: target.url)
    }

    public func disconnectAccountConnection(
        connection: AccountConnectionEntityDescriptor,
        connectivity: SettingsSurfaceConnectivity
    ) throws -> NativeIntentSettingsAction {
        let connectionID = try accountConnectionIDForMutation(connection)
        _ = PrivateAccountRequests.disconnectConnection(connectionID: connectionID)
        let plan = try settingsPlan(.disconnectOAuthConnection(connectionID: connectionID), connectivity: connectivity)
        guard plan.onlineOnlyReason == nil || plan.onlineOnlyReason == SettingsOnlineOnlyReason.oauthConnectionDisconnect else {
            throw NativeIntentActionError.settingsActionUnavailable("Unexpected account connection disconnect plan.")
        }
        return NativeIntentSettingsAction(
            plan: plan,
            route: .settings,
            url: DeepLinkURLBuilder.url(for: .settings)
        )
    }

    public func openPasskeys(connectivity: SettingsSurfaceConnectivity) throws -> NativeIntentSettingsHandoffPlan {
        let secureHandoffRoutes = settingsSecureHandoffRoutes
        let expectedURL = "https://spoonjoy.app/account/settings#passkeys"
        let handoff = secureHandoffRoutes.handoff(target: .passkeys)
        guard handoff.url.absoluteString == expectedURL else {
            throw NativeIntentActionError.settingsActionUnavailable("Unexpected passkey handoff route.")
        }
        let plan = try settingsPlan(.managePasskeys, connectivity: connectivity)
        return try settingsHandoffPlan(plan, fallbackHandoff: handoff)
    }

    public func openPassword(connectivity: SettingsSurfaceConnectivity) throws -> NativeIntentSettingsHandoffPlan {
        let secureHandoffRoutes = settingsSecureHandoffRoutes
        let expectedURL = "https://spoonjoy.app/account/settings#password"
        let handoff = secureHandoffRoutes.handoff(target: .password)
        guard handoff.url.absoluteString == expectedURL else {
            throw NativeIntentActionError.settingsActionUnavailable("Unexpected password handoff route.")
        }
        let plan = try settingsPlan(.managePassword, connectivity: connectivity)
        return try settingsHandoffPlan(plan, fallbackHandoff: handoff)
    }

    public func linkProvider(
        provider: SettingsAuthProvider,
        connectivity: SettingsSurfaceConnectivity
    ) throws -> NativeIntentSettingsHandoffPlan {
        let secureHandoffRoutes = settingsSecureHandoffRoutes
        let expectedURLPrefix = "https://spoonjoy.app/auth/"
        let handoff = secureHandoffRoutes.handoff(target: .providerLink(provider))
        guard handoff.url.absoluteString.hasPrefix(expectedURLPrefix) else {
            throw NativeIntentActionError.settingsActionUnavailable("Unexpected provider handoff route.")
        }
        let plan = try settingsPlan(.linkProvider(provider), connectivity: connectivity)
        return try settingsHandoffPlan(plan, fallbackHandoff: handoff)
    }

    public func logout(connectivity: SettingsSurfaceConnectivity) throws -> NativeIntentSettingsAction {
        let plan = try settingsPlan(.logout, connectivity: connectivity)
        guard plan.onlineOnlyReason == nil || plan.onlineOnlyReason == SettingsOnlineOnlyReason.logout else {
            throw NativeIntentActionError.settingsActionUnavailable("Unexpected logout plan.")
        }
        guard plan.sessionOperation != nil || plan.onlineOnlyReason != nil else {
            throw NativeIntentActionError.settingsActionUnavailable("Logout plan is missing its sessionOperation.")
        }
        return NativeIntentSettingsAction(
            plan: plan,
            route: .settings,
            url: plan.secureHandoff?.url ?? DeepLinkURLBuilder.url(for: .settings)
        )
    }

    public func revokeCurrentSession(connectivity: SettingsSurfaceConnectivity) throws -> NativeIntentSettingsAction {
        let plan = try settingsPlan(.revokeSession, connectivity: connectivity)
        guard plan.onlineOnlyReason == nil || plan.onlineOnlyReason == SettingsOnlineOnlyReason.sessionRevoke else {
            throw NativeIntentActionError.settingsActionUnavailable("Unexpected session revoke plan.")
        }
        return NativeIntentSettingsAction(
            plan: plan,
            route: .settings,
            url: DeepLinkURLBuilder.url(for: .settings)
        )
    }

    public func searchSpoonjoy(query: String, scope: SearchScope) -> NativeIntentAction {
        let route = AppRoute.search(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            scope: scope
        )
        return openRoute(route)
    }

    public func startCookMode(recipeID: String) throws -> NativeIntentAction {
        let id = try canonicalRecipeID(recipeID)
        return openRoute(.recipeDetail(id: id, presentation: .cook))
    }

    public func startCookMode(recipe: RecipeEntityDescriptor) throws -> NativeIntentAction {
        try openRoute(recipeDetailRoute(recipe, presentation: .cook))
    }

    public func continueCookMode(recipeID: String) throws -> NativeIntentAction {
        try startCookMode(recipeID: recipeID)
    }

    public func continueCookMode(recipe: RecipeEntityDescriptor) throws -> NativeIntentAction {
        try startCookMode(recipe: recipe)
    }

    public func shareRecipe(recipe: RecipeEntityDescriptor) throws -> NativeIntentShareValue {
        try publicShareValue(route: recipeDetailRoute(recipe, presentation: .detail), title: recipe.title, subtitle: recipe.subtitle)
    }

    public func shareCookbook(cookbook: CookbookEntityDescriptor) throws -> NativeIntentShareValue {
        try publicShareValue(route: cookbookDetailRoute(cookbook), title: cookbook.title, subtitle: cookbook.subtitle)
    }

    public func shareShoppingList(shoppingList: ShoppingListEntityDescriptor) throws -> NativeIntentShareValue {
        guard !shoppingList.isPlaceholder else {
            throw NativeIntentActionError.unresolvedShoppingListEntity
        }
        return NativeIntentShareValue(
            domain: .shoppingList,
            kind: .privateTransfer,
            publicURL: nil,
            route: shoppingList.route,
            title: shoppingList.title,
            subtitle: shoppingList.subtitle,
            privateTransferValue: shoppingList.transferValue.privateTransferValue
        )
    }

    public func forkRecipe(
        recipe: RecipeEntityDescriptor,
        title: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let id = try recipeIDForMutation(recipe)
        let titleOverride = normalizedRecipeTitle(title, fallback: "\(recipe.title), my version")
        let mutationID = "intent-recipe-fork-\(stableToken(id))-\(stableToken(createdAt))"
        return .nativeMutation(
            .recipeFork(
                recipeID: id,
                clientMutationID: mutationID,
                titleOverride: titleOverride,
                createdAt: createdAt
            ),
            route: .recipes,
            url: DeepLinkURLBuilder.url(for: .recipes)
        )
    }

    public func saveRecipeToCookbook(
        recipe: RecipeEntityDescriptor,
        cookbook: CookbookEntityDescriptor,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let recipeID = try recipeIDForMutation(recipe)
        let cookbookID = try cookbookIDForMutation(cookbook)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))
        guard cookbook.chefID == chefID else {
            throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)
        }
        let mutationID = "intent-cookbook-save-\(stableToken(cookbookID))-\(stableToken(recipeID))-\(stableToken(createdAt))"
        let route = AppRoute.recipeDetail(id: recipeID, presentation: .detail)
        return .nativeMutation(
            .cookbookAddRecipe(
                cookbookID: cookbookID,
                recipeID: recipeID,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: route,
            url: DeepLinkURLBuilder.url(for: route)
        )
    }

    public func createCookbook(
        title: String,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        _ = try canonicalObjectID(currentChefID, invalidError: .authRequired)
        let title = normalizedCookbookTitle(title)
        guard !title.isEmpty else {
            throw NativeIntentActionError.emptyCookbookTitle
        }
        let mutationID = "intent-cookbook-create-\(stableToken(title))-\(stableToken(createdAt))"
        return .nativeMutation(
            .cookbookCreate(
                clientMutationID: mutationID,
                title: title,
                createdAt: createdAt
            ),
            route: .cookbooks,
            url: DeepLinkURLBuilder.url(for: .cookbooks)
        )
    }

    public func renameCookbook(
        cookbook: CookbookEntityDescriptor,
        title: String,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let cookbookID = try cookbookIDForMutation(cookbook)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))
        guard cookbook.chefID == chefID else {
            throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)
        }
        let title = normalizedCookbookTitle(title)
        guard !title.isEmpty else {
            throw NativeIntentActionError.emptyCookbookTitle
        }
        let mutationID = "intent-cookbook-rename-\(stableToken(cookbookID))-\(stableToken(createdAt))"
        return .nativeMutation(
            .cookbookUpdate(
                cookbookID: cookbookID,
                title: title,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .cookbookDetail(id: cookbookID),
            url: DeepLinkURLBuilder.url(for: .cookbookDetail(id: cookbookID))
        )
    }

    public func deleteCookbook(
        cookbook: CookbookEntityDescriptor,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let cookbookID = try cookbookIDForMutation(cookbook)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))
        guard cookbook.chefID == chefID else {
            throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)
        }
        let mutationID = "intent-cookbook-delete-\(stableToken(cookbookID))-\(stableToken(createdAt))"
        return .nativeMutation(
            .cookbookDelete(
                cookbookID: cookbookID,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .cookbooks,
            url: DeepLinkURLBuilder.url(for: .cookbooks)
        )
    }

    public func addRecipeToCookbook(
        recipe: RecipeEntityDescriptor,
        cookbook: CookbookEntityDescriptor,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let recipeID = try recipeIDForMutation(recipe)
        let cookbookID = try cookbookIDForMutation(cookbook)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))
        guard cookbook.chefID == chefID else {
            throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)
        }
        let mutationID = "intent-cookbook-add-\(stableToken(cookbookID))-\(stableToken(recipeID))-\(stableToken(createdAt))"
        return .nativeMutation(
            .cookbookAddRecipe(
                cookbookID: cookbookID,
                recipeID: recipeID,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .cookbookDetail(id: cookbookID),
            url: DeepLinkURLBuilder.url(for: .cookbookDetail(id: cookbookID))
        )
    }

    public func removeRecipeFromCookbook(
        recipe: RecipeEntityDescriptor,
        cookbook: CookbookEntityDescriptor,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let recipeID = try recipeIDForMutation(recipe)
        let cookbookID = try cookbookIDForMutation(cookbook)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))
        guard cookbook.chefID == chefID else {
            throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)
        }
        let mutationID = "intent-cookbook-remove-\(stableToken(cookbookID))-\(stableToken(recipeID))-\(stableToken(createdAt))"
        return .nativeMutation(
            .cookbookRemoveRecipe(
                cookbookID: cookbookID,
                recipeID: recipeID,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .cookbookDetail(id: cookbookID),
            url: DeepLinkURLBuilder.url(for: .cookbookDetail(id: cookbookID))
        )
    }

    public func deleteRecipe(
        recipe: RecipeEntityDescriptor,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let recipeID = try recipeIDForMutation(recipe)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .recipeOwnershipRequired(recipeID: recipeID))
        guard recipe.chefID == chefID else {
            throw NativeIntentActionError.recipeOwnershipRequired(recipeID: recipeID)
        }
        let mutationID = "intent-recipe-delete-\(stableToken(recipeID))-\(stableToken(createdAt))"
        return .nativeMutation(
            .recipeDelete(
                recipeID: recipeID,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .recipes,
            url: DeepLinkURLBuilder.url(for: .recipes)
        )
    }

    public func logCook(
        recipe: RecipeEntityDescriptor,
        note: String?,
        nextTime: String?,
        cookedAt: String?,
        createdAt: String
    ) throws -> NativeIntentAction {
        let recipeID = try recipeIDForMutation(recipe)
        let normalizedNote = normalizedText(note)
        let normalizedNextTime = normalizedText(nextTime)
        guard normalizedNote != nil || normalizedNextTime != nil else {
            throw NativeIntentActionError.emptySpoonLog
        }
        let mutationID = "intent-spoon-log-\(stableToken(recipeID))-\(stableToken(createdAt))"
        let route = AppRoute.recipeDetail(id: recipeID, presentation: .detail)
        let loggedAt = normalizedText(cookedAt) ?? createdAt
        return .nativeMutation(
            .spoonCreate(
                recipeID: recipeID,
                clientMutationID: mutationID,
                note: normalizedNote,
                nextTime: normalizedNextTime,
                cookedAt: loggedAt,
                photoURL: nil,
                useAsRecipeCover: false,
                createdAt: createdAt
            ),
            route: .recipeDetail(id: recipeID, presentation: .detail),
            url: DeepLinkURLBuilder.url(for: route)
        )
    }

    public func editCookLog(
        spoon: SpoonEntityDescriptor,
        note: String?,
        nextTime: String?,
        cookedAt: String?,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let spoonID = try spoonIDForMutation(spoon)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .spoonOwnershipRequired(spoonID: spoonID))
        guard spoon.chefID == chefID else {
            throw NativeIntentActionError.spoonOwnershipRequired(spoonID: spoonID)
        }
        let mutationID = "intent-spoon-edit-\(stableToken(spoonID))-\(stableToken(createdAt))"
        let route = AppRoute.recipeDetail(id: spoon.recipeID, presentation: .detail)
        let updatedNote = normalizedText(note) ?? normalizedText(spoon.note)
        let updatedNextTime = normalizedText(nextTime) ?? normalizedText(spoon.nextTime)
        let updatedCookedAt = normalizedText(cookedAt) ?? normalizedText(spoon.cookedAt)
        return .nativeMutation(
            .spoonUpdate(
                recipeID: spoon.recipeID,
                spoonID: spoonID,
                clientMutationID: mutationID,
                note: updatedNote,
                nextTime: updatedNextTime,
                cookedAt: updatedCookedAt,
                photoURL: spoon.photoURL?.absoluteString,
                createdAt: createdAt
            ),
            route: route,
            url: DeepLinkURLBuilder.url(for: route)
        )
    }

    public func deleteCookLog(
        spoon: SpoonEntityDescriptor,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let spoonID = try spoonIDForMutation(spoon)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .spoonOwnershipRequired(spoonID: spoonID))
        guard spoon.chefID == chefID else {
            throw NativeIntentActionError.spoonOwnershipRequired(spoonID: spoonID)
        }
        let mutationID = "intent-spoon-delete-\(stableToken(spoonID))-\(stableToken(createdAt))"
        let route = AppRoute.recipeDetail(id: spoon.recipeID, presentation: .detail)
        return .nativeMutation(
            .spoonDelete(
                recipeID: spoon.recipeID,
                spoonID: spoonID,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: route,
            url: DeepLinkURLBuilder.url(for: route)
        )
    }

    public func createCoverFromSpoon(
        recipe: RecipeEntityDescriptor,
        spoon: SpoonEntityDescriptor,
        activate: Bool,
        generateEditorial: Bool,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let recipeID = try recipeIDForMutation(recipe)
        let spoonID = try spoonIDForMutation(spoon)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .recipeOwnershipRequired(recipeID: recipeID))
        guard recipe.chefID == chefID else {
            throw NativeIntentActionError.recipeOwnershipRequired(recipeID: recipeID)
        }
        guard spoon.recipeID == recipeID else {
            throw NativeIntentActionError.invalidRecipeID(spoon.recipeID)
        }
        guard spoon.photoURL != nil else {
            throw NativeIntentActionError.spoonPhotoRequired(spoonID: spoonID)
        }
        let mutationID = "intent-cover-spoon-\(stableToken(recipeID))-\(stableToken(spoonID))-\(stableToken(createdAt))"
        let route = AppRoute.recipeDetail(id: recipeID, presentation: .detail)
        return .nativeMutation(
            .coverFromSpoon(
                recipeID: recipeID,
                spoonID: spoonID,
                clientMutationID: mutationID,
                activate: activate,
                generateEditorial: generateEditorial,
                createdAt: createdAt
            ),
            route: route,
            url: DeepLinkURLBuilder.url(for: route)
        )
    }

    public func addShoppingListItem(
        name: String,
        quantity: Double?,
        unit: String?,
        createdAt: String
    ) throws -> NativeIntentAction {
        let normalizedName = try requiredTrimmed(name, error: .emptyShoppingItem).lowercased()
        let mutationID = "intent-shopping-add-\(stableToken(normalizedName))-\(stableToken(createdAt))"
        let mutation = QueuedMutation(
            id: mutationID,
            clientMutationID: mutationID,
            createdAt: createdAt,
            kind: .shoppingAdd(
                name: normalizedName,
                quantity: quantity,
                unit: normalizedOptional(unit),
                categoryKey: nil,
                iconKey: nil
            )
        )

        return .addShoppingListItem(
            mutation,
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func setShoppingListItemChecked(
        itemID: String,
        checked: Bool,
        createdAt: String
    ) throws -> NativeIntentAction {
        let id = try canonicalShoppingItemID(itemID)
        let mutationID = "intent-shopping-check-\(stableToken(id))-\(checked ? "checked" : "unchecked")-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingCheckItem(
                itemID: id,
                checked: checked,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func removeShoppingListItem(
        itemID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let id = try canonicalShoppingItemID(itemID)
        let mutationID = "intent-shopping-remove-\(stableToken(id))-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingDeleteItem(
                itemID: id,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func addRecipeIngredientsToShoppingList(
        recipeID: String,
        scaleFactor: Double,
        createdAt: String
    ) throws -> NativeIntentAction {
        let id = try canonicalRecipeID(recipeID)
        guard scaleFactor.isFinite && scaleFactor > 0 else {
            throw NativeIntentActionError.invalidScaleFactor(scaleFactor)
        }
        let mutationID = "intent-shopping-recipe-\(stableToken(id))-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingAddFromRecipe(
                recipeID: id,
                scaleFactor: scaleFactor,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func clearCompletedShoppingItems(createdAt: String) -> NativeIntentAction {
        let mutationID = "intent-shopping-clear-completed-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingClearCompleted(
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func clearShoppingList(createdAt: String) -> NativeIntentAction {
        let mutationID = "intent-shopping-clear-all-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingClearAll(
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func captureRecipe(source: String, createdAt: String) throws -> NativeIntentAction {
        let trimmedSource = try requiredTrimmed(source, error: .emptyCaptureSource)
        let draft = try CaptureDraft.localText(
            id: "intent-capture-\(stableToken(createdAt))",
            rawText: trimmedSource,
            createdAt: createdAt
        )

        return .captureDraft(
            draft,
            route: .capture,
            url: DeepLinkURLBuilder.url(for: .capture)
        )
    }

    public func submitCaptureImport(
        draft: CaptureDraftEntityDescriptor,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let captureDraftID = try captureDraftIDForMutation(draft)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .captureDraftOwnershipRequired(draftID: captureDraftID))
        guard draft.scope.accountID == chefID else {
            throw NativeIntentActionError.captureDraftOwnershipRequired(draftID: captureDraftID)
        }

        let captureDraft = try captureDraftForMutation(draft)
        guard captureDraft.importReadiness == .ready else {
            throw NativeIntentActionError.captureImportNeedsTextRecognition(draftID: captureDraftID)
        }

        let plan = try CaptureImportViewModel(
            draft: captureDraft,
            connectivity: .offline,
            pendingRetryMutation: draft.pendingImport
        ).planSubmit(
            clientMutationID: draft.pendingImport?.clientMutationID ?? "intent-capture-import-\(stableToken(captureDraftID))-\(stableToken(createdAt))",
            createdAt: createdAt
        )
        return try captureImportSubmitAction(from: plan, draftID: captureDraftID)
    }

    func captureImportSubmitAction(from plan: CaptureImportPlan, draftID: String) throws -> NativeIntentAction {
        guard let mutation = plan.offlineRetryMutation else {
            throw NativeIntentActionError.captureImportQueueUnavailable(draftID: draftID)
        }
        return .nativeMutation(
            mutation,
            route: .capture,
            url: DeepLinkURLBuilder.url(for: .capture)
        )
    }

    public func openCaptureDraft(draft: CaptureDraftEntityDescriptor) throws -> NativeIntentAction {
        _ = try captureDraftIDForMutation(draft)
        let target: (route: AppRoute, url: URL) = (route: .capture, url: DeepLinkURLBuilder.url(for: .capture))
        return .openRoute(target.route, url: target.url)
    }

    public func discardCaptureDraft(
        draft: CaptureDraftEntityDescriptor,
        currentChefID: String,
        createdAt: String
    ) throws -> NativeIntentAction {
        let captureDraftID = try captureDraftIDForMutation(draft)
        let chefID = try canonicalObjectID(currentChefID, invalidError: .captureDraftOwnershipRequired(draftID: captureDraftID))
        guard draft.scope.accountID == chefID else {
            throw NativeIntentActionError.captureDraftOwnershipRequired(draftID: captureDraftID)
        }

        let captureDraft = try captureDraftForMutation(draft)
        let draftImportSource = try? captureDraft.importSource()
        return .captureDraftDiscard(
            NativeQueuedMutation.captureDraftDiscard(
                draftID: captureDraftID,
                clientMutationID: "intent-capture-discard-\(stableToken(captureDraftID))-\(stableToken(createdAt))",
                createdAt: createdAt
            ),
            draftID: captureDraftID,
            draftImportSource: draftImportSource,
            route: .capture,
            url: DeepLinkURLBuilder.url(for: .capture)
        )
    }

    private func recipeIDForMutation(_ recipe: RecipeEntityDescriptor) throws -> String {
        guard !recipe.isPlaceholder else {
            throw NativeIntentActionError.unresolvedRecipeEntity
        }
        let id = try canonicalRecipeID(recipe.id)
        guard recipe.route == .recipeDetail(id: id, presentation: .detail) else {
            throw NativeIntentActionError.invalidRecipeID(recipe.id)
        }
        return id
    }

    private func cookbookIDForMutation(_ cookbook: CookbookEntityDescriptor) throws -> String {
        guard !cookbook.isPlaceholder else {
            throw NativeIntentActionError.unresolvedCookbookEntity
        }
        let id = try canonicalCookbookID(cookbook.id)
        guard cookbook.route == .cookbookDetail(id: id) else {
            throw NativeIntentActionError.invalidCookbookID(cookbook.id)
        }
        return id
    }

    private func spoonIDForMutation(_ spoon: SpoonEntityDescriptor) throws -> String {
        guard !spoon.isPlaceholder else {
            throw NativeIntentActionError.unresolvedSpoonEntity
        }
        let spoonID = try canonicalObjectID(spoon.spoonID, invalidError: .invalidSpoonID(spoon.spoonID))
        let recipeID = try canonicalRecipeID(spoon.recipeID)
        guard spoon.route == .recipeDetail(id: recipeID, presentation: .detail) else {
            throw NativeIntentActionError.invalidRecipeID(spoon.recipeID)
        }
        return spoonID
    }

    private func captureDraftIDForMutation(_ draft: CaptureDraftEntityDescriptor) throws -> String {
        guard !draft.isPlaceholder else {
            throw NativeIntentActionError.unresolvedCaptureDraftEntity
        }
        let captureDraftID = try canonicalObjectID(draft.captureDraftID, invalidError: .unresolvedCaptureDraftEntity)
        guard draft.route == .capture else {
            throw NativeIntentActionError.unresolvedCaptureDraftEntity
        }
        return captureDraftID
    }

    private func captureDraftForMutation(_ draft: CaptureDraftEntityDescriptor) throws -> CaptureDraft {
        guard let captureDraft = draft.importableDraft else {
            throw NativeIntentActionError.unresolvedCaptureDraftEntity
        }
        return captureDraft
    }

    private func settingsMutation(
        from plan: SettingsActionPlan,
        expectedKind: NativeQueuedMutationKind
    ) throws -> NativeQueuedMutation {
        guard let mutation = plan.queuedMutation ?? plan.offlineFallbackMutation,
              mutation.queueableKind == expectedKind else {
            throw NativeIntentActionError.settingsActionUnavailable("Settings action did not produce \(expectedKind.rawValue).")
        }
        return mutation
    }

    private func settingsPlan(
        _ action: SettingsAction,
        connectivity: SettingsSurfaceConnectivity,
        now: (@Sendable () -> String)? = nil
    ) throws -> SettingsActionPlan {
        try settingsPlanBuilder(action, connectivity, now)
    }

    private func settingsHandoffPlan(
        _ plan: SettingsActionPlan,
        fallbackHandoff: SettingsSecureHandoff
    ) throws -> NativeIntentSettingsHandoffPlan {
        NativeIntentSettingsHandoffPlan(
            plan: plan,
            route: .settings,
            url: DeepLinkURLBuilder.url(for: .settings),
            secureHandoff: plan.secureHandoff ?? fallbackHandoff
        )
    }

    private func tokenIDForMutation(_ token: APITokenEntityDescriptor) throws -> String {
        guard !token.isPlaceholder else {
            throw NativeIntentActionError.unresolvedAPITokenEntity
        }
        let credentialID = try canonicalObjectID(token.credentialID, invalidError: .unresolvedAPITokenEntity)
        guard token.route == .settings else {
            throw NativeIntentActionError.unresolvedAPITokenEntity
        }
        return credentialID
    }

    private func accountConnectionIDForMutation(_ connection: AccountConnectionEntityDescriptor) throws -> String {
        guard !connection.isPlaceholder else {
            throw NativeIntentActionError.unresolvedAccountConnectionEntity
        }
        let connectionID = try canonicalObjectID(connection.connectionID, invalidError: .unresolvedAccountConnectionEntity)
        guard connection.route == .settings else {
            throw NativeIntentActionError.unresolvedAccountConnectionEntity
        }
        return connectionID
    }

    private func canonicalRecipeID(_ recipeID: String) throws -> String {
        try canonicalObjectID(recipeID, invalidError: .invalidRecipeID(recipeID))
    }

    private func canonicalCookbookID(_ cookbookID: String) throws -> String {
        try canonicalObjectID(cookbookID, invalidError: .invalidCookbookID(cookbookID))
    }

    private func canonicalObjectID(
        _ rawID: String,
        invalidError: NativeIntentActionError
    ) throws -> String {
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !id.isEmpty,
            !id.contains("/"),
            !id.contains("\\"),
            !id.contains(".."),
            id != ".",
            id != "..",
            id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else {
            throw invalidError
        }

        return id
    }

    private func recipeDetailRoute(
        _ recipe: RecipeEntityDescriptor,
        presentation: RecipePresentation
    ) throws -> AppRoute {
        guard !recipe.isPlaceholder else {
            throw NativeIntentActionError.unresolvedRecipeEntity
        }
        let id = try canonicalRecipeID(recipe.id)
        guard recipe.route == .recipeDetail(id: id, presentation: .detail) else {
            throw NativeIntentActionError.invalidRecipeID(recipe.id)
        }
        return .recipeDetail(id: id, presentation: presentation)
    }

    private func cookbookDetailRoute(_ cookbook: CookbookEntityDescriptor) throws -> AppRoute {
        guard !cookbook.isPlaceholder else {
            throw NativeIntentActionError.unresolvedCookbookEntity
        }
        let id = try canonicalCookbookID(cookbook.id)
        guard cookbook.route == .cookbookDetail(id: id) else {
            throw NativeIntentActionError.invalidCookbookID(cookbook.id)
        }
        return .cookbookDetail(id: id)
    }

    private func profileRoute(_ profile: ChefProfileEntityDescriptor) throws -> AppRoute {
        guard !profile.isPlaceholder else {
            throw NativeIntentActionError.unresolvedChefProfileEntity
        }
        guard AppRoute.isSafeProfileIdentifier(profile.username),
              profile.route == .profile(identifier: profile.username) else {
            throw NativeIntentActionError.invalidProfileIdentifier(profile.username)
        }
        return .profile(identifier: profile.username)
    }

    private func openRoute(_ route: AppRoute) -> NativeIntentAction {
        .openRoute(route, url: DeepLinkURLBuilder.url(for: route))
    }

    private func normalizedRecipeTitle(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func normalizedCookbookTitle(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func publicShareValue(
        route: AppRoute,
        title: String,
        subtitle: String
    ) throws -> NativeIntentShareValue {
        guard let payload = NativeSharePayload.publicRoute(route),
              payload.kind == NativeSharePayloadKind.publicURL,
              let publicURL = payload.publicURL else {
            throw NativeIntentActionError.shareUnavailable(route)
        }

        return NativeIntentShareValue(
            domain: payload.domain,
            kind: NativeSharePayloadKind.publicURL,
            publicURL: publicURL,
            route: route,
            title: title,
            subtitle: subtitle,
            privateTransferValue: nil
        )
    }

    private func canonicalShoppingItemID(_ itemID: String) throws -> String {
        let id = itemID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !id.isEmpty,
            !id.contains("/"),
            !id.contains("\\"),
            !id.contains(".."),
            id != ".",
            id != "..",
            id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else {
            throw NativeIntentActionError.invalidShoppingItemID(itemID)
        }

        return id
    }

    private func requiredTrimmed(_ value: String, error: NativeIntentActionError) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw error
        }

        return trimmed
    }

    private func normalizedOptional(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "" ? nil : normalized
    }

    private func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == "" ? nil : normalized
    }

    private func stableToken(_ value: String) -> String {
        let token = value.unicodeScalars.map { scalar -> String in
            if CharacterSet.alphanumerics.contains(scalar) || scalar.value == 95 {
                return String(scalar)
            }

            return "-"
        }.joined()

        return token.split(separator: "-").joined(separator: "-")
    }

}
