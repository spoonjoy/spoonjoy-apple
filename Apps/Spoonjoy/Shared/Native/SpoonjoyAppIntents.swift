import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents
import UniformTypeIdentifiers
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

private typealias SpoonjoyIntentNativeSharePayload = NativeSharePayload

@available(iOS 27.0, macOS 27.0, *)
enum SpoonjoySearchScopeOption: String, AppEnum {
    case all
    case recipes
    case cookbooks
    case chefs
    case shoppingList

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Search Scope")
    }

    static var caseDisplayRepresentations: [SpoonjoySearchScopeOption: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(title: "All"),
            .recipes: DisplayRepresentation(title: "Recipes"),
            .cookbooks: DisplayRepresentation(title: "Cookbooks"),
            .chefs: DisplayRepresentation(title: "Chefs"),
            .shoppingList: DisplayRepresentation(title: "Shopping List")
        ]
    }

    var searchScope: SearchScope {
        switch self {
        case .all:
            SearchScope.all
        case .recipes:
            SearchScope.recipes
        case .cookbooks:
            SearchScope.cookbooks
        case .chefs:
            SearchScope.chefs
        case .shoppingList:
            SearchScope.shoppingList
        }
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Recipe"
    static let description = IntentDescription("Open a Spoonjoy recipe.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    init() {
        recipe = SpoonjoyRecipeEntity()
    }

    init(recipe: SpoonjoyRecipeEntity) {
        self.recipe = recipe
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().openRecipe(recipe: recipe.descriptor)
        await SpoonjoyIntentTelemetry.recordCompleted(action, intentName: "OpenRecipeIntent", returnsValue: false)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening recipe in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenCookbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Cookbook"
    static let description = IntentDescription("Open a Spoonjoy cookbook.")

    @Parameter(title: "Cookbook", requestValueDialog: "Which Spoonjoy cookbook?")
    var cookbook: SpoonjoyCookbookEntity

    init() {
        cookbook = SpoonjoyCookbookEntity()
    }

    init(cookbook: SpoonjoyCookbookEntity) {
        self.cookbook = cookbook
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().openCookbook(cookbook: cookbook.descriptor)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening cookbook in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Profile"
    static let description = IntentDescription("Open a Spoonjoy chef profile.")

    @Parameter(title: "Profile", requestValueDialog: "Which Spoonjoy profile?")
    var profile: SpoonjoyChefProfileEntity

    init() {
        profile = SpoonjoyChefProfileEntity()
    }

    init(profile: SpoonjoyChefProfileEntity) {
        self.profile = profile
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().openProfile(profile: profile.descriptor)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening profile in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Settings"
    static let description = IntentDescription("Open Spoonjoy settings.")

    func perform() async throws -> some IntentResult {
        let action = NativeIntentActionResolver().openSettings()
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening settings in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ReadNotificationPreferencesIntent: AppIntent {
    static let title: LocalizedStringResource = "Read Notification Preferences"
    static let description = IntentDescription("Read your Spoonjoy notification preferences.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let stateWriter = try SpoonjoyIntentStateWriter()
        let connectivity = try await stateWriter.notificationAPNsConnectivity()
        let data = try await stateWriter.notificationAPNsSurfaceData()
        let summary = try NativeIntentActionResolver().readNotificationPreferences(
            data: data,
            hasCachedPreferences: try await stateWriter.notificationAPNsHasCachedPreferences(),
            connectivity: connectivity
        )
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(value: summary.value, dialog: IntentDialog(stringLiteral: summary.value))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct UpdateNotificationPreferencesIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Notification Preferences"
    static let description = IntentDescription("Update your Spoonjoy notification preferences.")

    @Parameter(title: "Spoons")
    var spoons: Bool?

    @Parameter(title: "Forks")
    var forks: Bool?

    @Parameter(title: "Cookbook Saves")
    var cookbookSaves: Bool?

    @Parameter(title: "Fellow-Chef Cooks")
    var fellowChefCooks: Bool?

    init() {
        spoons = nil
        forks = nil
        cookbookSaves = nil
        fellowChefCooks = nil
    }

    init(spoons: Bool?, forks: Bool?, cookbookSaves: Bool?, fellowChefCooks: Bool?) {
        self.spoons = spoons
        self.forks = forks
        self.cookbookSaves = cookbookSaves
        self.fellowChefCooks = fellowChefCooks
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let stateWriter = try SpoonjoyIntentStateWriter()
        let connectivity = try await stateWriter.notificationAPNsConnectivity()
        let data = try await stateWriter.notificationAPNsSurfaceData()
        let requiresCurrentPreferences = spoons == nil || forks == nil || cookbookSaves == nil || fellowChefCooks == nil
        if requiresCurrentPreferences {
            _ = try NativeIntentActionResolver().readNotificationPreferences(
                data: data,
                hasCachedPreferences: try await stateWriter.notificationAPNsHasCachedPreferences(),
                connectivity: connectivity
            )
        }
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: spoons ?? data.preferences.notifySpoonOnMyRecipe,
            notifyForkOfMyRecipe: forks ?? data.preferences.notifyForkOfMyRecipe,
            notifyCookbookSaveOfMine: cookbookSaves ?? data.preferences.notifyCookbookSaveOfMine,
            notifyFellowChefOriginCook: fellowChefCooks ?? data.preferences.notifyFellowChefOriginCook
        )
        let action = try NativeIntentActionResolver().updateNotificationPreferences(
            preferences: preferences,
            connectivity: connectivity,
            deliveryCapability: data.deliveryCapability,
            createdAt: createdAt
        )
        let status = try await stateWriter.performNotificationAPNsActionStatus(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: status.dialogMessage(completed: "Updated notification preferences in Spoonjoy.", queued: "Queued notification preference update in Spoonjoy."))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenNotificationAPNsStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Notification APNs Status"
    static let description = IntentDescription("Open Spoonjoy notification delivery status.")

    func perform() async throws -> some IntentResult {
        let data = try await SpoonjoyIntentStateWriter().notificationAPNsSurfaceData()
        let blockerState: APNsDeliveryBlockerState = data.deliveryCapability.blockerState
        _ = blockerState
        _ = AppleDeveloperProgramBlocker.artifactFileName
        let action = NativeIntentActionResolver().openNotificationAPNsStatus(data: data)
        let message = action.deliveryBlocker?.ownerAction ?? "Opening notification delivery status in Spoonjoy"
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: IntentDialog(stringLiteral: message))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct UpdateProfileDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Profile Display"
    static let description = IntentDescription("Update your Spoonjoy profile display.")

    @Parameter(title: "Email")
    var email: String

    @Parameter(title: "Username")
    var username: String

    init() {
        email = ""
        username = ""
    }

    init(email: String, username: String) {
        self.email = email
        self.username = username
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().updateProfileDisplay(
            email: email,
            username: username,
            connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity(),
            createdAt: createdAt
        )
        let status = try await SpoonjoyIntentStateWriter().performSettingsActionStatus(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: status.dialogMessage(completed: "Updated profile in Spoonjoy.", queued: "Queued profile update in Spoonjoy."))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct UpdateProfilePhotoIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Profile Photo"
    static let description = IntentDescription("Update your Spoonjoy profile photo.")

    @Parameter(title: "Photo")
    var photo: IntentFile

    init() {
        photo = IntentFile(data: Data(), filename: "profile-photo.jpg", type: .jpeg)
    }

    init(photo: IntentFile) {
        self.photo = photo
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let contentType = photo.type?.preferredMIMEType ?? "application/octet-stream"
        let media = NativeStagedMediaUpload(
            localStageID: "intent-profile-photo-\(createdAt)",
            fileName: photo.filename,
            contentType: contentType,
            data: photo.data
        )
        _ = SettingsProfilePhotoStagingPolicy.webProfileParity
        let action = try NativeIntentActionResolver().updateProfilePhoto(
            photo: media,
            connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity(),
            createdAt: createdAt
        )
        let status = try await SpoonjoyIntentStateWriter().performSettingsActionStatus(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: status.dialogMessage(completed: "Updated profile photo in Spoonjoy.", queued: "Queued profile photo update in Spoonjoy."))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct RemoveProfilePhotoIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Profile Photo"
    static let description = IntentDescription("Remove your Spoonjoy profile photo.")

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().removeProfilePhoto(
            connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity(),
            createdAt: createdAt
        )
        let status = try await SpoonjoyIntentStateWriter().performSettingsActionStatus(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: status.dialogMessage(completed: "Removed profile photo in Spoonjoy.", queued: "Queued profile photo removal in Spoonjoy."))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenAPITokensIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Agent Access"
    static let description = IntentDescription("Open Spoonjoy agent access key settings.")

    func perform() async throws -> some IntentResult {
        let action = NativeIntentActionResolver().openAPITokens()
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening agent access settings in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct CreateAPITokenIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Agent Access Key"
    static let description = IntentDescription("Create a Spoonjoy access key for agents and tools.")

    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Scopes")
    var scopes: [String]

    init() {
        name = ""
        scopes = []
    }

    init(name: String, scopes: [String]) {
        self.name = name
        self.scopes = scopes
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().createAPIToken(
            name: name,
            scopes: scopes,
            connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity()
        )
        let offlineMessage = SettingsOnlineOnlyReason.apiTokenCreate.message
        let message = action.onlineOnlyReason?.message ?? action.plan.userFacingMessage ?? "Opening agent access settings in Spoonjoy."
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "\(action.onlineOnlyReason == nil ? message : offlineMessage)\(action.onlineOnlyReason == nil ? "" : " This action was not queued.")")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct RevokeAPITokenIntent: AppIntent {
    static let title: LocalizedStringResource = "Revoke Agent Access Key"
    static let description = IntentDescription("Revoke a Spoonjoy access key for agents and tools.")

    @Parameter(title: "Access Key", requestValueDialog: "Which access key should be revoked?")
    var token: SpoonjoyAPITokenEntity

    init() {
        token = SpoonjoyAPITokenEntity()
    }

    init(token: SpoonjoyAPITokenEntity) {
        self.token = token
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let action = try NativeIntentActionResolver().revokeAPIToken(token: token.descriptor, connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity())
        try await SpoonjoyIntentStateWriter().performSettingsAction(action)
        let offlineMessage = SettingsOnlineOnlyReason.apiTokenRevoke.message
        let message = action.onlineOnlyReason?.message ?? "Revoked access key in Spoonjoy."
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "\(action.onlineOnlyReason == nil ? message : offlineMessage)\(action.onlineOnlyReason == nil ? "" : " This action was not queued.")")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenAccountConnectionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Account Connections"
    static let description = IntentDescription("Open Spoonjoy account connection settings.")

    func perform() async throws -> some IntentResult {
        let action = NativeIntentActionResolver().openAccountConnections()
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening account connections in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct DisconnectAccountConnectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Disconnect Account Connection"
    static let description = IntentDescription("Disconnect a Spoonjoy account connection.")

    @Parameter(title: "Connection", requestValueDialog: "Which connection should be disconnected?")
    var connection: SpoonjoyAccountConnectionEntity

    init() {
        connection = SpoonjoyAccountConnectionEntity()
    }

    init(connection: SpoonjoyAccountConnectionEntity) {
        self.connection = connection
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let action = try NativeIntentActionResolver().disconnectAccountConnection(connection: connection.descriptor, connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity())
        try await SpoonjoyIntentStateWriter().performSettingsAction(action)
        let offlineMessage = SettingsOnlineOnlyReason.oauthConnectionDisconnect.message
        let message = action.onlineOnlyReason?.message ?? "Disconnected account connection in Spoonjoy."
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "\(action.onlineOnlyReason == nil ? message : offlineMessage)\(action.onlineOnlyReason == nil ? "" : " This action was not queued.")")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenPasskeysIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Passkeys"
    static let description = IntentDescription("Open Spoonjoy passkey settings.")

    func perform() async throws -> some IntentResult {
        let plan = try NativeIntentActionResolver().openPasskeys(connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity())
        if plan.onlineOnlyReason != nil {
            return .result(dialog: "\(SettingsOnlineOnlyReason.credentialHandoff.message) This action was not queued.")
        }
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(plan.secureHandoff.url), dialog: "Opening passkey settings in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenPasswordIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Password"
    static let description = IntentDescription("Open Spoonjoy password settings.")

    func perform() async throws -> some IntentResult {
        let plan = try NativeIntentActionResolver().openPassword(connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity())
        if plan.onlineOnlyReason != nil {
            return .result(dialog: "\(SettingsOnlineOnlyReason.credentialHandoff.message) This action was not queued.")
        }
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(plan.secureHandoff.url), dialog: "Opening password settings in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct LinkProviderIntent: AppIntent {
    static let title: LocalizedStringResource = "Link Provider"
    static let description = IntentDescription("Link a sign-in provider to Spoonjoy.")

    @Parameter(title: "Provider")
    var provider: SpoonjoySettingsAuthProviderOption

    init() {
        provider = .google
    }

    init(provider: SpoonjoySettingsAuthProviderOption) {
        self.provider = provider
    }

    func perform() async throws -> some IntentResult {
        let plan = try NativeIntentActionResolver().linkProvider(provider: provider.authProvider, connectivity: try await SpoonjoyIntentStateWriter().settingsConnectivity())
        if plan.onlineOnlyReason != nil {
            return .result(dialog: "\(SettingsOnlineOnlyReason.credentialHandoff.message) This action was not queued.")
        }
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(plan.secureHandoff.url), dialog: "Opening provider link in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct LogoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Out"
    static let description = IntentDescription("Log out of Spoonjoy.")

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let stateWriter = try SpoonjoyIntentStateWriter()
        let action = try NativeIntentActionResolver().logout(connectivity: try await stateWriter.settingsConnectivity())
        try await stateWriter.performSettingsAction(action)
        let offlineMessage = SettingsOnlineOnlyReason.logout.message
        let message = action.onlineOnlyReason?.message ?? "Logged out of Spoonjoy."
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "\(action.onlineOnlyReason == nil ? message : offlineMessage)\(action.onlineOnlyReason == nil ? "" : " This action was not queued.")")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct RevokeCurrentSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Revoke Current Session"
    static let description = IntentDescription("Revoke the current Spoonjoy session.")

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let stateWriter = try SpoonjoyIntentStateWriter()
        let action = try NativeIntentActionResolver().revokeCurrentSession(connectivity: try await stateWriter.settingsConnectivity())
        try await stateWriter.performSettingsAction(action)
        let offlineMessage = SettingsOnlineOnlyReason.sessionRevoke.message
        let message = action.onlineOnlyReason?.message ?? "Revoked the current Spoonjoy session."
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "\(action.onlineOnlyReason == nil ? message : offlineMessage)\(action.onlineOnlyReason == nil ? "" : " This action was not queued.")")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SearchSpoonjoyIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Spoonjoy"
    static let description = IntentDescription("Search recipes, cookbooks, chefs, and shopping-list items in Spoonjoy.")

    @Parameter(title: "Query")
    var query: String

    @Parameter(title: "Scope")
    var scope: SpoonjoySearchScopeOption

    init() {
        query = ""
        scope = .all
    }

    init(query: String, scope: SpoonjoySearchScopeOption = .all) {
        self.query = query
        self.scope = scope
    }

    func perform() async throws -> some IntentResult {
        let action = NativeIntentActionResolver().searchSpoonjoy(query: query, scope: scope.searchScope)
        await SpoonjoyIntentTelemetry.recordCompleted(action, intentName: "SearchSpoonjoyIntent", returnsValue: false)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Searching Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ShareRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Share Recipe"
    static let description = IntentDescription("Share a public Spoonjoy recipe URL.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    init() {
        recipe = SpoonjoyRecipeEntity()
    }

    init(recipe: SpoonjoyRecipeEntity) {
        self.recipe = recipe
    }

    func perform() async throws -> some IntentResult {
        let share = try NativeIntentActionResolver().shareRecipe(recipe: recipe.descriptor)
        guard let publicURL = share.publicURL else {
            throw NativeIntentActionError.shareUnavailable(recipe.descriptor.route)
        }
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(publicURL), dialog: "Sharing recipe from Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ShareCookbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Share Cookbook"
    static let description = IntentDescription("Share a public Spoonjoy cookbook URL.")

    @Parameter(title: "Cookbook", requestValueDialog: "Which Spoonjoy cookbook?")
    var cookbook: SpoonjoyCookbookEntity

    init() {
        cookbook = SpoonjoyCookbookEntity()
    }

    init(cookbook: SpoonjoyCookbookEntity) {
        self.cookbook = cookbook
    }

    func perform() async throws -> some IntentResult {
        let share = try NativeIntentActionResolver().shareCookbook(cookbook: cookbook.descriptor)
        guard let publicURL = share.publicURL else {
            throw NativeIntentActionError.shareUnavailable(cookbook.descriptor.route)
        }
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(publicURL), dialog: "Sharing cookbook from Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ShareShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "Share Shopping List"
    static let description = IntentDescription("Share a private Spoonjoy shopping-list transfer value.")

    @Parameter(title: "Shopping List", requestValueDialog: "Which Spoonjoy shopping list?")
    var shoppingList: SpoonjoyShoppingListEntity

    init() {
        shoppingList = SpoonjoyShoppingListEntity()
    }

    init(shoppingList: SpoonjoyShoppingListEntity) {
        self.shoppingList = shoppingList
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let share = try NativeIntentActionResolver().shareShoppingList(shoppingList: shoppingList.descriptor)
        guard let privateTransferValue = share.privateTransferValue,
              share.publicURL == nil,
              case .privateTransfer = share.kind else {
            throw NativeIntentActionError.shareUnavailable(shoppingList.descriptor.route)
        }
        await SpoonjoyIntentTelemetry.recordCompleted(share, intentName: "ShareShoppingListIntent", returnsValue: true)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(value: privateTransferValue, dialog: "Prepared a private Spoonjoy shopping-list transfer")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct StartCookModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Cooking"
    static let description = IntentDescription("Open a Spoonjoy recipe directly in cook mode.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    init() {
        recipe = SpoonjoyRecipeEntity()
    }

    init(recipe: SpoonjoyRecipeEntity) {
        self.recipe = recipe
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().startCookMode(recipe: recipe.descriptor)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Starting cook mode in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ContinueCookModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue Cooking"
    static let description = IntentDescription("Continue cooking a Spoonjoy recipe.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    init() {
        recipe = SpoonjoyRecipeEntity()
    }

    init(recipe: SpoonjoyRecipeEntity) {
        self.recipe = recipe
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().continueCookMode(recipe: recipe.descriptor)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Continuing cook mode in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ForkRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Fork Recipe"
    static let description = IntentDescription("Create a Spoonjoy variation of a recipe.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    @Parameter(title: "Title")
    var titleOverride: String

    init() {
        recipe = SpoonjoyRecipeEntity()
        titleOverride = ""
    }

    init(recipe: SpoonjoyRecipeEntity, titleOverride: String = "") {
        self.recipe = recipe
        self.titleOverride = titleOverride
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().forkRecipe(recipe: recipe.descriptor, title: titleOverride, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued recipe fork in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SaveRecipeToCookbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Recipe to Cookbook"
    static let description = IntentDescription("Save a Spoonjoy recipe to a cookbook.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    @Parameter(title: "Cookbook", requestValueDialog: "Which Spoonjoy cookbook?")
    var cookbook: SpoonjoyCookbookEntity

    init() {
        recipe = SpoonjoyRecipeEntity()
        cookbook = SpoonjoyCookbookEntity()
    }

    init(recipe: SpoonjoyRecipeEntity, cookbook: SpoonjoyCookbookEntity) {
        self.recipe = recipe
        self.cookbook = cookbook
    }

    func perform() async throws -> some IntentResult {
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().saveRecipeToCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cookbook save in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct CreateCookbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Cookbook"
    static let description = IntentDescription("Create a Spoonjoy cookbook.")

    @Parameter(title: "Title")
    var title: String

    init() {
        title = ""
    }

    init(title: String) {
        self.title = title
    }

    func perform() async throws -> some IntentResult {
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().createCookbook(title: title, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cookbook creation in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct RenameCookbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Rename Cookbook"
    static let description = IntentDescription("Rename one of your Spoonjoy cookbooks.")

    @Parameter(title: "Cookbook", requestValueDialog: "Which Spoonjoy cookbook?")
    var cookbook: SpoonjoyCookbookEntity

    @Parameter(title: "Title")
    var title: String

    init() {
        cookbook = SpoonjoyCookbookEntity()
        title = ""
    }

    init(cookbook: SpoonjoyCookbookEntity, title: String) {
        self.cookbook = cookbook
        self.title = title
    }

    func perform() async throws -> some IntentResult {
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().renameCookbook(cookbook: cookbook.descriptor, title: title, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cookbook rename in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct DeleteCookbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Cookbook"
    static let description = IntentDescription("Delete one of your Spoonjoy cookbooks.")

    @Parameter(title: "Cookbook", requestValueDialog: "Which Spoonjoy cookbook?")
    var cookbook: SpoonjoyCookbookEntity

    init() {
        cookbook = SpoonjoyCookbookEntity()
    }

    init(cookbook: SpoonjoyCookbookEntity) {
        self.cookbook = cookbook
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().deleteCookbook(cookbook: cookbook.descriptor, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cookbook deletion in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct AddRecipeToCookbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Recipe to Cookbook"
    static let description = IntentDescription("Add a Spoonjoy recipe to one of your cookbooks.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    @Parameter(title: "Cookbook", requestValueDialog: "Which Spoonjoy cookbook?")
    var cookbook: SpoonjoyCookbookEntity

    init() {
        recipe = SpoonjoyRecipeEntity()
        cookbook = SpoonjoyCookbookEntity()
    }

    init(recipe: SpoonjoyRecipeEntity, cookbook: SpoonjoyCookbookEntity) {
        self.recipe = recipe
        self.cookbook = cookbook
    }

    func perform() async throws -> some IntentResult {
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().addRecipeToCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cookbook recipe add in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct RemoveRecipeFromCookbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Recipe from Cookbook"
    static let description = IntentDescription("Remove a Spoonjoy recipe from a cookbook.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    @Parameter(title: "Cookbook", requestValueDialog: "Which Spoonjoy cookbook?")
    var cookbook: SpoonjoyCookbookEntity

    init() {
        recipe = SpoonjoyRecipeEntity()
        cookbook = SpoonjoyCookbookEntity()
    }

    init(recipe: SpoonjoyRecipeEntity, cookbook: SpoonjoyCookbookEntity) {
        self.recipe = recipe
        self.cookbook = cookbook
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().removeRecipeFromCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cookbook removal in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct DeleteRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Recipe"
    static let description = IntentDescription("Delete one of your Spoonjoy recipes.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    init() {
        recipe = SpoonjoyRecipeEntity()
    }

    init(recipe: SpoonjoyRecipeEntity) {
        self.recipe = recipe
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().deleteRecipe(recipe: recipe.descriptor, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued recipe deletion in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct AddShoppingListItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Shopping Item"
    static let description = IntentDescription("Add an item to the Spoonjoy shopping list.")

    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Quantity")
    var quantity: Double?

    @Parameter(title: "Unit")
    var unit: String?

    init() {
        name = ""
        quantity = nil
        unit = nil
    }

    init(name: String, quantity: Double? = nil, unit: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().addShoppingListItem(
            name: name,
            quantity: quantity,
            unit: unit,
            createdAt: createdAt
        )
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued \(name) in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SetShoppingListItemCheckedIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Shopping Item Checked"
    static let description = IntentDescription("Check or uncheck a Spoonjoy shopping-list item.")

    @Parameter(title: "Shopping Item", requestValueDialog: "Which Spoonjoy shopping item?")
    var item: SpoonjoyShoppingItemEntity

    @Parameter(title: "Checked")
    var checked: Bool

    init() {
        item = SpoonjoyShoppingItemEntity()
        checked = true
    }

    init(item: SpoonjoyShoppingItemEntity, checked: Bool) {
        self.item = item
        self.checked = checked
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let itemID = try item.resolvedShoppingItemID()
        let action = try NativeIntentActionResolver().setShoppingListItemChecked(
            itemID: itemID,
            checked: checked,
            createdAt: createdAt
        )
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Updated shopping item in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct RemoveShoppingListItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Shopping Item"
    static let description = IntentDescription("Remove an item from the Spoonjoy shopping list.")

    @Parameter(title: "Shopping Item", requestValueDialog: "Which Spoonjoy shopping item?")
    var item: SpoonjoyShoppingItemEntity

    init() {
        item = SpoonjoyShoppingItemEntity()
    }

    init(item: SpoonjoyShoppingItemEntity) {
        self.item = item
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let itemID = try item.resolvedShoppingItemID()
        let action = try NativeIntentActionResolver().removeShoppingListItem(
            itemID: itemID,
            createdAt: createdAt
        )
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Removed shopping item in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct AddRecipeIngredientsToShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Recipe Ingredients"
    static let description = IntentDescription("Add a Spoonjoy recipe's ingredients to the shopping list.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe?")
    var recipe: SpoonjoyRecipeEntity

    @Parameter(title: "Scale Factor")
    var scaleFactor: Double

    init() {
        recipe = SpoonjoyRecipeEntity()
        scaleFactor = 1
    }

    init(recipe: SpoonjoyRecipeEntity, scaleFactor: Double = 1) {
        self.recipe = recipe
        self.scaleFactor = scaleFactor
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let recipeID = try recipe.resolvedRecipeID()
        let action = try NativeIntentActionResolver().addRecipeIngredientsToShoppingList(
            recipeID: recipeID,
            scaleFactor: scaleFactor,
            createdAt: createdAt
        )
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued recipe ingredients in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ClearCompletedShoppingItemsIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Completed Shopping Items"
    static let description = IntentDescription("Remove completed items from the Spoonjoy shopping list.")

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = NativeIntentActionResolver().clearCompletedShoppingItems(createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Cleared completed shopping items in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ClearShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Shopping List"
    static let description = IntentDescription("Remove all items from the Spoonjoy shopping list.")

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = NativeIntentActionResolver().clearShoppingList(createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Cleared the Spoonjoy shopping list")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct LogCookIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Cook"
    static let description = IntentDescription("Log a cook on a Spoonjoy recipe.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe did you cook?")
    var recipe: SpoonjoyRecipeEntity

    @Parameter(title: "Note")
    var note: String?

    @Parameter(title: "Next Time")
    var nextTime: String?

    @Parameter(title: "Cooked At")
    var cookedAt: String?

    init() {
        recipe = SpoonjoyRecipeEntity()
        note = nil
        nextTime = nil
        cookedAt = nil
    }

    init(recipe: SpoonjoyRecipeEntity, note: String? = nil, nextTime: String? = nil, cookedAt: String? = nil) {
        self.recipe = recipe
        self.note = note
        self.nextTime = nextTime
        self.cookedAt = cookedAt
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().logCook(recipe: recipe.descriptor, note: note, nextTime: nextTime, cookedAt: cookedAt, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cook log in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct EditCookLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Cook Log"
    static let description = IntentDescription("Edit one of your Spoonjoy cook logs.")

    @Parameter(title: "Cook Log", requestValueDialog: "Which Spoonjoy cook log?")
    var spoon: SpoonjoySpoonEntity

    @Parameter(title: "Note")
    var note: String?

    @Parameter(title: "Next Time")
    var nextTime: String?

    @Parameter(title: "Cooked At")
    var cookedAt: String?

    init() {
        spoon = SpoonjoySpoonEntity()
        note = nil
        nextTime = nil
        cookedAt = nil
    }

    init(spoon: SpoonjoySpoonEntity, note: String? = nil, nextTime: String? = nil, cookedAt: String? = nil) {
        self.spoon = spoon
        self.note = note
        self.nextTime = nextTime
        self.cookedAt = cookedAt
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().editCookLog(spoon: spoon.descriptor, note: note, nextTime: nextTime, cookedAt: cookedAt, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cook-log edit in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct DeleteCookLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Cook Log"
    static let description = IntentDescription("Delete one of your Spoonjoy cook logs.")

    @Parameter(title: "Cook Log", requestValueDialog: "Which Spoonjoy cook log?")
    var spoon: SpoonjoySpoonEntity

    init() {
        spoon = SpoonjoySpoonEntity()
    }

    init(spoon: SpoonjoySpoonEntity) {
        self.spoon = spoon
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().deleteCookLog(spoon: spoon.descriptor, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cook-log deletion in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct CreateCoverFromSpoonIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Cover from Cook Log"
    static let description = IntentDescription("Use a Spoonjoy cook-log photo as a recipe cover.")

    @Parameter(title: "Recipe", requestValueDialog: "Which Spoonjoy recipe gets the cover?")
    var recipe: SpoonjoyRecipeEntity

    @Parameter(title: "Cook Log", requestValueDialog: "Which Spoonjoy cook log has the photo?")
    var spoon: SpoonjoySpoonEntity

    @Parameter(title: "Activate")
    var activate: Bool

    @Parameter(title: "Generate Editorial")
    var generateEditorial: Bool

    init() {
        recipe = SpoonjoyRecipeEntity()
        spoon = SpoonjoySpoonEntity()
        activate = true
        generateEditorial = false
    }

    init(recipe: SpoonjoyRecipeEntity, spoon: SpoonjoySpoonEntity, activate: Bool = true, generateEditorial: Bool = false) {
        self.recipe = recipe
        self.spoon = spoon
        self.activate = activate
        self.generateEditorial = generateEditorial
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().createCoverFromSpoon(recipe: recipe.descriptor, spoon: spoon.descriptor, activate: activate, generateEditorial: generateEditorial, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued spoon photo as a cover in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct CaptureRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Recipe"
    static let description = IntentDescription("Save a recipe URL or note into Spoonjoy capture drafts.")

    @Parameter(title: "Source", requestValueDialog: "What recipe URL or text should Spoonjoy capture?")
    var source: String

    init() {
        source = ""
    }

    init(source: String) {
        self.source = source
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().captureRecipe(
            source: source,
            createdAt: createdAt
        )
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Saved a Spoonjoy capture draft")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SubmitCaptureImportIntent: AppIntent {
    static let title: LocalizedStringResource = "Submit Capture Import"
    static let description = IntentDescription("Queue a Spoonjoy capture draft for recipe import.")

    @Parameter(title: "Capture Draft", requestValueDialog: "Which Spoonjoy capture draft should be imported?")
    var draft: SpoonjoyCaptureDraftEntity

    init() {
        draft = SpoonjoyCaptureDraftEntity()
    }

    init(draft: SpoonjoyCaptureDraftEntity) {
        self.draft = draft
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().submitCaptureImport(draft: draft.descriptor, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyIntentTelemetry.recordCompleted(action, intentName: "SubmitCaptureImportIntent", returnsValue: false)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued capture draft import in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct OpenCaptureDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Capture Draft"
    static let description = IntentDescription("Open a Spoonjoy capture draft.")

    @Parameter(title: "Capture Draft", requestValueDialog: "Which Spoonjoy capture draft should open?")
    var draft: SpoonjoyCaptureDraftEntity

    init() {
        draft = SpoonjoyCaptureDraftEntity()
    }

    init(draft: SpoonjoyCaptureDraftEntity) {
        self.draft = draft
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().openCaptureDraft(draft: draft.descriptor)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening capture draft in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct DiscardCaptureDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Discard Capture Draft"
    static let description = IntentDescription("Discard a Spoonjoy capture draft and cancel its pending import.")

    @Parameter(title: "Capture Draft", requestValueDialog: "Which Spoonjoy capture draft should be discarded?")
    var draft: SpoonjoyCaptureDraftEntity

    init() {
        draft = SpoonjoyCaptureDraftEntity()
    }

    init(draft: SpoonjoyCaptureDraftEntity) {
        self.draft = draft
    }

    func perform() async throws -> some IntentResult {
        try await requestConfirmation()
        let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().discardCaptureDraft(draft: draft.descriptor, currentChefID: currentChefID, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Discarded capture draft in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenRecipeIntent(),
            phrases: [
                "Open a recipe in \(.applicationName)",
                "Show my recipe in \(.applicationName)"
            ],
            shortTitle: "Open Recipe",
            systemImageName: "book"
        )
        AppShortcut(
            intent: OpenCookbookIntent(),
            phrases: [
                "Open a cookbook in \(.applicationName)",
                "Show my cookbook in \(.applicationName)"
            ],
            shortTitle: "Open Cookbook",
            systemImageName: "books.vertical"
        )
        AppShortcut(
            intent: SearchSpoonjoyIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Find something in \(.applicationName)"
            ],
            shortTitle: "Search Spoonjoy",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: ShareRecipeIntent(),
            phrases: [
                "Share a recipe from \(.applicationName)",
                "Send a \(.applicationName) recipe"
            ],
            shortTitle: "Share Recipe",
            systemImageName: "square.and.arrow.up"
        )
        AppShortcut(
            intent: ShareCookbookIntent(),
            phrases: [
                "Share a cookbook from \(.applicationName)",
                "Send a \(.applicationName) cookbook"
            ],
            shortTitle: "Share Cookbook",
            systemImageName: "square.and.arrow.up.on.square"
        )
        AppShortcut(
            intent: ShareShoppingListIntent(),
            phrases: [
                "Share my shopping list from \(.applicationName)",
                "Export my \(.applicationName) shopping list"
            ],
            shortTitle: "Share Shopping List",
            systemImageName: "cart"
        )
        AppShortcut(
            intent: StartCookModeIntent(),
            phrases: [
                "Start cooking in \(.applicationName)",
                "Cook with \(.applicationName)"
            ],
            shortTitle: "Start Cooking",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: ContinueCookModeIntent(),
            phrases: [
                "Continue cooking in \(.applicationName)",
                "Resume cooking with \(.applicationName)"
            ],
            shortTitle: "Continue Cooking",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: AddShoppingListItemIntent(),
            phrases: [
                "Add an item in \(.applicationName)",
                "Add to my \(.applicationName) shopping list"
            ],
            shortTitle: "Add Shopping Item",
            systemImageName: "cart.badge.plus"
        )
        AppShortcut(
            intent: CaptureRecipeIntent(),
            phrases: [
                "Capture a recipe in \(.applicationName)",
                "Save a recipe to \(.applicationName)"
            ],
            shortTitle: "Capture Recipe",
            systemImageName: "square.and.arrow.down"
        )
    }
}

@available(iOS 27.0, macOS 27.0, *)
private enum SpoonjoyIntentShortcutBudget {
    static let appShortcutLimit = 10

    static var shortcutsLibraryOnlyIntentNames: [String] {
        [
            String(describing: OpenProfileIntent()),
            String(describing: OpenSettingsIntent()),
            String(describing: ReadNotificationPreferencesIntent()),
            String(describing: UpdateNotificationPreferencesIntent()),
            String(describing: OpenNotificationAPNsStatusIntent()),
            String(describing: UpdateProfileDisplayIntent()),
            String(describing: UpdateProfilePhotoIntent()),
            String(describing: RemoveProfilePhotoIntent()),
            String(describing: OpenAPITokensIntent()),
            String(describing: CreateAPITokenIntent()),
            String(describing: RevokeAPITokenIntent()),
            String(describing: OpenAccountConnectionsIntent()),
            String(describing: DisconnectAccountConnectionIntent()),
            String(describing: OpenPasskeysIntent()),
            String(describing: OpenPasswordIntent()),
            String(describing: LinkProviderIntent()),
            String(describing: LogoutIntent()),
            String(describing: RevokeCurrentSessionIntent()),
            String(describing: SetShoppingListItemCheckedIntent()),
            String(describing: RemoveShoppingListItemIntent()),
            String(describing: AddRecipeIngredientsToShoppingListIntent()),
            String(describing: ClearCompletedShoppingItemsIntent()),
            String(describing: ClearShoppingListIntent()),
            String(describing: ForkRecipeIntent()),
            String(describing: CreateCookbookIntent()),
            String(describing: RenameCookbookIntent()),
            String(describing: DeleteCookbookIntent()),
            String(describing: AddRecipeToCookbookIntent()),
            String(describing: SaveRecipeToCookbookIntent()),
            String(describing: RemoveRecipeFromCookbookIntent()),
            String(describing: DeleteRecipeIntent()),
            String(describing: LogCookIntent()),
            String(describing: EditCookLogIntent()),
            String(describing: DeleteCookLogIntent()),
            String(describing: CreateCoverFromSpoonIntent()),
            String(describing: SubmitCaptureImportIntent()),
            String(describing: OpenCaptureDraftIntent()),
            String(describing: DiscardCaptureDraftIntent())
        ]
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyInteractionDonor {
    func donate(_ intent: some AppIntent) async throws {
        _ = try await IntentDonationManager.shared.donate(intent: intent)
    }

    func donateBestEffort(_ intent: some AppIntent) async {
        do {
            try await donate(intent)
        } catch {
            return
        }
    }

    func deleteDonations(matching entityIdentifier: EntityIdentifier) async throws {
        try await IntentDonationManager.shared.deleteDonations(matching: IntentDonationMatchingPredicate.entityIdentifier(entityIdentifier))
    }

    func deleteDonations<Intent: AppIntent>(matching intentType: Intent.Type) async throws {
        try await IntentDonationManager.shared.deleteDonations(matching: IntentDonationMatchingPredicate.intentType(intentType))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyIntentTelemetry {
    static func recordCompleted(_ action: NativeIntentAction, intentName: String, returnsValue: Bool) async {
        await record(action.telemetryDescriptor(intentName: intentName, returnsValue: returnsValue))
    }

    static func recordCompleted(_ share: NativeIntentShareValue, intentName: String, returnsValue: Bool) async {
        await record(share.telemetryDescriptor(intentName: intentName, returnsValue: returnsValue))
    }

    static func recordFailed(_ error: Error, intentName: String) async {
        await record(NativeIntentTelemetryDescriptor.failed(intentName: intentName, error: error))
    }

    private static func record(_ descriptor: NativeIntentTelemetryDescriptor) async {
        do {
            let refresher = SpoonjoyIntentAPIRefresher(vault: KeychainTokenVault())
            let configuration = try await refresher.validConfiguration()
            _ = try await URLSessionAPITransport(authenticationRefresher: refresher).send(
                try NativeTelemetryRequests.recordEvent(descriptor.telemetryEvent(
                    environment: "production",
                    metadata: metadata()
                )),
                configuration: configuration,
                decode: NativeTelemetryResponse.self
            )
        } catch {
            return
        }
    }

    private static func metadata() -> NativeTelemetryAppMetadata {
        let info = Bundle.main.infoDictionary
        return NativeTelemetryAppMetadata(
            platform: platform(),
            appVersion: nonblankInfoString(info?["CFBundleShortVersionString"]) ?? "0.0.0",
            buildNumber: nonblankInfoString(info?["CFBundleVersion"]) ?? "0"
        )
    }

    private static func platform() -> String {
        #if os(iOS)
        "ios"
        #elseif os(macOS)
        "macos"
        #else
        "unknown"
        #endif
    }

    private static func nonblankInfoString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum SpoonjoyIntentClock {
    static func timestamp(date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

@available(iOS 27.0, macOS 27.0, *)
private enum SpoonjoyIntentConnectivityProbe {
    static func settingsSurfaceConnectivity() async -> SettingsSurfaceConnectivity {
        var request = URLRequest(url: APIClientConfiguration.spoonjoyProduction.baseURL)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 3

        do {
            _ = try await URLSession.shared.data(for: request)
            return .online
        } catch let error as URLError where spoonjoyIntentIsOffline(error.code) {
            return .offline
        } catch {
            return .online
        }
    }
}

@available(iOS 27.0, macOS 27.0, *)
private struct SpoonjoyIntentAPIRefresher: APIAuthenticationRefresher {
    private let refreshCoordinator: RefreshCoordinator
    private let baseURL: URL

    init(vault: any TokenVault, baseURL: URL = APIClientConfiguration.spoonjoyProduction.baseURL) {
        self.baseURL = baseURL
        self.refreshCoordinator = RefreshCoordinator(vault: vault) { clientID, refreshToken in
            try await SpoonjoyIntentOAuthSupport.sendDecoded(
                OAuthRequests.refreshToken(clientID: clientID, refreshToken: refreshToken),
                configuration: APIClientConfiguration(baseURL: baseURL)
            )
        }
    }

    func validConfiguration() async throws -> APIClientConfiguration {
        let session = try await refreshCoordinator.validSession(at: Date())
        return APIClientConfiguration(baseURL: baseURL, bearerToken: session.accessToken)
    }

    func refreshedConfiguration(
        after _: APIError,
        configuration: APIClientConfiguration
    ) async throws -> APIClientConfiguration {
        let session = try await refreshCoordinator.validSession(at: Date())
        return APIClientConfiguration(baseURL: configuration.baseURL, bearerToken: session.accessToken)
    }
}

@available(iOS 27.0, macOS 27.0, *)
private enum SpoonjoyIntentOAuthSupport {
    static func sendDecoded<Value: Decodable & Equatable>(
        _ builder: APIRequestBuilder,
        configuration: APIClientConfiguration
    ) async throws -> Value {
        let data = try await send(builder, configuration: configuration)
        if let envelope = try? APIEnvelope<Value>.decode(data) {
            return envelope.data
        }

        return try JSONDecoder().decode(Value.self, from: data)
    }

    private static func send(_ builder: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> Data {
        let request = try builder.urlRequest(configuration: configuration)
        guard let url = url(from: request.url, queryItems: request.queryItems) else {
            throw spoonjoyIntentInvalidRequestURL()
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let response: (data: Data, urlResponse: URLResponse)
        do {
            response = try await URLSession.shared.data(for: urlRequest)
        } catch let error as URLError where spoonjoyIntentIsOffline(error.code) {
            throw APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: 1)
            )
        } catch {
            throw error
        }

        guard let httpResponse = response.urlResponse as? HTTPURLResponse else {
            throw APITransportError(
                kind: .nonHTTPResponse,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APITransportError(
                kind: .apiError,
                requestID: httpResponse.value(forHTTPHeaderField: "X-Request-ID"),
                statusCode: httpResponse.statusCode,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }

        return response.data
    }

    private static func url(from requestURL: APIRequestURL, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: requestURL.baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = requestURL.path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

}

@available(iOS 27.0, macOS 27.0, *)
private enum SpoonjoyIntentSettingsActionStatus {
    case completed
    case queued

    func dialogMessage(completed: String, queued: String) -> IntentDialog {
        switch self {
        case .completed:
            IntentDialog(stringLiteral: completed)
        case .queued:
            IntentDialog(stringLiteral: queued)
        }
    }
}

@available(iOS 27.0, macOS 27.0, *)
private struct SpoonjoyIntentSettingsActionExecution {
    let outcome: SettingsActionOutcome?
    let status: SpoonjoyIntentSettingsActionStatus
}

private func spoonjoyIntentInvalidRequestURL() -> APITransportError {
    APITransportError(
        kind: .invalidRequestURL,
        requestID: nil,
        statusCode: nil,
        apiError: nil,
        retryDecision: .doNotRetry
    )
}

private func spoonjoyIntentIsOffline(_ code: URLError.Code) -> Bool {
    switch code {
    case .notConnectedToInternet,
         .networkConnectionLost,
         .cannotFindHost,
         .cannotConnectToHost,
         .timedOut,
         .internationalRoamingOff,
         .callIsActive,
         .dataNotAllowed:
        true
    default:
        false
    }
}

@available(iOS 27.0, macOS 27.0, *)
private struct SpoonjoyIntentStateWriter {
    private let store: NativeAppStateStore
    private let syncStore: any NativeSyncStore
    private let cacheStore: NativeDurableCacheStore
    private let authVault: (any TokenVault)?
    private let connectivityProbe: (@Sendable () async -> SettingsSurfaceConnectivity)?

    init(
        fileURL: URL = NativeAppStateLocation.defaultFileURL(),
        syncStore: (any NativeSyncStore)? = nil,
        cacheStore: NativeDurableCacheStore? = nil,
        authVault: (any TokenVault)? = KeychainTokenVault(),
        connectivityProbe: (@Sendable () async -> SettingsSurfaceConnectivity)? = nil
    ) throws {
        store = NativeAppStateStore(fileURL: fileURL)
        self.authVault = authVault
        self.connectivityProbe = connectivityProbe
        let appDirectory = fileURL.deletingLastPathComponent()
        self.cacheStore = cacheStore ?? NativeDurableCacheStore(
            fileURL: appDirectory.appendingPathComponent("native-durable-cache.json")
        )
        if let syncStore {
            self.syncStore = syncStore
        } else {
            self.syncStore = try FileBackedNativeSyncStore(
                fileURL: appDirectory.appendingPathComponent("native-sync-store.json"),
                mediaResolver: NativeStagedMediaDirectory(
                    directoryURL: appDirectory.appendingPathComponent("native-staged-media", isDirectory: true)
                )
            )
        }
    }

    func apply(_ action: NativeIntentAction, savedAt: String) async throws {
        switch action {
        case .addShoppingListItem(let mutation, _, _):
            let nativeMutation = try NativeQueuedMutation.intentMutation(from: mutation)
            try await appendNativeMutation(nativeMutation)
            try await applyShoppingMutation(nativeMutation, savedAt: savedAt, legacyQueuedMutation: mutation)
        case .nativeMutation(let mutation, _, _):
            let appliedMutation: NativeQueuedMutation
            if mutation.queueableKind == .recipeImportSubmit {
                appliedMutation = try await appendNativeMutationIfNeeded(mutation)
            } else {
                try await appendNativeMutation(mutation)
                appliedMutation = mutation
            }
            try await applyNativeMutation(appliedMutation, savedAt: savedAt)
        case .settingsAction(let plan, let route, let url):
            try await performSettingsAction(NativeIntentSettingsAction(plan: plan, route: route, url: url))
        case .shoppingMutation(let mutation, _, _):
            try await appendNativeMutation(mutation)
            try await applyShoppingMutation(mutation, savedAt: savedAt)
        case .captureDraftDiscard(let mutation, let draftID, let draftImportSource, _, _):
            try await discardMatchingCaptureImportMutations(draftImportSource: draftImportSource)
            try await appendNativeMutationIfNeeded(mutation)
            var snapshot = try await loadSnapshot(savedAt: savedAt)
            snapshot = snapshot.discardingCaptureDraft(id: draftID, savedAt: savedAt)
            try store.save(snapshot)
            if let scope = try? await currentIntentScope() {
                await purgeCaptureDraftEntitySurfaces(draftID: draftID, scope: scope)
            }
        case .captureDraft(let draft, _, _):
            try await appendNativeMutation(.captureDraftCreate(
                draftID: draft.id,
                source: .text(draft.rawText),
                clientMutationID: "intent-\(draft.id)",
                createdAt: savedAt
            ))
            var snapshot = try await loadSnapshot(savedAt: savedAt)
            snapshot = snapshot.updatingCaptureDraft(draft, savedAt: savedAt)
            try store.save(snapshot)
        case .openRoute:
            break
        }
    }

    func currentAccountID() async throws -> String {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        return scope.accountID
    }

    func settingsConnectivity() async throws -> SettingsSurfaceConnectivity {
        let syncSnapshot = try await syncStore.loadSnapshot()
        _ = try await trustedIntentScope(from: syncSnapshot)
        let connectivityProbe = self.connectivityProbe ?? SpoonjoyIntentConnectivityProbe.settingsSurfaceConnectivity
        return await connectivityProbe()
    }

    func notificationAPNsSurfaceData() async throws -> NotificationAPNsSurfaceData {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let fallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: scope.accountID,
            environment: scope.environment,
            createdAt: Date(),
            records: [],
            dismissedIndicators: []
        )
        let cachedSnapshot = try cacheStore.loadOrRecover(fallback: fallback).value
        let cachedData = SnapshotNotificationAPNsSurfaceRepository(
            cache: NativeDurableCache(records: cachedSnapshot.records),
            environment: scope.environment,
            fallbackValidatedAt: Date()
        ).restoreSynchronously()
        let connectivity = try await notificationAPNsConnectivity()
        switch connectivity {
        case .offline:
            return cachedData
        case .online:
            break
        }

        guard let authVault else {
            throw NativeIntentActionError.authRequired
        }
        let refresher = SpoonjoyIntentAPIRefresher(vault: authVault)
        do {
            let configuration = try await refresher.validConfiguration()
            return try await FallbackNotificationAPNsSurfaceRepository(
                primary: LiveNotificationAPNsSurfaceRepository(
                    transport: URLSessionSettingsSurfaceTransport(
                        transport: URLSessionAPITransport(authenticationRefresher: refresher)
                    ),
                    configuration: configuration
                ),
                fallback: SnapshotNotificationAPNsSurfaceRepository(
                    cache: NativeDurableCache(records: cachedSnapshot.records),
                    environment: scope.environment,
                    fallbackValidatedAt: Date()
                )
            ).restore()
        } catch let error as APITransportError where error.isOffline {
            return cachedData
        }
    }

    func notificationAPNsHasCachedPreferences() async throws -> Bool {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let fallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: scope.accountID,
            environment: scope.environment,
            createdAt: Date(),
            records: [],
            dismissedIndicators: []
        )
        let snapshot = try cacheStore.loadOrRecover(fallback: fallback).value
        return snapshot.record(for: .notificationPreferences) != nil
    }

    func notificationAPNsConnectivity() async throws -> NotificationAPNsSurfaceConnectivity {
        let connectivity = try await settingsConnectivity()
        switch connectivity {
        case .online:
            return NotificationAPNsSurfaceConnectivity.online
        case .offline:
            return NotificationAPNsSurfaceConnectivity.offline
        }
    }

    @discardableResult
    func performSettingsAction(_ action: NativeIntentSettingsAction) async throws -> SettingsActionOutcome? {
        try await executeSettingsAction(action).outcome
    }

    func performSettingsActionStatus(_ action: NativeIntentAction, savedAt: String) async throws -> SpoonjoyIntentSettingsActionStatus {
        switch action {
        case .settingsAction(let plan, let route, let url):
            return try await executeSettingsAction(NativeIntentSettingsAction(plan: plan, route: route, url: url)).status
        default:
            try await apply(action, savedAt: savedAt)
            return .completed
        }
    }

    func performNotificationAPNsActionStatus(_ action: NativeIntentNotificationAction, savedAt: String) async throws -> SpoonjoyIntentSettingsActionStatus {
        let execution = try await executeNotificationAPNsAction(action)
        if let mutation = action.plan.offlineFallbackMutation,
           execution.status == .completed {
            try await applyNativeMutation(mutation, savedAt: savedAt)
        }
        return execution.status
    }

    private func executeNotificationAPNsAction(_ action: NativeIntentNotificationAction) async throws -> SpoonjoyIntentSettingsActionExecution {
        _ = NotificationAPNsActionPlanner.self
        if let blocker = action.deliveryBlocker {
            try await recordNotificationAPNsBlocker(blocker)
            return SpoonjoyIntentSettingsActionExecution(outcome: nil, status: .completed)
        }
        guard action.onlineOnlyReason == nil else {
            return SpoonjoyIntentSettingsActionExecution(outcome: nil, status: .completed)
        }

        let currentQueue = try await currentNativeMutationQueue()
        if let preflight = action.plan.queuePreflightDecision(queuedMutations: currentQueue.mutations) {
            switch preflight {
            case .queueMutation(let mutation, drainImmediately: _):
                try await appendNativeMutation(mutation)
                try await applyNativeMutation(mutation, savedAt: mutation.createdAt)
            }
            return SpoonjoyIntentSettingsActionExecution(outcome: nil, status: .queued)
        }

        if let request = action.plan.remoteRequestBuilder {
            do {
                _ = try await executeSettingsRequest(request, responseHandling: .refreshOnly)
            } catch let error as APITransportError where error.isOffline {
                if let mutation = action.plan.offlineFallbackMutation {
                    try await appendNativeMutation(mutation)
                    try await applyNativeMutation(mutation, savedAt: mutation.createdAt)
                    return SpoonjoyIntentSettingsActionExecution(outcome: nil, status: .queued)
                }
                throw error
            }
        }
        return SpoonjoyIntentSettingsActionExecution(outcome: nil, status: .completed)
    }

    private func executeSettingsAction(_ action: NativeIntentSettingsAction) async throws -> SpoonjoyIntentSettingsActionExecution {
        guard action.onlineOnlyReason == nil else {
            return SpoonjoyIntentSettingsActionExecution(outcome: nil, status: .completed)
        }

        let currentQueue = try await currentNativeMutationQueue()
        if let preflight = action.plan.queuePreflightDecision(queuedMutations: currentQueue.mutations) {
            switch preflight {
            case .queueMutation(let mutation, drainImmediately: _):
                try await appendNativeMutation(mutation)
                try await applyNativeMutation(mutation, savedAt: mutation.createdAt)
            }
            return SpoonjoyIntentSettingsActionExecution(outcome: nil, status: .queued)
        }

        var outcome: SettingsActionOutcome?
        if let request = action.plan.remoteRequestBuilder {
            do {
                outcome = try await executeSettingsRequest(
                    request,
                    responseHandling: action.plan.responseHandling
                )
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = action.plan.offlineFallbackMutation {
                    try await appendNativeMutation(offlineFallbackMutation)
                    try await applyNativeMutation(offlineFallbackMutation, savedAt: offlineFallbackMutation.createdAt)
                    return SpoonjoyIntentSettingsActionExecution(outcome: nil, status: .queued)
                }
                throw error
            }
        }
        if let sessionOperation = action.plan.sessionOperation {
            try await performSettingsSessionOperation(sessionOperation)
        }
        return SpoonjoyIntentSettingsActionExecution(outcome: outcome, status: .completed)
    }

    private func applyNativeMutation(_ mutation: NativeQueuedMutation, savedAt: String) async throws {
        switch mutation.queueableKind {
        case .shoppingAddItem, .shoppingCheckItem, .shoppingDeleteItem, .shoppingAddFromRecipe, .shoppingClearCompleted, .shoppingClearAll:
            try await applyShoppingMutation(mutation, savedAt: savedAt)
        case .recipeImportSubmit:
            var snapshot = try await loadSnapshot(savedAt: savedAt)
            snapshot = snapshot.recordingCaptureImportRetry(mutation, savedAt: savedAt)
            try store.save(snapshot)
        case .profileDisplayUpdate, .profilePhotoUpload, .profilePhotoRemove:
            try await applySettingsMutation(mutation, savedAt: savedAt)
        case .notificationPreferenceUpdate:
            try await applyNotificationPreferenceMutation(mutation, savedAt: savedAt)
        default:
            break
        }
    }

    private func applySettingsMutation(_ mutation: NativeQueuedMutation, savedAt: String) async throws {
        switch mutation.queueableKind {
        case .profileDisplayUpdate:
            guard let values = mutation.profileDisplayUpdateValues else {
                return
            }
            try await updateCachedSettingsAccount(savedAt: savedAt) { account in
                SettingsAccountProfile(
                    id: account.id,
                    email: values.email,
                    username: values.username,
                    photoURL: account.photoURL,
                    hasPassword: account.hasPassword,
                    linkedProviders: account.linkedProviders,
                    passkeys: account.passkeys
                )
            }
        case .profilePhotoRemove:
            try await updateCachedSettingsAccount(savedAt: savedAt) { account in
                SettingsAccountProfile(
                    id: account.id,
                    email: account.email,
                    username: account.username,
                    photoURL: nil,
                    hasPassword: account.hasPassword,
                    linkedProviders: account.linkedProviders,
                    passkeys: account.passkeys
                )
            }
        case .profilePhotoUpload:
            return
        default:
            return
        }
    }

    private func applyNotificationPreferenceMutation(_ mutation: NativeQueuedMutation, savedAt: String) async throws {
        guard let preferences = mutation.notificationPreferenceUpdateValues else {
            return
        }
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let savedDate = Self.date(from: savedAt) ?? Date()
        let fallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: scope.accountID,
            environment: scope.environment,
            createdAt: savedDate,
            records: [],
            dismissedIndicators: []
        )
        let cacheRecord = try cacheStore.loadOrRecover(fallback: fallback)
        let snapshot = cacheRecord.value
        let nextRecord = try NativeCacheRecord(
            id: NativeCacheDomain.notificationPreferences.stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: scope.accountID,
                environment: scope.environment,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: .notificationPreferences,
                fetchedAt: snapshot.record(for: .notificationPreferences)?.metadata.fetchedAt ?? savedDate,
                lastValidatedAt: savedDate,
                sourceEndpoint: "/api/v1/me/notification-preferences",
                serverRevision: .localRevision(savedAt)
            ),
            payload: .notificationPreferenceState(preferences)
        )
        let records = snapshot.records.filter { $0.metadata.domain != .notificationPreferences } + [nextRecord]
        try cacheStore.save(try snapshot.copy(records: records))
    }

    private func recordNotificationAPNsBlocker(_ blocker: AppleDeveloperProgramBlocker) async throws {
        _ = blocker.outputPath
    }

    private static func date(from timestamp: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp)
    }

    private func updateCachedSettingsAccount(
        savedAt: String,
        transform: (SettingsAccountProfile) -> SettingsAccountProfile
    ) async throws {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let fallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: scope.accountID,
            environment: scope.environment,
            createdAt: Date(),
            records: [],
            dismissedIndicators: []
        )
        let cacheRecord = try cacheStore.loadOrRecover(fallback: fallback)
        let snapshot = cacheRecord.value
        let records = try snapshot.records.map { record in
            guard record.metadata.domain == .settings,
                  case .settings(let account) = record.payload else {
                return record
            }
            let metadata = NativeCacheRecordMetadata(
                accountID: record.metadata.accountID,
                environment: record.metadata.environment,
                schemaVersion: record.metadata.schemaVersion,
                domain: record.metadata.domain,
                fetchedAt: record.metadata.fetchedAt,
                lastValidatedAt: record.metadata.lastValidatedAt,
                sourceEndpoint: record.metadata.sourceEndpoint,
                serverRevision: .localRevision(savedAt)
            )
            return try NativeCacheRecord(
                id: record.id,
                metadata: metadata,
                payload: .settings(account: transform(account))
            )
        }
        try cacheStore.save(try snapshot.copy(records: records))
    }

    private func applyShoppingMutation(
        _ mutation: NativeQueuedMutation,
        savedAt: String,
        legacyQueuedMutation: QueuedMutation? = nil
    ) async throws {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        var snapshot = try await loadSnapshot(savedAt: savedAt)
        let fallbackChef = ChefSummary(id: scope.accountID, username: "Spoonjoy")
        guard let updatedShoppingList = mutation.applyingOptimisticShoppingMutation(
            to: snapshot.shoppingList,
            recipes: [],
            fallbackChef: fallbackChef,
            now: savedAt
        ) else {
            return
        }
        snapshot = try snapshot.updatingShoppingList(
            updatedShoppingList,
            queuedMutation: legacyQueuedMutation,
            savedAt: savedAt
        )
        try store.save(snapshot)
    }

    private func executeSettingsRequest(
        _ request: APIRequestBuilder,
        responseHandling: SettingsActionResponseHandling
    ) async throws -> SettingsActionOutcome? {
        guard let authVault else {
            throw NativeIntentActionError.authRequired
        }
        let refresher = SpoonjoyIntentAPIRefresher(vault: authVault)
        let configuration = try await refresher.validConfiguration()
        let transport = URLSessionAPITransport(authenticationRefresher: refresher)

        switch responseHandling {
        case .refreshOnly:
            _ = try await transport.send(
                request,
                configuration: configuration,
                decode: JSONValue.self
            )
            return nil
        case .captureCreatedAPIToken:
            let envelope = try await transport.send(
                request,
                configuration: configuration,
                decode: SettingsCreatedAPIToken.self
            )
            return .createdAPIToken(envelope.data)
        }
    }

    private func performSettingsSessionOperation(_ operation: SettingsSessionOperation) async throws {
        guard let authVault else {
            throw NativeIntentActionError.authRequired
        }
        try await purgePrivateEntityIndexesForCurrentScope()
        switch operation {
        case .logout:
            try await authVault.clearSession()
            try await authVault.clearClientID()
        case .revokeAndLogout:
            if let session = try await authVault.loadSession() {
                try await executeOAuthRequest(OAuthRequests.revoke(refreshToken: session.refreshToken, clientID: session.clientID))
            }
            try await authVault.clearSession()
            try await authVault.clearClientID()
        }
    }

    private func purgePrivateEntityIndexesForCurrentScope() async throws {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let appSnapshot = loadScopedAppSnapshot(scope: scope)
        let cacheSnapshot = loadScopedCacheSnapshot(scope: scope)
        let accountID = scope.accountID
        let environment = scope.environment

        let shoppingItemIDs = Self.uniquePreservingOrder(
            syncSnapshot.cachedRecords.compactMap { record in
                record.kind == .shoppingItem ? record.resourceID : nil
            } + (appSnapshot?.shoppingList?.activeItems.map(\.id) ?? [])
        )
        let shoppingPlan = ShoppingEntityIndexPurgePlan.accountScopePurge(
            accountID: accountID,
            environment: environment,
            shoppingItemIDs: shoppingItemIDs
        )
        try await purgePrivateEntitySurfaces(
            identifiers: ShoppingEntityCatalog.purgeEntityIdentifiers(accountID: accountID, environment: environment, plan: shoppingPlan),
            domainIdentifiers: ShoppingEntityCatalog.purgeDomainIdentifiers(accountID: accountID, environment: environment, plan: shoppingPlan),
            accountID: accountID,
            environment: environment
        )

        let spoonIDs = Self.uniquePreservingOrder(syncSnapshot.cachedRecords.compactMap { record in
            record.kind == .spoon ? record.resourceID : nil
        })
        let spoonPlan = SpoonEntityIndexPurgePlan.accountScopePurge(
            accountID: accountID,
            environment: environment,
            spoonIDs: spoonIDs
        )
        try await purgePrivateEntitySurfaces(
            identifiers: SpoonEntityCatalog.purgeEntityIdentifiers(accountID: accountID, environment: environment, plan: spoonPlan),
            domainIdentifiers: SpoonEntityCatalog.purgeDomainIdentifiers(accountID: accountID, environment: environment, plan: spoonPlan),
            accountID: accountID,
            environment: environment
        )

        let captureDraftPlan = CaptureDraftEntityIndexPurgePlan.accountScopePurge(
            appSnapshot: appSnapshot,
            cacheSnapshot: cacheSnapshot,
            accountID: accountID,
            environment: environment
        )
        try await purgePrivateEntitySurfaces(
            identifiers: CaptureDraftEntityCatalog.purgeEntityIdentifiers(accountID: accountID, environment: environment, plan: captureDraftPlan),
            domainIdentifiers: CaptureDraftEntityCatalog.purgeDomainIdentifiers(accountID: accountID, environment: environment, plan: captureDraftPlan),
            accountID: accountID,
            environment: environment
        )

        let chefProfileIDs = Self.uniquePreservingOrder(
            syncSnapshot.cachedRecords.compactMap { record in
                record.kind == .profile ? record.resourceID : nil
            } + (cacheSnapshot?.records.compactMap { record in
                guard case .profile(let id) = record.metadata.domain else {
                    return nil
                }
                return id
            } ?? [])
        )
        let chefProfilePlan = ChefProfileEntityIndexPurgePlan.accountScopePurge(
            accountID: accountID,
            environment: environment,
            profileIDs: chefProfileIDs
        )
        try await purgePrivateEntitySurfaces(
            identifiers: ChefProfileEntityCatalog.purgeEntityIdentifiers(accountID: accountID, environment: environment, plan: chefProfilePlan),
            domainIdentifiers: ChefProfileEntityCatalog.purgeDomainIdentifiers(accountID: accountID, environment: environment, plan: chefProfilePlan),
            accountID: accountID,
            environment: environment
        )

        let recipeIDs = Self.uniquePreservingOrder(
            syncSnapshot.cachedRecords.compactMap { record in
                record.kind == .recipe ? record.resourceID : nil
            } + Self.recipeIDs(from: cacheSnapshot)
        )
        let cookbookIDs = Self.uniquePreservingOrder(
            syncSnapshot.cachedRecords.compactMap { record in
                record.kind == .cookbook ? record.resourceID : nil
            } + Self.cookbookIDs(from: cacheSnapshot)
        )
        let recipeCookbookPlan = RecipeCookbookEntityIndexPurgePlan.accountScopePurge(
            accountID: accountID,
            environment: environment,
            recipeIDs: recipeIDs,
            cookbookIDs: cookbookIDs
        )
        try await purgePrivateEntitySurfaces(
            identifiers: RecipeCookbookEntityCatalog.purgeEntityIdentifiers(accountID: accountID, environment: environment, plan: recipeCookbookPlan),
            domainIdentifiers: RecipeCookbookEntityCatalog.purgeDomainIdentifiers(accountID: accountID, environment: environment, plan: recipeCookbookPlan),
            accountID: accountID,
            environment: environment
        )
    }

    private func purgePrivateEntitySurfaces(
        identifiers: [String],
        domainIdentifiers: [String],
        accountID: String,
        environment: NativeCacheEnvironment
    ) async throws {
        guard !identifiers.isEmpty || !domainIdentifiers.isEmpty else {
            return
        }
#if canImport(CoreSpotlight)
        try await SpoonjoySpotlightIndexer().delete(
            identifiers: identifiers,
            domainIdentifiers: domainIdentifiers,
            accountID: accountID,
            environment: environment
        )
#else
        _ = identifiers
        _ = domainIdentifiers
        _ = accountID
        _ = environment
#endif
    }

    private func loadScopedAppSnapshot(scope: (accountID: String, environment: NativeCacheEnvironment)) -> NativeAppSnapshot? {
        let savedAt = SpoonjoyIntentClock.timestamp()
        let fallback = NativeAppSnapshot.bootstrap(
            shoppingList: nil,
            accountID: scope.accountID,
            environment: scope.environment,
            savedAt: savedAt
        )
        guard let record = try? store.loadOrCreate(fallback: fallback),
              record.value.isScoped(accountID: scope.accountID, environment: scope.environment) else {
            return nil
        }
        return record.value
    }

    private func loadScopedCacheSnapshot(scope: (accountID: String, environment: NativeCacheEnvironment)) -> NativeDurableCacheSnapshot? {
        let fallback = try? NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: scope.accountID,
            environment: scope.environment,
            createdAt: Date(),
            records: [],
            dismissedIndicators: []
        )
        guard let fallback,
              let snapshot = try? cacheStore.loadOrRecover(fallback: fallback).value,
              snapshot.accountID == scope.accountID,
              snapshot.environment == scope.environment else {
            return nil
        }
        return snapshot
    }

    private static func recipeIDs(from cacheSnapshot: NativeDurableCacheSnapshot?) -> [String] {
        cacheSnapshot?.records.flatMap { record -> [String] in
            switch record.payload {
            case .recipeCatalog(let ids):
                ids
            case .recipeDetail(let id, _):
                [id]
            default:
                []
            }
        } ?? []
    }

    private static func cookbookIDs(from cacheSnapshot: NativeDurableCacheSnapshot?) -> [String] {
        cacheSnapshot?.records.flatMap { record -> [String] in
            switch record.payload {
            case .cookbookList(let ids):
                ids
            case .cookbookDetail(let id, _):
                [id]
            default:
                []
            }
        } ?? []
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func executeOAuthRequest(_ requestBuilder: APIRequestBuilder) async throws {
        let apiRequest = try requestBuilder.urlRequest(configuration: APIClientConfiguration.spoonjoyProduction)
        guard var components = URLComponents(url: apiRequest.url.baseURL, resolvingAgainstBaseURL: false) else {
            throw spoonjoyIntentInvalidRequestURL()
        }
        components.path = apiRequest.url.path
        components.queryItems = apiRequest.queryItems.isEmpty ? nil : apiRequest.queryItems
        guard let url = components.url else {
            throw spoonjoyIntentInvalidRequestURL()
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = apiRequest.method.rawValue
        urlRequest.httpBody = apiRequest.body
        for (name, value) in apiRequest.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APITransportError(
                kind: .nonHTTPResponse,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }
        guard 200...299 ~= httpResponse.statusCode else {
            throw APITransportError(
                kind: .apiError,
                requestID: nil,
                statusCode: httpResponse.statusCode,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }
    }

    private func currentNativeMutationQueue() async throws -> NativeMutationQueue {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        if syncSnapshot.accountID == scope.accountID,
           syncSnapshot.environment == scope.environment {
            return try await syncStore.loadQueue()
        }
        return NativeMutationQueue()
    }

    private func appendNativeMutation(_ mutation: NativeQueuedMutation) async throws {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let queue: NativeMutationQueue
        if syncSnapshot.accountID == scope.accountID,
           syncSnapshot.environment == scope.environment {
            queue = try await syncStore.loadQueue()
        } else {
            queue = NativeMutationQueue()
        }
        try await syncStore.saveQueue(
            try queue.appending(mutation),
            accountID: scope.accountID,
            environment: scope.environment
        )
    }

    @discardableResult
    private func appendNativeMutationIfNeeded(_ mutation: NativeQueuedMutation) async throws -> NativeQueuedMutation {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let queue: NativeMutationQueue
        if syncSnapshot.accountID == scope.accountID,
           syncSnapshot.environment == scope.environment {
            queue = try await syncStore.loadQueue()
        } else {
            queue = NativeMutationQueue()
        }
        if queue.mutations.contains(where: { $0.clientMutationID == mutation.clientMutationID }),
           let existingMutation = queue.mutations.first(where: { $0.clientMutationID == mutation.clientMutationID }) {
            return existingMutation
        }
        if let source = mutation.recipeImportSource,
           let existingMutation = queue.mutations.first(where: {
               $0.queueableKind == .recipeImportSubmit &&
                   $0.recipeImportSource == source
           }) {
            return existingMutation
        }
        try await syncStore.saveQueue(
            try queue.appending(mutation),
            accountID: scope.accountID,
            environment: scope.environment
        )
        return mutation
    }

    private func discardMatchingCaptureImportMutations(draftImportSource: NativeMutationSource?) async throws {
        guard let draftImportSource else {
            return
        }
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let queue: NativeMutationQueue
        if syncSnapshot.accountID == scope.accountID,
           syncSnapshot.environment == scope.environment {
            queue = try await syncStore.loadQueue()
        } else {
            queue = NativeMutationQueue()
        }
        let clientMutationIDs = Set(queue.mutations
            .filter {
                $0.queueableKind == .recipeImportSubmit &&
                    $0.recipeImportSource == draftImportSource
            }
            .map(\.clientMutationID))
        guard !clientMutationIDs.isEmpty else {
            return
        }
        try await syncStore.saveQueue(
            try queue.removing(clientMutationIDs: clientMutationIDs),
            accountID: scope.accountID,
            environment: scope.environment
        )
    }

    private func purgeCaptureDraftEntitySurfaces(
        draftID: String,
        scope: (accountID: String, environment: NativeCacheEnvironment)
    ) async {
        let discardPlan = CaptureDraftEntityIndexPurgePlan.draftDiscardPurge(
            draftID: draftID,
            accountID: scope.accountID,
            environment: scope.environment
        )
        let identifiers = CaptureDraftEntityCatalog.purgeEntityIdentifiers(
            accountID: scope.accountID,
            environment: scope.environment,
            plan: discardPlan
        )
        let domainIdentifiers = CaptureDraftEntityCatalog.purgeDomainIdentifiers(
            accountID: scope.accountID,
            environment: scope.environment,
            plan: discardPlan
        )
#if canImport(CoreSpotlight)
        try? await SpoonjoySpotlightIndexer().delete(
            identifiers: identifiers,
            domainIdentifiers: domainIdentifiers,
            accountID: scope.accountID,
            environment: scope.environment
        )
#endif
    }

    private func currentIntentScope() async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        let syncSnapshot = try await syncStore.loadSnapshot()
        return try await trustedIntentScope(from: syncSnapshot)
    }

    private func loadSnapshot(savedAt: String) async throws -> NativeAppSnapshot {
        let syncSnapshot = try await syncStore.loadSnapshot()
        let scope = try await trustedIntentScope(from: syncSnapshot)
        let fallback = NativeAppSnapshot
            .bootstrap(
                shoppingList: nil,
                accountID: scope.accountID,
                environment: scope.environment,
                savedAt: savedAt
            )
            .completingFirstRun(savedAt: savedAt)
        let snapshot = try store.loadOrCreate(fallback: fallback).value
        return snapshot.isScoped(accountID: scope.accountID, environment: scope.environment) ? snapshot : fallback
    }

    private func trustedIntentScope(from syncSnapshot: NativeSyncSnapshot) async throws -> (accountID: String, environment: NativeCacheEnvironment) {
        guard let session = try await authVault?.loadSession(),
              let accountID = session.accountID else {
            throw NativeIntentActionError.authRequired
        }
        let environment = syncSnapshot.accountID == accountID
            ? (syncSnapshot.environment ?? .production)
            : .production
        return (accountID, environment)
    }

}
#endif
