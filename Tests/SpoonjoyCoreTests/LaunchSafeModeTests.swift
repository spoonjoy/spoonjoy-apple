import Foundation
import Testing
@testable import SpoonjoyCore

// Launch safe mode: after two launches in a row that never finished opening, the next one shows a plain page instead
// of the shell. Prior art: Chromium iOS Safe Mode (failed-startup counter, threshold, plain screen, never trap the
// user) and expo-updates error recovery (a launch only counts as good some seconds after the first frame).
@Suite("Launch safe mode")
struct LaunchSafeModeTests {
    private final class MemoryStorage: LaunchSafeModeStorage {
        var stored: LaunchSafeModeState?
        func load() -> LaunchSafeModeState? { stored }
        func save(_ state: LaunchSafeModeState) { stored = state }
    }

    private static func ledger(_ storage: MemoryStorage, build: String = "100", threshold: Int = 2) -> LaunchSafeMode {
        LaunchSafeMode(storage: storage, buildVersion: build, threshold: threshold)
    }

    private static func safe(_ unfinished: Int, reads: Bool = true, reports: Bool) -> LaunchSafeMode.Decision {
        .safeMode(LaunchSafeMode.SafeLaunch(unfinishedLaunches: unfinished, readsRecentRecipes: reads, reportsLoop: reports))
    }

    // MARK: - Counting

    @Test("a first launch is normal and counts as started, under this build")
    func firstLaunchIsNormal() {
        let storage = MemoryStorage()
        let ledger = Self.ledger(storage)

        #expect(ledger.beginLaunch() == .normal)
        #expect(ledger.unfinishedLaunches == 1)
        #expect(storage.stored == LaunchSafeModeState(unfinishedLaunches: 1, buildVersion: "100"))
    }

    @Test("a launch that reaches success clears the count")
    func successClearsCount() {
        let storage = MemoryStorage()
        let ledger = Self.ledger(storage)
        _ = ledger.beginLaunch()
        ledger.markLaunchSucceeded()

        #expect(ledger.unfinishedLaunches == 0)
        // One unfinished launch after a finished one is still normal next time.
        _ = ledger.beginLaunch()
        #expect(Self.ledger(storage).beginLaunch() == .normal)
    }

    @Test("two launches that never finish send the third to safe mode, without counting it, and report the loop once")
    func twoUnfinishedLaunchesTriggerSafeMode() {
        let storage = MemoryStorage()
        #expect(Self.ledger(storage).beginLaunch() == .normal)
        #expect(Self.ledger(storage).beginLaunch() == .normal)

        let third = Self.ledger(storage)
        #expect(third.beginLaunch() == Self.safe(2, reports: true))
        #expect(third.unfinishedLaunches == 2)
        third.markSafeLaunchSettled()
        // Safe mode stays until Try again, and the loop is not reported a second time.
        #expect(Self.ledger(storage).beginLaunch() == Self.safe(2, reports: false))
    }

    @Test("a safe launch that never settled makes the next one bare: no recipe read")
    func unsettledSafeLaunchIsBare() {
        let storage = MemoryStorage()
        storage.stored = LaunchSafeModeState(unfinishedLaunches: 2, buildVersion: "100")
        #expect(Self.ledger(storage).beginLaunch() == Self.safe(2, reports: true))
        #expect(Self.ledger(storage).beginLaunch() == Self.safe(2, reads: false, reports: false))

        Self.ledger(storage).markSafeLaunchSettled()
        #expect(Self.ledger(storage).beginLaunch() == Self.safe(2, reports: false))
    }

    @Test("one unfinished launch is not enough")
    func oneUnfinishedLaunchIsNotEnough() {
        let storage = MemoryStorage()
        _ = Self.ledger(storage).beginLaunch()

        #expect(Self.ledger(storage).beginLaunch() == .normal)
    }

    @Test("Try again leaves the count one short of the threshold, so a shell that still fails comes straight back")
    func tryAgainLeavesOneShort() {
        let storage = MemoryStorage()
        storage.stored = LaunchSafeModeState(unfinishedLaunches: 2, buildVersion: "100")
        let ledger = Self.ledger(storage)
        #expect(ledger.beginLaunch() == Self.safe(2, reports: true))

        ledger.leaveSafeMode()

        #expect(ledger.unfinishedLaunches == 1)
        #expect(storage.stored?.safeLaunchUnsettled == false)
        #expect(storage.stored?.loopReported == true)
        // The shell Try again loaded is the launch that brings the count back to the threshold.
        _ = Self.ledger(storage).beginLaunch()
        #expect(Self.ledger(storage).beginLaunch() == Self.safe(2, reports: false))
    }

    @Test("a new build starts from zero, so an update clears safe mode")
    func newBuildClearsSafeMode() {
        let storage = MemoryStorage()
        storage.stored = LaunchSafeModeState(unfinishedLaunches: 2, buildVersion: "100", safeLaunchUnsettled: true, loopReported: true)

        let updated = Self.ledger(storage, build: "101")
        #expect(updated.unfinishedLaunches == 0)
        #expect(updated.beginLaunch() == .normal)
        #expect(storage.stored == LaunchSafeModeState(unfinishedLaunches: 1, buildVersion: "101"))
    }

    @Test("a custom threshold is honoured, and never drops below one")
    func customThreshold() {
        let storage = MemoryStorage()
        let ledger = Self.ledger(storage, threshold: 3)
        #expect(ledger.threshold == 3)
        #expect(ledger.buildVersion == "100")
        _ = ledger.beginLaunch()
        _ = ledger.beginLaunch()
        #expect(ledger.beginLaunch() == .normal)
        #expect(ledger.beginLaunch() == Self.safe(3, reports: true))
        ledger.leaveSafeMode()
        #expect(ledger.unfinishedLaunches == 2)

        #expect(Self.ledger(MemoryStorage(), threshold: 0).threshold == 1)
    }

    @Test("a negative stored count reads as zero")
    func negativeCount() {
        let storage = MemoryStorage()
        storage.stored = LaunchSafeModeState(unfinishedLaunches: -4, buildVersion: "100")
        let ledger = Self.ledger(storage)

        #expect(ledger.unfinishedLaunches == 0)
        #expect(ledger.beginLaunch() == .normal)
        #expect(ledger.unfinishedLaunches == 1)
    }

    @Test("a preset below the threshold starts a fresh loop; at the threshold it keeps the loop's flags")
    func preset() {
        let storage = MemoryStorage()
        storage.stored = LaunchSafeModeState(unfinishedLaunches: 2, buildVersion: "100", safeLaunchUnsettled: true, loopReported: true)
        let ledger = Self.ledger(storage)

        ledger.presetUnfinishedLaunches(-1)
        #expect(storage.stored == LaunchSafeModeState(unfinishedLaunches: 0, buildVersion: "100"))

        storage.stored = LaunchSafeModeState(unfinishedLaunches: 0, buildVersion: "100", safeLaunchUnsettled: true, loopReported: true)
        ledger.presetUnfinishedLaunches(2)
        #expect(storage.stored == LaunchSafeModeState(unfinishedLaunches: 2, buildVersion: "100", safeLaunchUnsettled: true, loopReported: true))
    }

    @Test("success waits a few seconds after the first frame, like expo-updates")
    func constants() {
        #expect(LaunchSafeMode.successDelay == .seconds(3))
        #expect(LaunchSafeMode.defaultThreshold == 2)
    }

    // MARK: - File storage

    @Test("the state file round-trips and is written at once, so the count survives a crash right after")
    func fileRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchSafeModeFile-\(UUID().uuidString)", isDirectory: true)
        let file = LaunchSafeModeFile(appDirectory: directory)
        #expect(file.fileURL.lastPathComponent == LaunchSafeModeFile.fileName)
        #expect(file.load() == nil)

        _ = LaunchSafeMode(storage: file, buildVersion: "7").beginLaunch()
        _ = LaunchSafeMode(storage: LaunchSafeModeFile(fileURL: file.fileURL), buildVersion: "7").beginLaunch()

        #expect(LaunchSafeModeFile(fileURL: file.fileURL).load() == LaunchSafeModeState(unfinishedLaunches: 2, buildVersion: "7"))
    }

    @Test("an unreadable state file reads as no state, so it can never trap anyone")
    func corruptFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchSafeModeFile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = LaunchSafeModeFile(appDirectory: directory)
        try Data("{ nope".utf8).write(to: file.fileURL)

        #expect(file.load() == nil)
        #expect(LaunchSafeMode(storage: file, buildVersion: "7").beginLaunch() == .normal)
    }

    // MARK: - Launch options

    @Test("a shipping build is always armed and ignores the test arguments")
    func releaseOptionsIgnoreTestArguments() {
        let options = LaunchSafeModeOptions(
            arguments: [
                "Spoonjoy",
                LaunchSafeModeOptions.armArgument,
                LaunchSafeModeOptions.neverSucceedArgument,
                LaunchSafeModeOptions.crashShellArgument,
                LaunchSafeModeOptions.presetArgument, "2"
            ],
            isDebugBuild: false
        )

        #expect(options == LaunchSafeModeOptions(armed: true, presetUnfinishedLaunches: nil, neverSucceeds: false, crashesShell: false))
    }

    @Test("a debug build stays out of the way unless a test arms it, so quick UI test relaunches never trip it")
    func debugOptionsAreUnarmedByDefault() {
        let options = LaunchSafeModeOptions(arguments: ["Spoonjoy", "-AppleLanguages", "(en)"], isDebugBuild: true)

        #expect(options == LaunchSafeModeOptions(armed: false, presetUnfinishedLaunches: nil, neverSucceeds: false))
    }

    @Test("a debug build reads the arm, preset, never-succeed and crash arguments")
    func debugOptionsReadTestArguments() {
        let options = LaunchSafeModeOptions(
            arguments: [
                "Spoonjoy",
                LaunchSafeModeOptions.armArgument,
                LaunchSafeModeOptions.presetArgument, "0",
                LaunchSafeModeOptions.neverSucceedArgument,
                LaunchSafeModeOptions.crashShellArgument
            ],
            isDebugBuild: true
        )

        #expect(options == LaunchSafeModeOptions(armed: true, presetUnfinishedLaunches: 0, neverSucceeds: true, crashesShell: true))
    }

    @Test("a preset with no number, or a word, is ignored")
    func malformedPresetIsIgnored() {
        let trailing = LaunchSafeModeOptions(
            arguments: [LaunchSafeModeOptions.armArgument, LaunchSafeModeOptions.presetArgument],
            isDebugBuild: true
        )
        let word = LaunchSafeModeOptions(
            arguments: [LaunchSafeModeOptions.presetArgument, "two", LaunchSafeModeOptions.armArgument],
            isDebugBuild: true
        )

        #expect(trailing.presetUnfinishedLaunches == nil)
        #expect(word.presetUnfinishedLaunches == nil)
    }

    // MARK: - Telemetry

    @Test("a crash loop reports through the existing native telemetry event, never a new endpoint")
    func telemetryEvent() throws {
        let metadata = NativeTelemetryAppMetadata(platform: "ios", appVersion: "1.3", buildNumber: "42")
        let event = LaunchSafeMode.enteredTelemetryEvent(
            unfinishedLaunches: 2,
            environment: "production",
            metadata: metadata
        )

        #expect(event.name == .bootstrapFailed)
        #expect(event.stage == "launch_safe_mode")
        #expect(event.errorType == "launch_crash_loop")
        #expect(event.retry == "unfinished_launches_2")
        #expect(event.environment == "production")
        #expect(event.metadata == metadata)

        let request = try NativeTelemetryRequests.recordEvent(event).urlRequest(configuration: .spoonjoyProduction)
        #expect(request.url.path == "/api/v1/native/telemetry")
    }
}

@Suite("Launch safe mode recent recipes")
struct LaunchSafeModeRecentRecipesTests {
    private static func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchSafeModeRecentRecipesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func write(_ json: String, in directory: URL) throws {
        try Data(json.utf8).write(to: directory.appendingPathComponent(NativeProcessSyncStore.syncStoreFileName))
    }

    @Test("reads recipe titles newest first, skipping other kinds, blank titles, deleted and tombstoned recipes")
    func readsNewestFirst() throws {
        let directory = try Self.directory()
        try Self.write("""
        {
          "cachedRecords": [
            {"kind": "recipe", "resourceID": "r1", "payload": {"title": "Old soup", "updatedAt": "2026-01-01T00:00:00.000Z", "deletedAt": null}},
            {"kind": "cookbook", "resourceID": "c1", "payload": {"title": "Not a recipe", "updatedAt": "2026-12-01T00:00:00.000Z"}},
            {"kind": "recipe", "resourceID": "r2", "payload": {"title": "  Lemon pasta ", "updatedAt": "2026-11-01T00:00:00.000Z", "steps": [{"deep": {"deeper": [1, 2]}}]}},
            {"kind": "recipe", "resourceID": "r3", "payload": {"title": "   ", "updatedAt": "2026-11-02T00:00:00.000Z"}},
            {"kind": "recipe", "resourceID": "r4", "payload": {"updatedAt": "2026-11-03T00:00:00.000Z"}},
            {"kind": "recipe", "resourceID": "r5", "payload": "not an object"},
            {"kind": "recipe", "resourceID": "r6", "payload": {"title": "Undated toast"}},
            {"kind": "recipe", "resourceID": "r7", "payload": {"title": 7}},
            {"kind": "recipe", "resourceID": "r8", "payload": {"title": "Deleted stew", "updatedAt": "2026-11-09T00:00:00.000Z", "deletedAt": "2026-11-09T00:00:00.000Z"}},
            {"kind": "recipe", "resourceID": "r9", "payload": {"title": "Tombstoned pie", "updatedAt": "2026-11-09T00:00:00.000Z"}},
            {"kind": "spoon", "resourceID": "r1", "payload": {"title": "A spoon"}}
          ],
          "tombstones": [
            {"resourceType": "recipe", "resourceID": "r9", "deletedAt": "2026-11-10T00:00:00.000Z", "updatedAt": "2026-11-10T00:00:00.000Z"},
            {"resourceType": "cookbook", "resourceID": "r1", "deletedAt": "2026-11-10T00:00:00.000Z", "updatedAt": "2026-11-10T00:00:00.000Z"}
          ]
        }
        """, in: directory)

        let recipes = try LaunchSafeModeRecentRecipes.read(appDirectory: directory)

        #expect(recipes == [
            LaunchSafeModeRecentRecipe(id: "r2", title: "Lemon pasta"),
            LaunchSafeModeRecentRecipe(id: "r1", title: "Old soup"),
            LaunchSafeModeRecentRecipe(id: "r6", title: "Undated toast")
        ])
    }

    @Test("keeps at most the limit, eight by default")
    func honoursLimit() throws {
        let directory = try Self.directory()
        let records = (1...9).map { index in
            #"{"kind": "recipe", "resourceID": "r\#(index)", "payload": {"title": "Recipe \#(index)", "updatedAt": "2026-11-0\#(index)T00:00:00.000Z"}}"#
        }
        try Self.write(#"{"cachedRecords": [\#(records.joined(separator: ","))]}"#, in: directory)

        #expect(try LaunchSafeModeRecentRecipes.read(appDirectory: directory, limit: 3).map(\.title) == ["Recipe 9", "Recipe 8", "Recipe 7"])
        #expect(try LaunchSafeModeRecentRecipes.read(appDirectory: directory).count == 8)
        #expect(LaunchSafeModeRecentRecipes.defaultLimit == 8)
    }

    @Test("a store over the size limit is not read at all")
    func skipsLargeFile() throws {
        let directory = try Self.directory()
        try Self.write(#"{"cachedRecords": [{"kind": "recipe", "resourceID": "r1", "payload": {"title": "Soup"}}]}"#, in: directory)

        #expect(try LaunchSafeModeRecentRecipes.read(appDirectory: directory, maximumFileBytes: 10).isEmpty)
        #expect(LaunchSafeModeRecentRecipes.maximumFileBytes == 5 * 1024 * 1024)
    }

    @Test("no sync store yet means no recipes, and a store with no records too")
    func missingStore() throws {
        let directory = try Self.directory()
        #expect(try LaunchSafeModeRecentRecipes.read(appDirectory: directory).isEmpty)

        try Self.write("{}", in: directory)
        #expect(try LaunchSafeModeRecentRecipes.read(appDirectory: directory).isEmpty)
    }

    @Test("a corrupt store throws, so the safe page simply shows no list")
    func corruptStoreThrows() throws {
        let directory = try Self.directory()
        try Self.write("{ not json", in: directory)

        #expect(throws: (any Error).self) {
            try LaunchSafeModeRecentRecipes.read(appDirectory: directory)
        }
    }

    @Test("reading never writes: the store file is byte for byte the same afterwards")
    func readOnly() throws {
        let directory = try Self.directory()
        let json = #"{"cachedRecords": [{"kind": "recipe", "resourceID": "r1", "payload": {"title": "Soup"}}], "queue": {"x": 1}}"#
        try Self.write(json, in: directory)

        _ = try LaunchSafeModeRecentRecipes.read(appDirectory: directory)

        let after = try String(contentsOf: directory.appendingPathComponent(NativeProcessSyncStore.syncStoreFileName), encoding: .utf8)
        #expect(after == json)
    }
}
