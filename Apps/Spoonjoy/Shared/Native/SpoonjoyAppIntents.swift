import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents

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
        let recipeID = try recipe.resolvedRecipeID()
        let action = try NativeIntentActionResolver().openRecipe(recipeID: recipeID)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening recipe in Spoonjoy")
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
        let recipeID = try recipe.resolvedRecipeID()
        let action = try NativeIntentActionResolver().startCookMode(recipeID: recipeID)
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Starting cook mode in Spoonjoy")
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
            intent: StartCookModeIntent(),
            phrases: [
                "Start cooking in \(.applicationName)",
                "Cook with \(.applicationName)"
            ],
            shortTitle: "Start Cooking",
            systemImageName: "fork.knife"
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
            intent: SetShoppingListItemCheckedIntent(),
            phrases: [
                "Update a shopping item in \(.applicationName)",
                "Check off an item in \(.applicationName)"
            ],
            shortTitle: "Check Shopping Item",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: AddRecipeIngredientsToShoppingListIntent(),
            phrases: [
                "Add recipe ingredients in \(.applicationName)",
                "Shop for a recipe in \(.applicationName)"
            ],
            shortTitle: "Add Recipe Ingredients",
            systemImageName: "list.bullet.clipboard"
        )
        AppShortcut(
            intent: ClearCompletedShoppingItemsIntent(),
            phrases: [
                "Clear completed shopping items in \(.applicationName)",
                "Clean up my \(.applicationName) shopping list"
            ],
            shortTitle: "Clear Completed",
            systemImageName: "checklist.checked"
        )
        AppShortcut(
            intent: ClearShoppingListIntent(),
            phrases: [
                "Clear my shopping list in \(.applicationName)",
                "Empty my \(.applicationName) shopping list"
            ],
            shortTitle: "Clear Shopping List",
            systemImageName: "trash"
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
