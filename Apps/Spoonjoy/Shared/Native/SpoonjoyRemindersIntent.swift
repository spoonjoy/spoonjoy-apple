import Foundation
import SpoonjoyCore

#if canImport(AppIntents) && canImport(EventKit)
import AppIntents

@available(iOS 27.0, macOS 27.0, *)
enum SpoonjoyRemindersIntentError: Error, CustomLocalizedStringResourceConvertible {
    case accessNotGranted
    case noListChosen
    case unavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .accessNotGranted:
            "Spoonjoy does not have full access to Reminders yet. Open Spoonjoy, choose Send to Reminders on any recipe, and allow access once."
        case .noListChosen:
            "Spoonjoy does not know which Reminders list to use yet. Open Spoonjoy, choose Send to Reminders on any recipe, and pick a list once."
        case .unavailable:
            "Spoonjoy could not send the ingredients to Reminders."
        }
    }
}

/// Uses the same planner and EventKit adapter as the Send to Reminders buttons, so a repeat run changes nothing.
@available(iOS 27.0, macOS 27.0, *)
struct AddRecipeIngredientsToRemindersIntent: AppIntent {
    static let title: LocalizedStringResource = "Add recipe ingredients to Reminders"
    static let description = IntentDescription("Add a Spoonjoy recipe's ingredients to your Reminders list without duplicating items already on it.")

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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let recipeID = try recipe.resolvedRecipeID()
        let syncStore = try SpoonjoyIntentSyncStoreFactory.syncStore()
        let snapshot = try await syncStore.loadSnapshot()
        let scope = try await SpoonjoyIntentScopeProvider(authVault: KeychainTokenVault()).trustedIntentScope(from: snapshot)
        let catalog = RecipeCookbookEntityCatalog(
            syncSnapshot: snapshot,
            currentAccountID: scope.accountID,
            environment: scope.environment
        )
        let content = try catalog.reminderIngredients(forRecipeID: recipeID)

        let store = SpoonjoyRemindersStore()
        guard store.hasFullAccess else {
            throw SpoonjoyRemindersIntentError.accessNotGranted
        }
        guard let list = store.resolvedList() else {
            throw SpoonjoyRemindersIntentError.noListChosen
        }
        let summary: ReminderSyncSummary
        do {
            summary = try await store.send(
                ReminderIncomingIngredient.fromRecipe(content.ingredients, scaleFactor: scaleFactor),
                source: ReminderSource(id: recipeID, label: content.title),
                listID: list.id
            )
        } catch {
            throw SpoonjoyRemindersIntentError.unavailable
        }
        await SpoonjoyInteractionDonor().donateBestEffort(self)
        return .result(dialog: IntentDialog(stringLiteral: summary.message(listName: list.title)))
    }
}
#endif
