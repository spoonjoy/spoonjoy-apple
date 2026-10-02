#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import Foundation

/// What the step alarm carries, so its system Live Activity can show the recipe and step.
/// The app schedules the alarm with this metadata and the widget extension draws it, so AlarmKit stays the one source of timer state.
@available(iOS 26.0, *)
struct SpoonjoyCookTimerMetadata: AlarmMetadata {
    let recipeID: String
    let recipeTitle: String
    let stepID: String
    let stepNumber: Int
    let stepTitle: String
    let durationMinutes: Int
    /// Tapping the activity opens cook mode for this recipe.
    let deepLink: String
}

enum SpoonjoyCookActivityCommand: Sendable {
    case pause(alarmID: UUID)
    case resume(alarmID: UUID)
    case nextStep(recipeID: String)
}

/// The app sets the handler at launch. Live Activity intents run in the app process, so the handler can reach cook mode and the alarm.
@MainActor
enum SpoonjoyCookActivityBridge {
    static var handler: (@MainActor (SpoonjoyCookActivityCommand) async -> Void)?
}

@available(iOS 26.0, *)
struct PauseCookTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause Timer"
    static let isDiscoverable = false

    @Parameter(title: "Timer")
    var alarmID: String

    init() {
        alarmID = ""
    }

    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            await SpoonjoyCookActivityBridge.handler?(.pause(alarmID: id))
        }
        return .result()
    }
}

@available(iOS 26.0, *)
struct ResumeCookTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume Timer"
    static let isDiscoverable = false

    @Parameter(title: "Timer")
    var alarmID: String

    init() {
        alarmID = ""
    }

    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            await SpoonjoyCookActivityBridge.handler?(.resume(alarmID: id))
        }
        return .result()
    }
}

/// Opens the app, because stepping cook mode needs the screen. When cook mode is open the step advances; otherwise it opens at the recipe.
@available(iOS 26.0, *)
struct NextCookActivityStepIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next Step"
    static let isDiscoverable = false
    static let openAppWhenRun = true

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
        await SpoonjoyCookActivityBridge.handler?(.nextStep(recipeID: recipeID))
        return .result()
    }
}
#endif
