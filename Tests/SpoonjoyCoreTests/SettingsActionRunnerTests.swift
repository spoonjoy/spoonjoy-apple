import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Settings actions: one runner for the app and Ouro Reins")
@MainActor
struct SettingsActionRunnerTests {
    private final class Log {
        var steps: [String] = []
    }

    private static let mutation = NativeQueuedMutation.profileDisplayUpdate(email: "a@b.c", username: "ari", clientMutationID: "cm_1", createdAt: "2026-11-05T00:00:00Z")
    private static let request = APIRequestBuilder(method: .post, pathComponents: ["api", "v1", "thing"], queryItems: [])
    private static let handoff = SettingsSecureHandoff(target: .logout, url: URL(string: "https://spoonjoy.app/logout")!)
    private static let offline = APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)

    private func run(_ plan: SettingsActionPlan, queued: [NativeQueuedMutation] = [], execute: Error? = nil, log: Log) async throws -> SettingsActionOutcome? {
        try await plan.perform(
            queuedMutations: queued,
            queueMutation: { log.steps.append("queue \($0.clientMutationID)") },
            queueMutations: { log.steps.append("drain \($0.map(\.clientMutationID)) \($1)") },
            execute: { request, _ in
                log.steps.append("send \(request.pathComponents.last ?? "")")
                if let execute { throw execute }
                return .chefBlocks([])
            },
            sessionOperation: { log.steps.append("session \($0)") },
            openURL: { log.steps.append("open \($0.absoluteString)") }
        )
    }

    @Test("a queued plan queues, and a fallback behind queued work drains with it")
    func queues() async throws {
        let log = Log()
        #expect(try await run(SettingsActionPlan(queuedMutation: Self.mutation), log: log) == nil)
        #expect(try await run(SettingsActionPlan(remoteRequestBuilder: Self.request, offlineFallbackMutation: Self.mutation), queued: [Self.mutation], log: log) == nil)
        #expect(log.steps == ["queue cm_1", "drain [\"cm_1\"] true"])
    }

    @Test("an online plan sends, changes the session, then opens the hand-off")
    func online() async throws {
        let log = Log()
        let plan = SettingsActionPlan(remoteRequestBuilder: Self.request, secureHandoff: Self.handoff, sessionOperation: .logout)
        #expect(try await run(plan, log: log) == .chefBlocks([]))
        #expect(log.steps == ["send thing", "session logout", "open https://spoonjoy.app/logout"])
        let bare = Log()
        #expect(try await run(SettingsActionPlan(), log: bare) == nil)
        #expect(bare.steps.isEmpty)
    }

    @Test("offline, a fallback is queued; with none, or for another failure, the error stands")
    func offline() async throws {
        let log = Log()
        #expect(try await run(SettingsActionPlan(remoteRequestBuilder: Self.request, offlineFallbackMutation: Self.mutation), execute: Self.offline, log: log) == nil)
        #expect(log.steps == ["send thing", "queue cm_1"])
        await #expect(throws: APITransportError.self) { try await run(SettingsActionPlan(remoteRequestBuilder: Self.request), execute: Self.offline, log: log) }
        await #expect(throws: CocoaError.self) { try await run(SettingsActionPlan(remoteRequestBuilder: Self.request), execute: CocoaError(.fileNoSuchFile), log: log) }
    }

    @Test("the surface turns server-only rows off offline and builds the delete form only for a known account")
    func surfaceRules() {
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        let data = SettingsSurfaceData(
            account: SettingsAccountProfile(id: "chef_ari", email: "ari@example.com", username: "ari", photoURL: nil, hasPassword: true, linkedProviders: [], passkeys: []),
            notifications: nil,
            apiTokens: [],
            oauthConnections: [],
            environment: .production,
            offline: .unavailable,
            source: .live(requestID: "req_settings", validatedAt: now)
        )
        let online = SettingsSurfaceViewModel(data: data, queuedMutations: [], conflicts: [], connectivity: .online, secureHandoffRoutes: .spoonjoyApp, now: { now })
        let offline = SettingsSurfaceViewModel(data: data, queuedMutations: [], conflicts: [], connectivity: .offline, secureHandoffRoutes: .spoonjoyApp, now: { now })
        #expect(!online.onlineOnlyActionsDisabled)
        #expect(offline.onlineOnlyActionsDisabled)
        #expect(online.accountDeletionForm() == AccountDeletionForm(username: "ari", reauthentication: .password))
        let signedOut = SettingsSurfaceViewModel.signedOut(environment: .production, offline: .unavailable, secureHandoffRoutes: .spoonjoyApp)
        #expect(signedOut.accountDeletionForm() == nil)
    }
}
