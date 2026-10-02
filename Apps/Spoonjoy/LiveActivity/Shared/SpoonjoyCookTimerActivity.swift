import ActivityKit
import AppIntents
import Foundation

/// Shared by the app (which starts and updates the activity) and the widget extension (which draws it).
@available(iOS 26.0, *)
struct SpoonjoyCookTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case running
            case paused
            case finished
        }

        var phase: Phase
        /// The timer counts down from `startDate` to `endDate` while running.
        var startDate: Date
        var endDate: Date
        var pausedRemainingSeconds: Int
        /// "Step 2 of 5" for the step cook mode is on now.
        var stepLabel: String
        var stepTitle: String
        /// Set when the timer belongs to a different step than the one cook mode is on.
        var timerStepLabel: String?
        var canAdvance: Bool
        /// What the timer is for, so a button tap can rebuild it without the cook-mode screen.
        var timerStepID: String
        var timerStepNumber: Int
        var timerStepTitle: String
        var durationSeconds: Int
    }

    var recipeID: String
    var recipeTitle: String
    /// Tapping the activity opens cook mode for this recipe.
    var deepLink: URL
}

enum SpoonjoyCookActivityCommand: Sendable {
    case toggleTimer
    case nextStep
}

/// The app sets the handler at launch. Live Activity intents run in the app process, so the handler can reach cook mode.
@MainActor
enum SpoonjoyCookActivityBridge {
    static var handler: (@MainActor (SpoonjoyCookActivityCommand) async -> Void)?
}

@available(iOS 26.0, *)
struct ToggleCookTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume Timer"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await SpoonjoyCookActivityBridge.handler?(.toggleTimer)
        return .result()
    }
}

@available(iOS 26.0, *)
struct NextCookActivityStepIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next Step"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await SpoonjoyCookActivityBridge.handler?(.nextStep)
        return .result()
    }
}
