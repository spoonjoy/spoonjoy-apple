import Foundation
import SpoonjoyCore

/// An API transport that answers from a script instead of the server: each request is "METHOD /path" plus its JSON
/// body, and the script returns the response's `data`. A request the script doesn't answer fails, so a journey can
/// only reach the endpoints it meant to.
public final class SpoonjoyScriptedAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    public typealias Script = @Sendable (_ endpoint: String, _ body: [String: Any]?) throws -> Any?

    private let lock = NSLock()
    private let script: Script
    private var sentRequests: [String] = []

    public init(_ script: @escaping Script) {
        self.script = script
    }

    /// Every endpoint sent so far, "METHOD /path", in order.
    public var sent: [String] {
        lock.withLock { sentRequests }
    }

    public func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let built = try request.urlRequest(configuration: configuration)
        let endpoint = "\(built.method.rawValue) \(built.url.path)"
        lock.withLock { sentRequests.append(endpoint) }
        let body = try built.body.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        guard let data = try script(endpoint, body) else {
            throw FixtureKitchenError.notInFixture(endpoint)
        }
        let envelope: [String: Any] = ["ok": true, "requestId": "req_reins", "data": data]
        return try APIEnvelope<Value>.decode(JSONSerialization.data(withJSONObject: envelope))
    }
}

/// Spoonjoy's report and block endpoints, kept in memory: what a reported or blocked chef looks like to the server.
/// One instance serves every launch of a journey, as the QA server outlives a relaunch.
public final class SpoonjoyReinsModerationServer: @unchecked Sendable {
    private let lock = NSLock()
    private let chefs: [String: BlockedChef]
    private var blockedIDs: [String] = []
    private var reportedTargets: [String] = []

    /// `chefs`: who the server knows, so a block names the chef as the server would.
    public init(chefs: [BlockedChef]) {
        self.chefs = Dictionary(chefs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public var blocked: [String] { lock.withLock { blockedIDs } }
    public var reported: [String] { lock.withLock { reportedTargets } }

    /// The transport the app's settings and moderation requests go through.
    public func transport() -> SpoonjoyScriptedAPITransport {
        SpoonjoyScriptedAPITransport { [self] endpoint, body in try answer(endpoint, body) }
    }

    private func answer(_ endpoint: String, _ body: [String: Any]?) throws -> Any? {
        try lock.withLock {
            switch endpoint {
            case "POST /api/v1/reports":
                let target = "\(body?["targetType"] ?? "")/\(body?["targetId"] ?? "")"
                reportedTargets.append(target)
                return ["report": ["id": "report_\(reportedTargets.count)", "createdAt": Self.stamp]]
            case "GET /api/v1/blocks":
                return ["blocks": try blockedIDs.map(blockJSON)]
            case "POST /api/v1/blocks":
                let id = body?["chefId"] as? String ?? ""
                if !blockedIDs.contains(id) { blockedIDs.append(id) }
                return ["block": try blockJSON(id)]
            case let delete where delete.hasPrefix("DELETE /api/v1/blocks/"):
                let id = String(delete.dropFirst("DELETE /api/v1/blocks/".count))
                blockedIDs.removeAll { $0 == id }
                return ["unblocked": true]
            default:
                return nil
            }
        }
    }

    private func blockJSON(_ chefID: String) throws -> [String: Any] {
        guard let chef = chefs[chefID] else {
            throw FixtureKitchenError.notInFixture("chef \(chefID)")
        }
        return ["chef": ["id": chef.id, "username": chef.username, "displayName": chef.displayName as Any? ?? NSNull(), "photoUrl": NSNull()], "createdAt": Self.stamp]
    }

    static let stamp = "2026-11-05T00:00:00.000Z"
}

/// The device's Reminders, in memory: lists, the reminders in them and the list Spoonjoy remembers. One instance
/// serves every launch of a journey, as Reminders and the app's defaults outlive a relaunch.
public final class SpoonjoyReinsReminders: SpoonjoyRemindersStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var allLists: [ReminderListSummary]
    private var remembered: String?
    private var remindersByList: [String: [ReminderExisting]] = [:]
    /// Whether the person has allowed full access; the first send asks, and the fixture says yes.
    public private(set) var hasFullAccess = false

    public init(lists: [ReminderListSummary] = []) {
        allLists = lists
    }

    /// The reminders in a list, as Reminders shows them.
    public func reminders(in listID: String) -> [ReminderExisting] {
        lock.withLock { remindersByList[listID] ?? [] }
    }

    public func requestAccess() async throws {
        lock.withLock { hasFullAccess = true }
    }

    public func lists() -> [ReminderListSummary] {
        lock.withLock { allLists }
    }

    public var chosenListID: String? {
        get { lock.withLock { remembered } }
        set { lock.withLock { remembered = newValue } }
    }

    public func createList(title: String) throws -> ReminderListSummary {
        lock.withLock {
            let list = ReminderListSummary(id: "list_\(allLists.count + 1)", title: title)
            allLists.append(list)
            return list
        }
    }

    public func existingReminders(listID: String) async throws -> [ReminderExisting] {
        try lock.withLock {
            guard allLists.contains(where: { $0.id == listID }) else { throw SpoonjoyRemindersError.listMissing }
            return remindersByList[listID] ?? []
        }
    }

    public func apply(_ plan: ReminderSyncPlan, listID: String) throws {
        lock.withLock {
            var reminders = remindersByList[listID] ?? []
            for operation in plan.operations {
                switch operation {
                case .create(let title, let notes):
                    reminders.append(ReminderExisting(id: "reminder_\(reminders.count + 1)", title: title, notes: notes, isCompleted: false))
                case .update(let id, let title, let notes, _):
                    if let index = reminders.firstIndex(where: { $0.id == id }) {
                        reminders[index] = ReminderExisting(id: id, title: title, notes: notes, isCompleted: false)
                    }
                case .unchanged:
                    continue
                }
            }
            remindersByList[listID] = reminders
        }
    }
}

/// A sync transport for a `.liveFirst` launch: the server has nothing newer than the cache, and refuses a push, so a
/// journey that needs the online settings surface launches with no network.
public struct SpoonjoyReinsQuietSync: NativeSyncTransport {
    public init() {}

    public func bootstrap(request: APIRequest, configuration: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        .success(cursor: nil, tombstones: [])
    }

    public func send(_ mutation: NativeQueuedMutation, configuration: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        throw FixtureKitchenError.notInFixture("sync push")
    }
}

extension SpoonjoyReinsFixtures {
    /// The fixture kitchen's account as `/api/v1/me/settings` returns it: a password account with no linked providers.
    public static let kitchenAccount = SettingsAccountProfile(
        id: SpoonjoyFixtureKitchen.accountID,
        email: "kitchen@spoonjoy.test",
        username: "kitchen",
        photoURL: nil,
        hasPassword: true,
        linkedProviders: [],
        passkeys: []
    )

    /// Settings' surface fetch answering with `account`, as the server does once a sync finishes.
    public static func settingsSurface(account: SettingsAccountProfile = kitchenAccount, now: @escaping @Sendable () -> Date) -> NativeSettingsSurfaceFetchOperation {
        { _, environment, _, _, _ in
            SettingsSurfaceResult(data: SettingsSurfaceData(
                account: account,
                notifications: nil,
                apiTokens: [],
                oauthConnections: [],
                environment: environment,
                offline: .unavailable,
                source: .live(requestID: "req_reins_settings", validatedAt: now())
            ), persistedRecords: [])
        }
    }

    /// A launch with the online settings surface: live first over a quiet sync, the account's settings, and one vault
    /// for every launch so a sign-out survives a relaunch.
    public static func online(vault: FixtureTokenVault, now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_793_000_000) }) -> SpoonjoyReinsFixtures {
        SpoonjoyReinsFixtures(
            now: now,
            settingsSurfaceFetch: settingsSurface(now: now),
            syncTransport: SpoonjoyReinsQuietSync(),
            bootstrapMode: .liveFirst,
            vault: vault
        )
    }
}
