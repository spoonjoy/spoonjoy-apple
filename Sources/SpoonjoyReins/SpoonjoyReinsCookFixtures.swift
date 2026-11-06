import Foundation
import SpoonjoyCore

/// What cook mode reads from the device, replaced for a headless journey: how step alarms are set, what the mic hears,
/// and the screen it is laid out on.
public struct SpoonjoyReinsCookFixtures: Sendable {
    /// How a step's alarm is set.
    public enum Alarms: Sendable, Equatable {
        /// The journeys' stand-in (`CookStepAlarms.journeyStandIn`), as a journey launch with
        /// `SPOONJOY_JOURNEY_ALARM_FIXTURE` gets: every start sets an alarm, and the shell records each one.
        case recording
        /// System timers refused, as the CI simulator refuses AlarmKit: the real `CookModeSystemTimerScheduler` runs
        /// against a client that reports `denied`, so the ring shows the app's own message.
        case denied
    }

    public var alarms: Alarms
    /// What the mic hears once it listens, as `SPOONJOY_JOURNEY_VOICE_FIXTURE` gives the app (nil: a mic that hears nothing).
    public var voice: NativeJourneyVoiceFixture?
    /// The pause before each transcript is heard. The app's journey stand-in waits five seconds; headless waits less.
    public var voiceSpacing: Duration
    public var display: SpoonjoyReinsDisplay

    public init(
        alarms: Alarms = .recording,
        voice: NativeJourneyVoiceFixture? = nil,
        voiceSpacing: Duration = .milliseconds(150),
        display: SpoonjoyReinsDisplay = .phone
    ) {
        self.alarms = alarms
        self.voice = voice
        self.voiceSpacing = voiceSpacing
        self.display = display
    }

    /// The same phrases VoiceJourney launches the app with.
    public static let voiceJourneyPhrases = NativeJourneyVoiceFixture.requested(environment: [
        NativeJourneyVoiceFixture.environmentKey: "okay next step|the next thing is garlic and onions|go back|start the timer|check all",
    ])
}

/// The screen cook mode lays out on and the accessibility settings it reads, as a journey launches the app with them
/// (`-SpoonjoyForcePosture`, the largest text size, Reduce Motion).
public struct SpoonjoyReinsDisplay: Sendable, Equatable {
    public var width: Double
    public var height: Double
    /// The horizontal size class is regular (a wide iPad or the Duo's inner screen).
    public var isRegularWidth: Bool
    /// What the hinge reports (`FoldReading.applyingForcedHinge`).
    public var hinge: HingePosture
    /// An accessibility text size (the journeys use the largest).
    public var accessibilityText: Bool
    public var reduceMotion: Bool

    public init(width: Double, height: Double, isRegularWidth: Bool, hinge: HingePosture = .unknown, accessibilityText: Bool = false, reduceMotion: Bool = false) {
        self.width = width
        self.height = height
        self.isRegularWidth = isRegularWidth
        self.hinge = hinge
        self.accessibilityText = accessibilityText
        self.reduceMotion = reduceMotion
    }

    /// The Journeys job's iPhone.
    public static let phone = SpoonjoyReinsDisplay(width: 402, height: 874, isRegularWidth: false)
    /// The iPhone Duo's inner screen held tall and stood half-open (`-SpoonjoyForcePosture tabletop`).
    public static let duoTabletop = SpoonjoyReinsDisplay(width: 600, height: 844, isRegularWidth: true, hinge: .partiallyOpen)
    /// The iPhone Duo folded shut (`-SpoonjoyForcePosture closed`): the cover screen.
    public static let duoClosed = SpoonjoyReinsDisplay(width: 402, height: 874, isRegularWidth: false, hinge: .closed)
    /// The iPhone Duo's inner screen open flat and held wide, which SpoonjoyWideJourneys runs on.
    public static let duoOpenWide = SpoonjoyReinsDisplay(width: 1_000, height: 700, isRegularWidth: true, hinge: .fullyOpen)

    public func with(accessibilityText: Bool = false, reduceMotion: Bool = false) -> SpoonjoyReinsDisplay {
        var display = self
        display.accessibilityText = accessibilityText
        display.reduceMotion = reduceMotion
        return display
    }
}

/// A clock a journey moves on by hand, so "the timer's end survives a relaunch" is checked at a later time than it
/// was set, without waiting. Pass `now` as the fixtures' clock.
public final class SpoonjoyReinsClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    public init(_ start: Date = Date(timeIntervalSince1970: 1_793_000_000)) {
        current = start
    }

    public var now: @Sendable () -> Date {
        { [self] in lock.withLock { current } }
    }

    public func advance(by seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}
