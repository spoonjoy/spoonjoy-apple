import ActivityKit
import AppIntents
import Foundation
#if !SPOONJOY_WIDGET_EXTENSION
// The widget extension links no package, so it compiles the snapshot file itself instead of importing SpoonjoyCore.
import SpoonjoyCore
#endif

/// The cook-mode session Live Activity: which step is up, what is checked, and up to three step timers.
/// AlarmKit still draws each timer's own countdown activity; this one shows the whole session.
struct SpoonjoyCookSessionAttributes: ActivityAttributes {
    typealias ContentState = CookSessionSnapshot

    let recipeID: String
    /// Tapping the activity opens cook mode for this recipe. The app builds it, so the widget never copies the route.
    let deepLink: String
}

enum SpoonjoyCookSessionCommand: Sendable {
    case checkStep(recipeID: String)
    case nextStep(recipeID: String)
    /// Opens cook mode at the recipe, for a button pressed after cook mode has gone.
    case open(recipeID: String)
}

/// The app sets the handler at launch. Live Activity intents run in the app process, so it reaches cook mode directly.
@MainActor
enum SpoonjoyCookSessionBridge {
    /// Returns true when cook mode was open and took the command.
    static var handler: (@MainActor (SpoonjoyCookSessionCommand) async -> Bool)?

    /// Runs the command in the background when cook mode is still open. Otherwise it brings the app forward and
    /// opens cook mode at the recipe, because only cook mode can change the step.
    static func perform(_ command: SpoonjoyCookSessionCommand, recipeID: String, intent: some AppIntent) async throws {
        if await handler?(command) == true {
            return
        }
        try await intent.continueInForeground(alwaysConfirm: false)
        _ = await handler?(.open(recipeID: recipeID))
    }
}

/// Checks off everything the current step uses, without opening the app when cook mode is still open.
struct CheckCurrentStepIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Check Off Step"
    static let isDiscoverable = false
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @Parameter(title: "Recipe")
    var recipeID: String

    init() {
        recipeID = ""
    }

    init(recipeID: String) {
        self.recipeID = recipeID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await SpoonjoyCookSessionBridge.perform(.checkStep(recipeID: recipeID), recipeID: recipeID, intent: self)
        return .result()
    }
}

/// Moves cook mode to the next step without opening the app when it can; otherwise it opens the app.
struct NextCookSessionStepIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next Step"
    static let isDiscoverable = false
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @Parameter(title: "Recipe")
    var recipeID: String

    init() {
        recipeID = ""
    }

    init(recipeID: String) {
        self.recipeID = recipeID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await SpoonjoyCookSessionBridge.perform(.nextStep(recipeID: recipeID), recipeID: recipeID, intent: self)
        return .result()
    }
}
