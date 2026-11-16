import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native kill switches")
struct NativeKillSwitchesTests {
    static let baseURL = URL(string: "https://spoonjoy.test")!

    static func withDefaults<T>(_ body: (UserDefaults) async throws -> T) async throws -> T {
        let suite = "spoonjoy-kill-switches-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        return try await body(defaults)
    }

    static func envelope(_ killSwitches: String) -> String {
        #"{"ok":true,"requestId":"req_1","data":{"killSwitches":\#(killSwitches),"features":["cook-session-sync","spotlight-indexing"]}}"#
    }

    @Test("the feature names match spoonjoy-v2's NATIVE_FEATURES")
    func featureNames() {
        #expect(NativeFeature.allCases.map(\.rawValue) == ["cook-session-sync", "spotlight-indexing"])
    }

    @Test("everything is on until a feature is switched off")
    func switches() {
        #expect(NativeKillSwitches.allOn.allows(.cookSessionSync))
        #expect(NativeKillSwitches.allOn.allows(.spotlightIndexing))

        let off = NativeKillSwitches(off: [.spotlightIndexing])
        #expect(off.isOff(.spotlightIndexing))
        #expect(!off.allows(.spotlightIndexing))
        #expect(off.allows(.cookSessionSync))

        // An entry that says off: false leaves the feature on.
        let mixed = NativeKillSwitches(switchedOff: [
            .cookSessionSync: NativeKillSwitch(off: false, reason: "back"),
            .spotlightIndexing: NativeKillSwitch(reason: "crash"),
        ])
        #expect(mixed.switchedOff == [.spotlightIndexing: NativeKillSwitch(reason: "crash")])
    }

    @Test("a running app adopts newly switched-off features but keeps its own until relaunch")
    func addingSwitchedOff() {
        let launched = NativeKillSwitches(switchedOff: [.cookSessionSync: NativeKillSwitch(reason: "launch")])
        let merged = launched.addingSwitchedOff(from: NativeKillSwitches(switchedOff: [
            .cookSessionSync: NativeKillSwitch(reason: "newer"),
            .spotlightIndexing: NativeKillSwitch(),
        ]))
        #expect(merged.switchedOff == [
            .cookSessionSync: NativeKillSwitch(reason: "launch"),
            .spotlightIndexing: NativeKillSwitch(),
        ])
        #expect(launched.addingSwitchedOff(from: .allOn) == launched)
    }

    @Test("decodes the recorded response and skips entries it does not know or cannot read")
    func decodesResponse() throws {
        let decoded = try APIEnvelope<NativeConfigResponse>.decode(Data(Self.envelope(
            #"{"cook-session-sync":{"off":true,"reason":"Repairs"},"spotlight-indexing":{"off":"yes"},"tabs":{"off":true,"reason":null}}"#
        ).utf8)).data
        #expect(decoded == NativeConfigResponse(killSwitches: NativeKillSwitches(switchedOff: [
            .cookSessionSync: NativeKillSwitch(reason: "Repairs"),
        ])))
        #expect(try APIEnvelope<NativeConfigResponse>.decode(Data(Self.envelope("{}").utf8)).data.killSwitches == .allOn)
        #expect(throws: (any Error).self) {
            try APIEnvelope<NativeConfigResponse>.decode(Data(Self.envelope("[]").utf8))
        }
    }

    @Test("the store keeps the last switches and reads everything on when it has none or cannot read them")
    func store() async throws {
        try await Self.withDefaults { defaults in
            let store = NativeKillSwitchStore(defaults: defaults)
            #expect(store.load() == .allOn)

            let saved = NativeKillSwitches(switchedOff: [.cookSessionSync: NativeKillSwitch(reason: "Repairs")])
            store.save(saved)
            #expect(NativeKillSwitchStore(defaults: defaults).load() == saved)

            let savedAt = Date().timeIntervalSinceReferenceDate
            defaults.set(Data(#"{"savedAt":\#(savedAt),"switches":{"cook-session-sync":{"off":true},"retired-feature":{"off":true}}}"#.utf8), forKey: NativeKillSwitchStore.key)
            #expect(store.load() == NativeKillSwitches(off: [.cookSessionSync]))

            // Switches saved without the time they were saved cannot be aged, so they read as everything on.
            defaults.set(Data(#"{"cook-session-sync":{"off":true}}"#.utf8), forKey: NativeKillSwitchStore.key)
            #expect(store.load() == .allOn)

            defaults.set(Data("garbage".utf8), forKey: NativeKillSwitchStore.key)
            #expect(store.load() == .allOn)
        }
    }

    @Test("saved switches older than 7 days are dropped, so everything is on again")
    func staleSwitches() async throws {
        try await Self.withDefaults { defaults in
            let store = NativeKillSwitchStore(defaults: defaults)
            let savedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)
            store.save(NativeKillSwitches(off: [.cookSessionSync, .spotlightIndexing]), at: savedAt)

            #expect(NativeKillSwitchStore.maxAge == 7 * 24 * 60 * 60)
            #expect(store.load(now: savedAt.addingTimeInterval(NativeKillSwitchStore.maxAge)) == NativeKillSwitches(off: [.cookSessionSync, .spotlightIndexing]))
            #expect(store.load(now: savedAt.addingTimeInterval(NativeKillSwitchStore.maxAge + 1)) == .allOn)

            // A launch eight days on runs with every feature on, and a failed refresh does not bring the old switches back.
            let center = NativeKillSwitchCenter(store: store, now: { savedAt.addingTimeInterval(8 * 24 * 60 * 60) }) {
                throw URLError(.notConnectedToInternet)
            }
            #expect(center.current == .allOn)
            #expect(await center.refresh() == nil)
            #expect(center.current == .allOn)
        }
    }

    @Test("gives up on a read that runs past its deadline in all")
    func fetchDeadline() async throws {
        // The session would answer only after an hour, so a timedOut error means the deadline won. (No wall-clock
        // bound: a busy CI runner can stall every test for minutes.)
        let error = await #expect(throws: URLError.self) {
            _ = try await NativeConfigRequests.fetch(baseURL: Self.baseURL, session: HangingSession(), deadline: .milliseconds(50))
        }
        #expect(error?.code == .timedOut)
    }

    @Test("reads the public config with a short timeout and no credentials")
    func fetch() async throws {
        let session = ScriptedCookURLSession(responses: [
            .json(200, Self.envelope(#"{"spotlight-indexing":{"off":true,"reason":null}}"#)),
            .json(503, #"{"ok":false}"#),
            .nonHTTP,
            .failure(URLError(.timedOut)),
            .json(200, "not json"),
        ])

        #expect(try await NativeConfigRequests.fetch(baseURL: Self.baseURL, session: session) == NativeKillSwitches(off: [.spotlightIndexing]))
        for _ in 0..<4 {
            await #expect(throws: (any Error).self) {
                _ = try await NativeConfigRequests.fetch(baseURL: Self.baseURL, session: session)
            }
        }

        let request = try #require(await session.requests.first)
        #expect(request.url?.absoluteString == "https://spoonjoy.test/api/v1/native/config")
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == NativeConfigRequests.timeout)
        #expect(request.timeoutInterval == 5)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test("launch reads the saved switches without the network, and a refresh saves the server's for the next launch")
    func centerRefresh() async throws {
        try await Self.withDefaults { defaults in
            let store = NativeKillSwitchStore(defaults: defaults)
            store.save(NativeKillSwitches(off: [.cookSessionSync]))
            let center = NativeKillSwitchCenter(store: store) {
                NativeKillSwitches(off: [.spotlightIndexing])
            }
            #expect(center.current == NativeKillSwitches(off: [.cookSessionSync]))
            #expect(center.isOff(.cookSessionSync))

            #expect(await center.refresh() == NativeKillSwitches(off: [.spotlightIndexing]))
            // Spotlight goes off now; cook sessions, back on at the server, stay off until the next launch.
            #expect(center.current == NativeKillSwitches(off: [.cookSessionSync, .spotlightIndexing]))
            #expect(store.load() == NativeKillSwitches(off: [.spotlightIndexing]))
            #expect(NativeKillSwitchCenter(store: store, fetch: { .allOn }).current == NativeKillSwitches(off: [.spotlightIndexing]))
        }
    }

    @Test("a failed refresh changes nothing, here or at the next launch")
    func centerRefreshFailure() async throws {
        try await Self.withDefaults { defaults in
            let store = NativeKillSwitchStore(defaults: defaults)
            store.save(NativeKillSwitches(off: [.spotlightIndexing]))
            let center = NativeKillSwitchCenter(store: store) { throw URLError(.notConnectedToInternet) }
            #expect(await center.refresh() == nil)
            #expect(center.current == NativeKillSwitches(off: [.spotlightIndexing]))
            #expect(store.load() == NativeKillSwitches(off: [.spotlightIndexing]))
        }
    }

    @Test("background refreshes run at most once every 15 minutes, and each adopts newly switched-off features")
    func centerRefreshThrottle() async throws {
        try await Self.withDefaults { defaults in
            let fetches = FetchCounter()
            let clock = TestClock(Date(timeIntervalSinceReferenceDate: 800_000_000))
            let center = NativeKillSwitchCenter(store: NativeKillSwitchStore(defaults: defaults), now: { clock.now }) {
                await fetches.increment()
                return await fetches.count == 1 ? NativeKillSwitches(off: [.cookSessionSync]) : NativeKillSwitches(off: [.spotlightIndexing])
            }
            #expect(NativeKillSwitchCenter.defaultRefreshInterval == 15 * 60)

            // Launch refreshes.
            _ = await center.refreshInBackgroundIfDue()?.value
            #expect(await fetches.count == 1)
            #expect(center.current == NativeKillSwitches(off: [.cookSessionSync]))

            // Coming to the foreground soon after does not.
            clock.advance(by: 14 * 60)
            #expect(center.refreshInBackgroundIfDue() == nil)
            #expect(await fetches.count == 1)

            // Fifteen minutes after the last refresh it does. Spotlight goes off now; cook sessions, back on at the
            // server, stay off until the next launch.
            clock.advance(by: 60)
            _ = await center.refreshInBackgroundIfDue()?.value
            #expect(await fetches.count == 2)
            #expect(center.current == NativeKillSwitches(off: [.cookSessionSync, .spotlightIndexing]))
            #expect(center.refreshInBackgroundIfDue() == nil)

            // A clock set back never stops refreshes.
            clock.advance(by: -60 * 60)
            _ = await center.refreshInBackgroundIfDue()?.value
            #expect(await fetches.count == 3)
        }
    }
}

/// A session that never answers until it is cancelled.
private struct HangingSession: URLSessionPerforming {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await Task.sleep(for: .seconds(3600))
        throw URLError(.cannotConnectToHost)
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date) {
        self.date = date
    }

    var now: Date {
        lock.withLock { date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { date = date.addingTimeInterval(interval) }
    }
}

private actor FetchCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
