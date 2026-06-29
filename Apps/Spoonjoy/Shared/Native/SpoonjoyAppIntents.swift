import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents

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
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().saveRecipeToCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor, createdAt: createdAt)
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)
        await SpoonjoyInteractionDonor().donateBestEffort(self)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued cookbook save in Spoonjoy")
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
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().removeRecipeFromCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor, createdAt: createdAt)
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
struct CaptureRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Recipe"
    static let description = IntentDescription("Save a recipe URL or note into Spoonjoy capture drafts.")

    @Parameter(title: "Source")
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
            String(describing: SetShoppingListItemCheckedIntent()),
            String(describing: RemoveShoppingListItemIntent()),
            String(describing: AddRecipeIngredientsToShoppingListIntent()),
            String(describing: ClearCompletedShoppingItemsIntent()),
            String(describing: ClearShoppingListIntent()),
            String(describing: ForkRecipeIntent()),
            String(describing: SaveRecipeToCookbookIntent()),
            String(describing: RemoveRecipeFromCookbookIntent()),
            String(describing: DeleteRecipeIntent())
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

private enum SpoonjoyIntentClock {
    static func timestamp(date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

private struct SpoonjoyIntentStateWriter {
    private let store: NativeAppStateStore
    private let syncStore: any NativeSyncStore
    private let authVault: (any TokenVault)?

    init(
        fileURL: URL = NativeAppStateLocation.defaultFileURL(),
        syncStore: (any NativeSyncStore)? = nil,
        authVault: (any TokenVault)? = KeychainTokenVault()
    ) throws {
        store = NativeAppStateStore(fileURL: fileURL)
        self.authVault = authVault
        if let syncStore {
            self.syncStore = syncStore
        } else {
            let appDirectory = fileURL.deletingLastPathComponent()
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
            try await appendNativeMutation(mutation)
            try await applyNativeMutation(mutation, savedAt: savedAt)
        case .shoppingMutation(let mutation, _, _):
            try await appendNativeMutation(mutation)
            try await applyShoppingMutation(mutation, savedAt: savedAt)
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

    private func applyNativeMutation(_ mutation: NativeQueuedMutation, savedAt: String) async throws {
        switch mutation.queueableKind {
        case .shoppingAddItem, .shoppingCheckItem, .shoppingDeleteItem, .shoppingAddFromRecipe, .shoppingClearCompleted, .shoppingClearAll:
            try await applyShoppingMutation(mutation, savedAt: savedAt)
        default:
            break
        }
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
