import Foundation
import SpoonjoyCore

#if canImport(AppIntents)
import AppIntents

@available(iOS 27.0, macOS 27.0, *)
struct OpenRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Recipe"
    static let description = IntentDescription("Open a Spoonjoy recipe by identifier.")

    @Parameter(title: "Recipe ID")
    var recipeID: String

    init() {
        recipeID = ""
    }

    init(recipeID: String) {
        self.recipeID = recipeID
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().openRecipe(recipeID: recipeID)
        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Opening recipe in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct StartCookModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Cooking"
    static let description = IntentDescription("Open a Spoonjoy recipe directly in cook mode.")

    @Parameter(title: "Recipe ID")
    var recipeID: String

    init() {
        recipeID = ""
    }

    init(recipeID: String) {
        self.recipeID = recipeID
    }

    func perform() async throws -> some IntentResult {
        let action = try NativeIntentActionResolver().startCookMode(recipeID: recipeID)
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

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Queued \(name) in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SetShoppingListItemCheckedIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Shopping Item Checked"
    static let description = IntentDescription("Check or uncheck a Spoonjoy shopping-list item.")

    @Parameter(title: "Item ID")
    var itemID: String

    @Parameter(title: "Checked")
    var checked: Bool

    init() {
        itemID = ""
        checked = true
    }

    init(itemID: String, checked: Bool) {
        self.itemID = itemID
        self.checked = checked
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().setShoppingListItemChecked(
            itemID: itemID,
            checked: checked,
            createdAt: createdAt
        )
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Updated shopping item in Spoonjoy")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct AddRecipeIngredientsToShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Recipe Ingredients"
    static let description = IntentDescription("Add a Spoonjoy recipe's ingredients to the shopping list.")

    @Parameter(title: "Recipe ID")
    var recipeID: String

    @Parameter(title: "Scale Factor")
    var scaleFactor: Double

    init() {
        recipeID = ""
        scaleFactor = 1
    }

    init(recipeID: String, scaleFactor: Double = 1) {
        self.recipeID = recipeID
        self.scaleFactor = scaleFactor
    }

    func perform() async throws -> some IntentResult {
        let createdAt = SpoonjoyIntentClock.timestamp()
        let action = try NativeIntentActionResolver().addRecipeIngredientsToShoppingList(
            recipeID: recipeID,
            scaleFactor: scaleFactor,
            createdAt: createdAt
        )
        try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)

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

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Saved a Spoonjoy capture draft")
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
