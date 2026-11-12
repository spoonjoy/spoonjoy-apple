import AppIntents
import AppIntentsTesting
import Foundation

enum JourneyIntentsError: Error, CustomStringConvertible {
    case recipeNotFound(title: String, recipeID: String, lastFound: [String])

    var description: String {
        switch self {
        case .recipeNotFound(let title, let recipeID, let lastFound):
            "Spoonjoy's recipe query never matched \"\(title)\" (recipe \(recipeID)), so Siri could not find it by name. "
                + "Its last answer had \(lastFound.count) recipe(s): \(lastFound.joined(separator: ", "))"
        }
    }
}

/// Runs Spoonjoy's App Intents the way Siri and Shortcuts do: out of process, by bundle identifier, in the app that
/// XCTest launched (AppIntentsTesting talks to a runner service that only an XCTest launch puts in the app). Each
/// intent's own `perform()` runs in the app with its real state; only the speech that picks the intent is skipped.
/// The type and parameter names are the app's Swift names, which `Metadata.appintents` records.
@available(iOS 27.0, *)
struct JourneyIntents {
    static let bundleIdentifier = "app.spoonjoy"

    private let definitions = IntentDefinitions(bundleIdentifier: JourneyIntents.bundleIdentifier)

    /// Waits until App Intents knows the app. The system registers an installed app's intents on its own time, and
    /// until then every call fails with metadata error 400, "app.spoonjoy is not present" (run 43120179185, issue
    /// #301). Only that error waits, for at most `seconds`; any other error fails the journey at once.
    func waitUntilRegistered(seconds: Int = 60, waited: Int = 0) async throws {
        do {
            _ = try await definitions.entities["SpoonjoyRecipeEntity"].entities(matching: "")
        } catch let error as NSError where error.domain == "AppIntentsServicesMetadataErrorDomain" && error.code == 400 {
            guard waited < seconds else {
                throw error
            }
            try await Task.sleep(for: .seconds(2))
            try await waitUntilRegistered(seconds: seconds, waited: waited + 2)
        }
    }

    /// Siri's "Which Spoonjoy recipe?": the recipe query matched against the spoken title. The query reads the app's
    /// synced kitchen, so a recipe created on QA a moment ago may take a few reads to arrive. Recursion instead of a
    /// loop keeps the journey rules simple.
    func recipe(titled title: String, recipeID: String, attempts: Int = 30) async throws -> AnyAppEntity {
        let found = try await definitions.entities["SpoonjoyRecipeEntity"].entities(matching: title)
        // A signed-in recipe entity's id ends in the recipe id (RecipeCookbookEntityCatalog.recipeEntityIdentifier).
        if let match = found.first(where: { $0.identifier.instanceIdentifier.hasSuffix(recipeID) }) {
            return match
        }
        guard attempts > 1 else {
            throw JourneyIntentsError.recipeNotFound(title: title, recipeID: recipeID, lastFound: found.map(\.identifier.instanceIdentifier))
        }
        try await Task.sleep(for: .seconds(1))
        return try await recipe(titled: title, recipeID: recipeID, attempts: attempts - 1)
    }

    /// "Start cooking in Spoonjoy", once Siri knows the recipe.
    func startCooking(_ recipe: AnyAppEntity) async throws {
        try await definitions.intents["StartCookModeIntent"].makeIntent(recipe: recipe).run()
    }

    /// "Next step in Spoonjoy".
    func nextStep() async throws {
        try await definitions.intents["NextCookStepIntent"].makeIntent().run()
    }

    /// "Previous step in Spoonjoy".
    func previousStep() async throws {
        try await definitions.intents["PreviousCookStepIntent"].makeIntent().run()
    }

    /// "Read the step in Spoonjoy".
    func readStep() async throws {
        try await definitions.intents["ReadCookStepIntent"].makeIntent().run()
    }

    /// "Start the step timer in Spoonjoy", for the step on screen.
    func startStepTimer() async throws {
        try await definitions.intents["StartCookStepTimerIntent"].makeIntent().run()
    }

    /// "Add to my Spoonjoy shopping list", after Siri asks what to add.
    func addShoppingItem(named name: String, quantity: Double) async throws {
        try await definitions.intents["AddShoppingListItemIntent"].makeIntent(name: name, quantity: quantity).run()
    }
}
