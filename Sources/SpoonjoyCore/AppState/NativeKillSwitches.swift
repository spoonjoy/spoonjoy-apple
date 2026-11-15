import Foundation

/// A named feature path the server can switch off without an app build (`GET /api/v1/native/config`).
///
/// The names are shared with spoonjoy-v2's `NATIVE_FEATURES` (app/lib/native-kill-switches.server.ts) and
/// documented in its docs/api.md, "Native kill switches"; add a name on both sides.
public enum NativeFeature: String, CaseIterable, Codable, Sendable {
    /// Cross-device cook progress: the store's exchange with `/api/cook-sessions`. Off, progress stays on the device.
    case cookSessionSync = "cook-session-sync"
    /// The Spotlight and App Entity index refresh. Off, the index keeps what it already holds.
    case spotlightIndexing = "spotlight-indexing"
}

/// One feature the server switched off, and why.
public struct NativeKillSwitch: Codable, Equatable, Sendable {
    public let off: Bool
    public let reason: String?

    public init(off: Bool = true, reason: String? = nil) {
        self.off = off
        self.reason = reason
    }
}

/// The features switched off. Every feature not listed is on, and `allOn` is the default whenever nothing can be read.
public struct NativeKillSwitches: Equatable, Sendable {
    public let switchedOff: [NativeFeature: NativeKillSwitch]

    public static let allOn = NativeKillSwitches(switchedOff: [:])

    public init(switchedOff: [NativeFeature: NativeKillSwitch]) {
        self.switchedOff = switchedOff.filter { $0.value.off }
    }

    public init(off features: Set<NativeFeature>) {
        self.init(switchedOff: Dictionary(uniqueKeysWithValues: features.map { ($0, NativeKillSwitch()) }))
    }

    public func isOff(_ feature: NativeFeature) -> Bool {
        switchedOff[feature] != nil
    }

    public func allows(_ feature: NativeFeature) -> Bool {
        !isOff(feature)
    }

    /// These switches with every feature `other` switches off also off: what a running app may adopt at once,
    /// because stopping a feature before its next start is always safe, while starting one waits for a relaunch.
    public func addingSwitchedOff(from other: NativeKillSwitches) -> NativeKillSwitches {
        NativeKillSwitches(switchedOff: switchedOff.merging(other.switchedOff) { current, _ in current })
    }
}

/// The `data` of `GET /api/v1/native/config`. Entries for unknown features, or that cannot be read, are skipped, so a
/// newer server never breaks an older app.
public struct NativeConfigResponse: Decodable, Equatable, Sendable {
    public let killSwitches: NativeKillSwitches

    private enum CodingKeys: String, CodingKey {
        case killSwitches
    }

    /// One entry that never fails to decode: an entry the app cannot read is nil and skipped.
    private struct LenientEntry: Decodable {
        let killSwitch: NativeKillSwitch?

        init(from decoder: any Decoder) {
            killSwitch = try? NativeKillSwitch(from: decoder)
        }
    }

    public init(killSwitches: NativeKillSwitches) {
        self.killSwitches = killSwitches
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decode([String: LenientEntry].self, forKey: .killSwitches)
        var switchedOff: [NativeFeature: NativeKillSwitch] = [:]
        for (name, entry) in entries {
            if let feature = NativeFeature(rawValue: name), let killSwitch = entry.killSwitch {
                switchedOff[feature] = killSwitch
            }
        }
        killSwitches = NativeKillSwitches(switchedOff: switchedOff)
    }
}

/// Keeps the last switches the server sent, and when, for the next launch to read before anything else runs.
public struct NativeKillSwitchStore: @unchecked Sendable {
    public static let key = "SpoonjoyNativeKillSwitches"
    /// Saved switches older than this are dropped, so a device that cannot reach the server never keeps a feature off for good.
    public static let maxAge: TimeInterval = 7 * 24 * 60 * 60
    private let defaults: UserDefaults

    private struct Saved: Codable {
        let savedAt: Date
        let switches: [String: NativeKillSwitch]
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved switches; everything on when nothing was saved, the saved value cannot be read, or it is older than `maxAge`.
    public func load(now: Date = Date()) -> NativeKillSwitches {
        guard let data = defaults.data(forKey: Self.key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              now.timeIntervalSince(saved.savedAt) <= Self.maxAge else {
            return .allOn
        }
        var switchedOff: [NativeFeature: NativeKillSwitch] = [:]
        for (name, killSwitch) in saved.switches {
            if let feature = NativeFeature(rawValue: name) {
                switchedOff[feature] = killSwitch
            }
        }
        return NativeKillSwitches(switchedOff: switchedOff)
    }

    public func save(_ killSwitches: NativeKillSwitches, at savedAt: Date = Date()) {
        let switches = Dictionary(uniqueKeysWithValues: killSwitches.switchedOff.map { ($0.key.rawValue, $0.value) })
        // Encoding a date and a dictionary of strings and optional strings cannot fail.
        defaults.set(try? JSONEncoder().encode(Saved(savedAt: savedAt, switches: switches)), forKey: Self.key)
    }
}

/// Reads `GET /api/v1/native/config` without credentials, so an expired session never hides a switch.
public enum NativeConfigRequests {
    /// The whole read's deadline, connection to decoded answer. Short, because the app never waits for it.
    public static let timeout: TimeInterval = 5

    public static func urlRequest(baseURL: URL) -> URLRequest {
        var request = URLRequest(
            url: baseURL.appending(path: "api/v1/native/config"),
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: timeout
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// The server's switches; throws on any failure, or when the read takes longer than `deadline` in all, so the
    /// caller keeps what it had. (`URLRequest.timeoutInterval` alone only limits the wait between bytes.)
    public static func fetch(
        baseURL: URL,
        session: any URLSessionPerforming = URLSession.shared,
        deadline: Duration = .seconds(timeout)
    ) async throws -> NativeKillSwitches {
        let request = urlRequest(baseURL: baseURL)
        return try await withThrowingTaskGroup(of: NativeKillSwitches.self) { group in
            group.addTask {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return try APIEnvelope<NativeConfigResponse>.decode(data).data.killSwitches
            }
            group.addTask {
                try await Task.sleep(for: deadline)
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            // The first child to finish wins; a group with children always has a next result.
            guard let first = try await group.next() else {
                throw URLError(.timedOut)
            }
            return first
        }
    }
}

/// The switches this process runs with.
///
/// At launch it reads the saved switches synchronously, with no network, so launch never waits. The app then
/// refreshes them in the background at launch and whenever it comes to the foreground, at most once every
/// `refreshInterval`, and saves them for the next launch (Firebase Remote Config's "activate on next launch"). A
/// feature the server switches off is also off for the rest of this run from the next time it starts; a feature
/// switched back on stays off until the next launch, so a feature never starts part-way through a run that began
/// without it.
public final class NativeKillSwitchCenter: @unchecked Sendable {
    public typealias Fetch = @Sendable () async throws -> NativeKillSwitches

    /// The shortest time between two background refreshes.
    public static let defaultRefreshInterval: TimeInterval = 15 * 60

    private let lock = NSLock()
    private var active: NativeKillSwitches
    private var lastRefreshStartedAt: Date?
    private let store: NativeKillSwitchStore
    private let refreshInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let fetch: Fetch

    public init(
        store: NativeKillSwitchStore,
        refreshInterval: TimeInterval = NativeKillSwitchCenter.defaultRefreshInterval,
        now: @escaping @Sendable () -> Date = { Date() },
        fetch: @escaping Fetch
    ) {
        self.store = store
        self.refreshInterval = refreshInterval
        self.now = now
        self.fetch = fetch
        active = store.load(now: now())
    }

    /// The switches in force now.
    public var current: NativeKillSwitches {
        lock.withLock { active }
    }

    public func isOff(_ feature: NativeFeature) -> Bool {
        current.isOff(feature)
    }

    /// Fetches and saves the server's switches; returns them, or nil when they could not be read (nothing changes then).
    @discardableResult
    public func refresh() async -> NativeKillSwitches? {
        guard let fetched = try? await fetch() else {
            return nil
        }
        store.save(fetched, at: now())
        lock.withLock { active = active.addingSwitchedOff(from: fetched) }
        return fetched
    }

    /// Starts a background refresh unless one started less than `refreshInterval` ago; then it returns nil. Called at
    /// launch and each time the app comes to the foreground. Nothing awaits it.
    @discardableResult
    public func refreshInBackgroundIfDue() -> Task<Void, Never>? {
        lock.withLock {
            let startedAt = now()
            // A clock set back counts as due, so a wrong clock never stops refreshes.
            if let lastRefreshStartedAt, (0..<refreshInterval).contains(startedAt.timeIntervalSince(lastRefreshStartedAt)) {
                return nil
            }
            lastRefreshStartedAt = startedAt
            let task = Task.detached(priority: .utility) { [self] in
                _ = await refresh()
            }
            return task
        }
    }
}
