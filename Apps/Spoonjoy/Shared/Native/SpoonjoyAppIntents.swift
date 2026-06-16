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
        try SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)

        return .result(opensIntent: OpenURLIntent(action.url), dialog: "Added \(name) to Spoonjoy")
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
        try SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)

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

    init(fileURL: URL = NativeAppStateLocation.defaultFileURL()) {
        store = NativeAppStateStore(fileURL: fileURL)
    }

    func apply(_ action: NativeIntentAction, savedAt: String) throws {
        switch action {
        case .addShoppingListItem(let mutation, _, _):
            try applyShoppingMutation(mutation, savedAt: savedAt)
        case .captureDraft(let draft, _, _):
            var snapshot = try loadSnapshot(savedAt: savedAt)
            snapshot = snapshot.updatingCaptureDraft(draft, savedAt: savedAt)
            try store.save(snapshot)
        case .openRoute:
            break
        }
    }

    private func applyShoppingMutation(_ mutation: QueuedMutation, savedAt: String) throws {
        guard case .shoppingAdd(let name, let quantity, let unit, let categoryKey, let iconKey) = mutation.kind else {
            return
        }

        var snapshot = try loadSnapshot(savedAt: savedAt)
        let shoppingList = try snapshot.shoppingList ?? ShoppingListState.decodeFromBundle()
        let result = try shoppingList.addingOrRestoringItem(
            name: name,
            quantity: quantity,
            unit: unit,
            categoryKey: categoryKey,
            iconKey: iconKey,
            clientMutationID: mutation.clientMutationID
        )
        snapshot = try snapshot.updatingShoppingList(
            result.shoppingList,
            queuedMutation: mutation,
            savedAt: savedAt
        )
        try store.save(snapshot)
    }

    private func loadSnapshot(savedAt: String) throws -> NativeAppSnapshot {
        let fallback = NativeAppSnapshot
            .bootstrap(shoppingList: try? ShoppingListState.decodeFromBundle(), savedAt: savedAt)
            .completingFirstRun(savedAt: savedAt)
        return try store.loadOrCreate(fallback: fallback).value
    }

}
#endif
