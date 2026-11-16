import Foundation

/// What launch safe mode remembers between launches.
public struct LaunchSafeModeState: Codable, Equatable, Sendable {
    /// Launches started since the last one that finished.
    public var unfinishedLaunches: Int
    /// The build (`CFBundleVersion`) that kept this count. A different build starts from zero, so an update that
    /// fixes a launch crash never opens on the safe page.
    public var buildVersion: String
    /// A safe launch started and has not yet settled. If the safe page itself never settles, the next safe launch
    /// shows the bare page and reads nothing.
    public var safeLaunchUnsettled: Bool
    /// This crash loop has already been reported, so later safe launches in the same loop stay quiet.
    public var loopReported: Bool

    public init(unfinishedLaunches: Int = 0, buildVersion: String, safeLaunchUnsettled: Bool = false, loopReported: Bool = false) {
        self.unfinishedLaunches = unfinishedLaunches
        self.buildVersion = buildVersion
        self.safeLaunchUnsettled = safeLaunchUnsettled
        self.loopReported = loopReported
    }
}

/// Where the state is kept between launches.
public protocol LaunchSafeModeStorage {
    func load() -> LaunchSafeModeState?
    func save(_ state: LaunchSafeModeState)
}

/// A small JSON file, written atomically and synchronously on every change, so the count is on disk before the
/// shell is built and survives a crash a moment later. A file that cannot be read reads as no state: safe mode must
/// never be the thing that traps the person.
public struct LaunchSafeModeFile: LaunchSafeModeStorage {
    public static let fileName = "launch-safe-mode.json"

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init(appDirectory: URL) {
        self.init(fileURL: appDirectory.appendingPathComponent(Self.fileName))
    }

    public func load() -> LaunchSafeModeState? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(LaunchSafeModeState.self, from: data)
    }

    public func save(_ state: LaunchSafeModeState) {
        // Encoding this plain struct cannot fail; a failed write leaves the last count, which errs toward normal.
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(state).write(to: fileURL, options: .atomic)
    }
}

/// Counts launches that never finished opening, so a launch crash loop ends on a plain page instead of a crash.
///
/// A launch is counted as started when its first window is built, before the main shell's view is built, and as
/// finished once the shell has been up and active for a few seconds, or when the shell's scene first goes to the
/// background. After `threshold` launches in a row that never finished, the next launch shows the safe page instead
/// of the shell, until the person taps Try again.
///
/// Crashes before the first window is built (in the App's init or `application(_:didFinishLaunchingWithOptions:)`)
/// are not counted: the launch has not started by this measure yet.
///
/// Prior art: Chromium iOS Safe Mode (a failed-startup counter, a threshold, a plain screen, never trapping the
/// person) and expo-updates error recovery (a launch only counts as good some seconds after its first render).
public struct LaunchSafeMode {
    public struct SafeLaunch: Equatable, Sendable {
        public let unfinishedLaunches: Int
        /// False when the last safe launch never settled: show the bare page and read nothing.
        public let readsRecentRecipes: Bool
        /// True only for the first safe launch of a crash loop.
        public let reportsLoop: Bool

        public init(unfinishedLaunches: Int, readsRecentRecipes: Bool, reportsLoop: Bool) {
            self.unfinishedLaunches = unfinishedLaunches
            self.readsRecentRecipes = readsRecentRecipes
            self.reportsLoop = reportsLoop
        }
    }

    public enum Decision: Equatable, Sendable {
        case normal
        case safeMode(SafeLaunch)
    }

    public static let defaultThreshold = 2
    /// How long the shell must stay up, active, before the launch counts as finished: the same settle time as the
    /// `launch_completed` report (``NativeLaunchSettlement``), so both agree on what a finished launch is.
    public static var successDelay: Duration { NativeLaunchSettlement.settleDelay }

    public let threshold: Int
    public let buildVersion: String
    private let storage: any LaunchSafeModeStorage

    public init(storage: any LaunchSafeModeStorage, buildVersion: String, threshold: Int = LaunchSafeMode.defaultThreshold) {
        self.storage = storage
        self.buildVersion = buildVersion
        self.threshold = max(1, threshold)
    }

    /// The stored state, or a fresh one when there is none or another build kept it.
    public var state: LaunchSafeModeState {
        guard let stored = storage.load(), stored.buildVersion == buildVersion else {
            return LaunchSafeModeState(buildVersion: buildVersion)
        }
        return stored
    }

    public var unfinishedLaunches: Int {
        max(0, state.unfinishedLaunches)
    }

    /// Decides this launch, once per process, before the shell is built. A normal launch is counted as started
    /// right away, so a crash while the shell builds still counts. A safe launch is not counted, so the count stays
    /// at the threshold until the person chooses to try again.
    public func beginLaunch() -> Decision {
        var current = state
        let unfinished = max(0, current.unfinishedLaunches)
        if unfinished >= threshold {
            let launch = SafeLaunch(
                unfinishedLaunches: unfinished,
                readsRecentRecipes: !current.safeLaunchUnsettled,
                reportsLoop: !current.loopReported
            )
            current.safeLaunchUnsettled = true
            current.loopReported = true
            storage.save(current)
            return .safeMode(launch)
        }
        current.unfinishedLaunches = unfinished + 1
        storage.save(current)
        return .normal
    }

    /// The shell stayed up: the streak and the loop are over.
    public func markLaunchSucceeded() {
        storage.save(LaunchSafeModeState(buildVersion: buildVersion))
    }

    /// The safe page stayed up: the next safe launch may read recent recipes again.
    public func markSafeLaunchSettled() {
        var current = state
        current.safeLaunchUnsettled = false
        storage.save(current)
    }

    /// Try again: one launch short of the threshold, so a shell that still fails before it settles brings the safe
    /// page straight back on the next launch instead of looping. The loop stays reported.
    public func leaveSafeMode() {
        var current = state
        current.unfinishedLaunches = threshold - 1
        current.safeLaunchUnsettled = false
        storage.save(current)
    }

    /// Debug builds only: sets the count, so a UI test can start from a known place.
    public func presetUnfinishedLaunches(_ count: Int) {
        var current = state
        current.unfinishedLaunches = max(0, count)
        if current.unfinishedLaunches < threshold {
            current.loopReported = false
            current.safeLaunchUnsettled = false
        }
        storage.save(current)
    }

    /// The report for a crash loop. It travels through the existing native telemetry event
    /// (`POST /api/v1/native/telemetry`), whose event names the server constrains, so it is a `bootstrap_failed`
    /// event at the `launch_safe_mode` stage rather than a new event or endpoint.
    public static func enteredTelemetryEvent(
        unfinishedLaunches: Int,
        environment: String,
        metadata: NativeTelemetryAppMetadata
    ) -> NativeTelemetryEvent {
        NativeTelemetryEvent(
            name: .bootstrapFailed,
            stage: "launch_safe_mode",
            environment: environment,
            metadata: metadata,
            errorType: "launch_crash_loop",
            retry: "unfinished_launches_\(unfinishedLaunches)"
        )
    }
}

/// How this process treats launch safe mode, from its launch arguments.
///
/// A shipping build is always armed and ignores every argument. A debug build is armed only when a test asks
/// (`-SpoonjoyLaunchSafeModeArmed`): UI tests relaunch the app within seconds all day, and would otherwise trip it.
public struct LaunchSafeModeOptions: Equatable, Sendable {
    public static let armArgument = "-SpoonjoyLaunchSafeModeArmed"
    /// Followed by a number: sets the unfinished-launch count before this launch is decided.
    public static let presetArgument = "-SpoonjoyLaunchSafeModeUnfinishedLaunches"
    /// This launch never counts as finished, as if it crashed before the shell settled.
    public static let neverSucceedArgument = "-SpoonjoyLaunchSafeModeNeverSucceed"
    /// The shell crashes the app for real, once it has been built and before the launch can finish.
    public static let crashShellArgument = "-SpoonjoyLaunchSafeModeCrashShell"

    public let armed: Bool
    public let presetUnfinishedLaunches: Int?
    public let neverSucceeds: Bool
    public let crashesShell: Bool

    public init(armed: Bool, presetUnfinishedLaunches: Int?, neverSucceeds: Bool, crashesShell: Bool = false) {
        self.armed = armed
        self.presetUnfinishedLaunches = presetUnfinishedLaunches
        self.neverSucceeds = neverSucceeds
        self.crashesShell = crashesShell
    }

    public init(arguments: [String], isDebugBuild: Bool) {
        guard isDebugBuild else {
            self.init(armed: true, presetUnfinishedLaunches: nil, neverSucceeds: false)
            return
        }
        var preset: Int?
        if let index = arguments.firstIndex(of: Self.presetArgument), arguments.indices.contains(index + 1) {
            preset = Int(arguments[index + 1])
        }
        self.init(
            armed: arguments.contains(Self.armArgument),
            presetUnfinishedLaunches: preset,
            neverSucceeds: arguments.contains(Self.neverSucceedArgument),
            crashesShell: arguments.contains(Self.crashShellArgument)
        )
    }
}

public struct LaunchSafeModeRecentRecipe: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// The safe page's most recent recipes, read straight from the sync store's file without opening the store. It
/// never writes, skips a file over `maximumFileBytes`, and decodes only each record's kind, id, title, date and
/// deletion, so a recipe the full model cannot read still cannot take the safe page down. Deleted and tombstoned
/// recipes are left out. A file that cannot be read throws, and the page then shows no list.
public enum LaunchSafeModeRecentRecipes {
    public static let defaultLimit = 8
    public static let maximumFileBytes = 5 * 1024 * 1024

    private struct StoreFile: Decodable {
        let cachedRecords: [Record]?
        let tombstones: [Tombstone]?
    }

    private struct Tombstone: Decodable {
        let resourceType: String
        let resourceID: String
    }

    private struct Record: Decodable {
        let kind: String
        let resourceID: String
        let payload: Payload
    }

    /// Only the fields the list needs; anything else in the payload, or a payload that is not an object, is skipped.
    private struct Payload: Decodable {
        private enum CodingKeys: String, CodingKey {
            case title
            case updatedAt
            case deletedAt
        }

        let title: String?
        let updatedAt: String?
        let deleted: Bool

        init(from decoder: Decoder) throws {
            guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
                title = nil
                updatedAt = nil
                deleted = false
                return
            }
            title = try? container.decode(String.self, forKey: .title)
            updatedAt = try? container.decode(String.self, forKey: .updatedAt)
            deleted = (try? container.decode(String.self, forKey: .deletedAt)) != nil
        }
    }

    public static func read(
        appDirectory: URL,
        limit: Int = defaultLimit,
        maximumFileBytes: Int = maximumFileBytes
    ) throws -> [LaunchSafeModeRecentRecipe] {
        let fileURL = appDirectory.appendingPathComponent(NativeProcessSyncStore.syncStoreFileName)
        guard let size = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int,
              size <= maximumFileBytes else {
            return []
        }
        let file = try JSONDecoder().decode(StoreFile.self, from: Data(contentsOf: fileURL))
        let recipeKind = NativeSyncEntryKind.recipe.rawValue
        let tombstoned = Set((file.tombstones ?? []).filter { $0.resourceType == recipeKind }.map(\.resourceID))
        let dated = (file.cachedRecords ?? []).compactMap { record -> (recipe: LaunchSafeModeRecentRecipe, updatedAt: String)? in
            guard record.kind == recipeKind,
                  !record.payload.deleted,
                  !tombstoned.contains(record.resourceID),
                  let title = record.payload.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else {
                return nil
            }
            return (LaunchSafeModeRecentRecipe(id: record.resourceID, title: title), record.payload.updatedAt ?? "")
        }
        return dated
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map(\.recipe)
    }
}
