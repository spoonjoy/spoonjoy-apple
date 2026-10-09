import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cook session sync")
struct CookSessionSyncTests {
    private static func progress(
        step: Int = 0,
        scale: Double = 1,
        ingredients: [String] = [],
        outputs: [String] = []
    ) -> CookSyncProgress {
        CookSyncProgress(
            activeStepIndex: step,
            scaleFactor: scale,
            checkedIngredientIDs: ingredients,
            checkedStepOutputIDs: outputs
        )
    }

    private static func server(
        attempt: String = "attempt-1",
        revision: Int = 0,
        _ progress: CookSyncProgress = .initial
    ) -> CookServerSnapshot {
        CookServerSnapshot(attemptID: attempt, revision: revision, progress: progress)
    }

    private static let bounds = CookSyncBounds(
        stepCount: 3,
        ingredientIDs: ["a", "b", "c"],
        stepOutputIDs: ["o1", "o2"]
    )

    // MARK: Merge rules

    @Test("progress is the same regardless of id order")
    func sameProgress() {
        #expect(Self.progress(ingredients: ["a", "b"]).isSame(as: Self.progress(ingredients: ["b", "a"])))
        #expect(!Self.progress(step: 1).isSame(as: .initial))
        #expect(!Self.progress(scale: 2).isSame(as: .initial))
        #expect(!Self.progress(ingredients: ["a"]).isSame(as: .initial))
        #expect(!Self.progress(outputs: ["o1"]).isSame(as: .initial))
    }

    @Test("normalizing clamps the step and scale and drops ids the recipe does not have")
    func normalizing() {
        let normalized = Self.progress(step: 9, scale: 99, ingredients: ["a", "a", "zzz"], outputs: ["o2", "x"])
            .normalized(to: Self.bounds)
        #expect(normalized == Self.progress(step: 2, scale: 50, ingredients: ["a"], outputs: ["o2"]))
        #expect(Self.progress(step: -4, scale: 0.01).normalized(to: Self.bounds) == Self.progress(step: 0, scale: 0.25))
        #expect(Self.progress(scale: .nan).normalized(to: Self.bounds).scaleFactor == 1)
        #expect(Self.progress(scale: 1.234).normalized(to: Self.bounds).scaleFactor == 1.23)
        let empty = CookSyncBounds(stepCount: 0, ingredientIDs: [], stepOutputIDs: [])
        #expect(Self.progress(step: 3).normalized(to: empty).activeStepIndex == 0)
    }

    @Test("a changed step or scale wins over the server's, otherwise the server's stands")
    func mergeStepAndScale() {
        let base = Self.progress(step: 1, scale: 1)
        let remote = Self.progress(step: 2, scale: 3)
        #expect(CookSyncProgress.merge(base: base, local: Self.progress(step: 0, scale: 1), remote: remote).activeStepIndex == 0)
        #expect(CookSyncProgress.merge(base: base, local: Self.progress(step: 1, scale: 2), remote: remote).scaleFactor == 2)
        let untouched = CookSyncProgress.merge(base: base, local: base, remote: remote)
        #expect(untouched.activeStepIndex == 2)
        #expect(untouched.scaleFactor == 3)
    }

    @Test("two devices checking different ingredients both keep their checks")
    func mergeChecks() {
        let merged = CookSyncProgress.merge(
            base: Self.progress(ingredients: ["a"], outputs: ["o1"]),
            local: Self.progress(ingredients: ["a", "b"], outputs: []),
            remote: Self.progress(ingredients: ["a", "c"], outputs: ["o1", "o2"])
        )
        #expect(merged.checkedIngredientIDs == ["a", "c", "b"])
        #expect(merged.checkedStepOutputIDs == ["o2"])
    }

    @Test("an uncheck here removes the check the server still has, and a check both sides made is kept once")
    func mergeUncheckAndDuplicates() {
        let merged = CookSyncProgress.merge(
            base: Self.progress(ingredients: ["a", "b"]),
            local: Self.progress(ingredients: ["b", "c"]),
            remote: Self.progress(ingredients: ["a", "b", "c"])
        )
        #expect(merged.checkedIngredientIDs == ["b", "c"])
    }

    @Test("changes lists only the fields that differ")
    func changes() {
        let from = Self.progress(step: 0, scale: 1, ingredients: ["a"], outputs: ["o1"])
        #expect(from.changes(to: from).isEmpty)
        let all = from.changes(to: Self.progress(step: 2, scale: 2, ingredients: ["b"], outputs: []))
        #expect(all.activeStepIndex == 2)
        #expect(all.scaleFactor == 2)
        #expect(all.checkedIngredientIDs == ["b"])
        #expect(all.checkedStepOutputIDs == [])
        #expect(!all.isEmpty)
        let json = all.jsonObject
        #expect(Set(json.keys) == ["activeStepIndex", "scaleFactor", "checkedIngredientIds", "checkedStepOutputIds"])
        #expect(from.changes(to: Self.progress(step: 1, ingredients: ["a"], outputs: ["o1"])).jsonObject.keys.sorted() == ["activeStepIndex"])
    }

    @Test("progress and server state use the server's field names")
    func wireNames() throws {
        let data = Data("""
        {"attemptId":"attempt-9","revision":4,"version":1,"progress":{"activeStepIndex":1,"scaleFactor":2,"checkedIngredientIds":["a"],"checkedStepOutputIds":["o1"]}}
        """.utf8)
        let decoded = try JSONDecoder().decode(CookServerSnapshot.self, from: data)
        #expect(decoded == Self.server(attempt: "attempt-9", revision: 4, Self.progress(step: 1, scale: 2, ingredients: ["a"], outputs: ["o1"])))
        let roundTrip = try JSONDecoder().decode(CookServerSnapshot.self, from: JSONEncoder().encode(decoded))
        #expect(roundTrip == decoded)
    }

    // MARK: Requests

    @Test("requests go to the cook-session endpoints with a bearer token and the site origin, and no cook-user header")
    func requests() throws {
        let configuration = APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "sj_token")
        let read = try CookSessionRequests.read(recipeID: "r 1").urlRequest(configuration: configuration)
        #expect(read.method == .get)
        #expect(read.url.path == "/api/cook-sessions/r%201")
        #expect(read.headers["Authorization"] == "Bearer sj_token")
        #expect(read.headers["X-Spoonjoy-Cook-User"] == nil)

        let start = try CookSessionRequests.start(recipeID: "r1", origin: "https://spoonjoy.app").urlRequest(configuration: configuration)
        #expect(start.method == .post)
        #expect(start.url.path == "/api/cook-sessions/r1/start")
        #expect(start.headers["Origin"] == "https://spoonjoy.app")
        #expect(start.headers["Authorization"] == "Bearer sj_token")
        #expect(start.body == nil)

        let patch = try CookSessionRequests.patch(
            recipeID: "r1",
            server: Self.server(attempt: "attempt-1", revision: 3),
            changes: CookSyncChanges(activeStepIndex: 2),
            mutationID: "m1",
            origin: "https://spoonjoy.app"
        ).urlRequest(configuration: configuration)
        #expect(patch.method == .patch)
        #expect(patch.url.path == "/api/cook-sessions/r1")
        #expect(patch.headers["Origin"] == "https://spoonjoy.app")
        #expect(patch.headers["Content-Type"] == "application/json")
        #expect(patch.headers["X-Spoonjoy-Cook-User"] == nil)
        let bodyData = try #require(patch.body)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(Set(body.keys) == ["attemptId", "expectedRevision", "mutationId", "changes"])
        #expect(body["attemptId"] as? String == "attempt-1")
        #expect(body["expectedRevision"] as? Int == 3)
        #expect(body["mutationId"] as? String == "m1")
        #expect((body["changes"] as? [String: Any])?["activeStepIndex"] as? Int == 2)
    }

    @Test("the origin is the scheme, host and any port of the base URL")
    func origin() {
        #expect(CookSessionRequests.origin(for: URL(string: "https://spoonjoy.app/some/path")!) == "https://spoonjoy.app")
        #expect(CookSessionRequests.origin(for: URL(string: "http://127.0.0.1:8787")!) == "http://127.0.0.1:8787")
        #expect(CookSessionRequests.origin(for: URL(string: "/relative")!) == "https://")
    }

    // MARK: Client

    private static func client(
        _ session: ScriptedCookURLSession,
        baseURL: String = "https://spoonjoy.app"
    ) -> URLSessionCookSessionClient {
        URLSessionCookSessionClient(
            session: session,
            configuration: APIClientConfiguration(baseURL: URL(string: baseURL)!, bearerToken: "sj_token")
        )
    }

    private static let stateBody = """
    {"state":{"version":1,"recipeId":"r1","attemptId":"attempt-1","status":"active","revision":2,"progress":{"activeStepIndex":1,"scaleFactor":1,"checkedIngredientIds":["a"],"checkedStepOutputIds":[]}}}
    """

    @Test("the client sends each operation and reads the session state")
    func clientOperations() async throws {
        let session = ScriptedCookURLSession(responses: [
            .json(200, Self.stateBody),
            .json(201, Self.stateBody),
            .json(200, Self.stateBody),
            .json(200, #"{"state":null}"#)
        ])
        let client = Self.client(session)
        let expected = Self.server(attempt: "attempt-1", revision: 2, Self.progress(step: 1, ingredients: ["a"]))

        #expect(await client.read(recipeID: "r1") == .state(expected))
        #expect(await client.start(recipeID: "r1") == .state(expected))
        #expect(await client.patch(
            recipeID: "r1",
            server: expected,
            changes: CookSyncChanges(scaleFactor: 2),
            mutationID: "m2"
        ) == .state(expected))
        #expect(await client.read(recipeID: "r2") == .state(nil))

        let requests = await session.requests
        #expect(requests.map(\.httpMethod) == ["GET", "POST", "PATCH", "GET"])
        #expect(requests[0].url?.absoluteString == "https://spoonjoy.app/api/cook-sessions/r1")
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer sj_token")
        #expect(requests[1].value(forHTTPHeaderField: "Origin") == "https://spoonjoy.app")
        #expect(requests[2].value(forHTTPHeaderField: "Origin") == "https://spoonjoy.app")
        #expect(requests[2].value(forHTTPHeaderField: "X-Spoonjoy-Cook-User") == nil)
    }

    @Test("the client classifies every answer the docs describe")
    func clientClassification() async {
        let conflict = """
        {"error":{"code":"stale_revision","message":"x","retryable":false,"state":{"version":1,"recipeId":"r1","attemptId":"attempt-2","revision":5,"progress":{"activeStepIndex":0,"scaleFactor":1,"checkedIngredientIds":[],"checkedStepOutputIds":[]}}}}
        """
        let unavailable = #"{"error":{"code":"cook_session_protocol_unavailable","message":"x","retryable":true}}"#
        let cases: [(ScriptedCookURLSession.Response, CookSyncResult)] = [
            (.json(409, conflict), .conflict(Self.server(attempt: "attempt-2", revision: 5))),
            (.json(409, #"{"error":{"code":"stale_revision"}}"#), .stopped),
            (.json(401, #"{"error":{"code":"authentication_required"}}"#), .unauthenticated),
            (.json(403, #"{"error":{"code":"insufficient_scope"}}"#), .stopped),
            (.json(404, #"{"error":{"code":"not_found"}}"#), .missing),
            (.json(400, #"{"error":{"code":"invalid_request"}}"#), .rejected),
            (.json(412, #"{"error":{"code":"user_mismatch"}}"#), .stopped),
            (.json(428, #"{"error":{"code":"user_header_required"}}"#), .stopped),
            (.json(503, unavailable), .stopped),
            (.json(503, #"{"error":{"code":"other"}}"#), .transient(retryAfterSeconds: nil)),
            (.json(500, "not json"), .transient(retryAfterSeconds: nil)),
            (.json(429, "{}", retryAfter: "7"), .transient(retryAfterSeconds: 7)),
            (.json(429, "{}", retryAfter: "soon"), .transient(retryAfterSeconds: nil)),
            (.json(429, "{}", retryAfter: "-1"), .transient(retryAfterSeconds: nil)),
            (.json(200, #"{"state":{"attemptId":1}}"#), .transient(retryAfterSeconds: nil)),
            (.json(200, "[]"), .transient(retryAfterSeconds: nil)),
            (.nonHTTP, .transient(retryAfterSeconds: nil)),
            (.failure(URLError(.notConnectedToInternet)), .transient(retryAfterSeconds: nil))
        ]
        for (response, expected) in cases {
            let client = Self.client(ScriptedCookURLSession(responses: [response]))
            #expect(await client.read(recipeID: "r1") == expected)
        }
    }

    @Test("a base URL that cannot be requested stops sync, and a patch that cannot be encoded is rejected")
    func clientUnrequestable() async {
        let session = ScriptedCookURLSession(responses: [])
        let client = Self.client(session, baseURL: "mailto:chef@spoonjoy.app")
        #expect(await client.read(recipeID: "r1") == .stopped)
        // The default session is the shared URLSession; nothing is sent for a URL that cannot be requested.
        let sharedSession = URLSessionCookSessionClient(
            configuration: APIClientConfiguration(baseURL: URL(string: "mailto:chef@spoonjoy.app")!, bearerToken: nil)
        )
        #expect(await sharedSession.start(recipeID: "r1") == .stopped)
        #expect(await Self.client(session).patch(
            recipeID: "r1",
            server: Self.server(),
            changes: CookSyncChanges(scaleFactor: .nan),
            mutationID: "m"
        ) == .rejected)
        #expect(await session.requests.isEmpty)
    }

    // MARK: Reconciler

    private static func reconcile(
        _ client: ScriptedCookSessionClient,
        local: CookSyncProgress,
        known: CookServerSnapshot? = nil,
        pull: Bool = true
    ) async -> CookSyncReconciliation {
        await CookSessionReconciler(client: client, mutationID: { "mutation" })
            .reconcile(recipeID: "r1", local: local, known: known, pull: pull, bounds: bounds)
    }

    @Test("nothing on the server and nothing here starts nothing")
    func reconcileNothing() async {
        let client = ScriptedCookSessionClient(read: [.state(nil)])
        let result = await Self.reconcile(client, local: .initial)
        #expect(result == CookSyncReconciliation(progress: .initial, server: nil, outcome: .synced))
        #expect(await client.calls == ["read"])
    }

    @Test("progress with no server session starts one and sends the progress")
    func reconcileStartsAndPatches() async {
        let local = Self.progress(step: 1, ingredients: ["a"])
        let started = Self.server(revision: 0)
        let patched = Self.server(revision: 1, local)
        let client = ScriptedCookSessionClient(read: [.state(nil)], start: [.state(started)], patch: [.state(patched)])
        let result = await Self.reconcile(client, local: local)
        #expect(result == CookSyncReconciliation(progress: local, server: patched, outcome: .synced))
        #expect(await client.calls == ["read", "start", "patch"])
        #expect(await client.patches.map(\.changes) == [CookSyncProgress.initial.changes(to: local)])
        #expect(await client.patches.first?.mutationID == "mutation")
        #expect(await client.patches.first?.server == started)
    }

    @Test("a stale revision replays the pending changes on top of the server's newer state")
    func reconcileConflictReplays() async {
        let base = Self.server(revision: 1, Self.progress(ingredients: ["a"]))
        let local = Self.progress(ingredients: ["a", "b"])
        let newer = Self.server(revision: 2, Self.progress(step: 2, ingredients: ["a", "c"]))
        let final = Self.server(revision: 3, Self.progress(step: 2, ingredients: ["a", "c", "b"]))
        let client = ScriptedCookSessionClient(patch: [.conflict(newer), .state(final)])
        let result = await Self.reconcile(client, local: local, known: base, pull: false)
        #expect(result.outcome == .synced)
        #expect(result.server == final)
        #expect(result.progress == final.progress)
        let patches = await client.patches
        #expect(patches.count == 2)
        #expect(patches[0].server == base)
        #expect(patches[0].changes == CookSyncChanges(checkedIngredientIDs: ["a", "b"]))
        // The second send is built from the newer state and carries only what that state lacks.
        #expect(patches[1].server == newer)
        #expect(patches[1].changes == CookSyncChanges(checkedIngredientIDs: ["a", "c", "b"]))
        #expect(await client.calls == ["patch", "patch"])
    }

    @Test("a new attempt on the server is merged against a fresh base")
    func reconcileNewAttempt() async {
        let base = Self.server(attempt: "attempt-1", revision: 4, Self.progress(step: 2, ingredients: ["a"]))
        let local = Self.progress(step: 2, ingredients: ["a", "b"])
        let newAttempt = Self.server(attempt: "attempt-2", revision: 0)
        let final = Self.server(attempt: "attempt-2", revision: 1, Self.progress(step: 2, ingredients: ["a", "b"]))
        let client = ScriptedCookSessionClient(patch: [.conflict(newAttempt), .state(final)])
        let result = await Self.reconcile(client, local: local, known: base, pull: false)
        #expect(result.server == final)
        // Against attempt-2's empty base every local check is a pending change.
        #expect(await client.patches[1].changes == CookSyncChanges(activeStepIndex: 2, checkedIngredientIDs: ["a", "b"]))
    }

    @Test("a session that is gone is started again")
    func reconcileMissingRestarts() async {
        let base = Self.server(revision: 1, Self.progress(step: 1))
        let local = Self.progress(step: 2)
        let restarted = Self.server(attempt: "attempt-2", revision: 0)
        let final = Self.server(attempt: "attempt-2", revision: 1, local)
        let client = ScriptedCookSessionClient(start: [.state(restarted)], patch: [.missing, .state(final)])
        let result = await Self.reconcile(client, local: local, known: base, pull: false)
        #expect(result == CookSyncReconciliation(progress: local, server: final, outcome: .synced))
        #expect(await client.calls == ["patch", "start", "patch"])
    }

    @Test("a server that already has this device's progress needs no send")
    func reconcileAlreadySynced() async {
        let state = Self.server(revision: 2, Self.progress(step: 1, ingredients: ["a"]))
        let client = ScriptedCookSessionClient(read: [.state(state)])
        let result = await Self.reconcile(client, local: state.progress, known: state)
        #expect(result == CookSyncReconciliation(progress: state.progress, server: state, outcome: .synced))
        #expect(await client.calls == ["read"])
    }

    @Test("reading brings in progress from another device")
    func reconcilePullsRemoteProgress() async {
        let known = Self.server(revision: 1, Self.progress(ingredients: ["a"]))
        let remote = Self.server(revision: 2, Self.progress(step: 2, ingredients: ["a", "b"]))
        let client = ScriptedCookSessionClient(read: [.state(remote)])
        let result = await Self.reconcile(client, local: known.progress, known: known)
        #expect(result == CookSyncReconciliation(progress: remote.progress, server: remote, outcome: .synced))
    }

    // This used to trim the server's progress to this device's recipe and remember the trimmed copy as the
    // server's state, which made the next exchange send the trim and erase the other device's checks. The server's
    // state is now kept as the server holds it; the app fits it to the recipe only for display.
    @Test("a refused change adopts the server's progress and remembers the server's state as it is")
    func reconcileRejectedAdopts() async {
        let remote = Self.server(revision: 3, Self.progress(step: 9, ingredients: ["a", "a", "gone"]))
        let client = ScriptedCookSessionClient(read: [.state(remote)], patch: [.rejected])
        let result = await Self.reconcile(client, local: Self.progress(step: 1), known: Self.server(revision: 3), pull: false)
        #expect(result.progress == Self.progress(step: 9, ingredients: ["a", "gone"]))
        #expect(result.progress.normalized(to: Self.bounds) == Self.progress(step: 2, ingredients: ["a"]))
        #expect(result.server == remote)
        #expect(result.outcome == .synced)
    }

    @Test("a check made on a newer version of the recipe survives this device's send")
    func reconcileKeepsChecksThisDeviceDoesNotKnow() async {
        // The web added "salt" to the recipe and checked it; this device still has the old recipe and checks "a".
        let known = Self.server(revision: 1, Self.progress(ingredients: []))
        let remote = Self.server(revision: 2, Self.progress(ingredients: ["salt"], outputs: ["o9"]))
        let accepted = Self.server(revision: 3, Self.progress(ingredients: ["salt", "a"], outputs: ["o9"]))
        let client = ScriptedCookSessionClient(read: [.state(remote)], patch: [.state(accepted)])
        let result = await Self.reconcile(client, local: Self.progress(ingredients: ["a"]), known: known)

        #expect(await client.patches.map(\.changes) == [CookSyncChanges(checkedIngredientIDs: ["salt", "a"])])
        #expect(result.server == accepted)
        #expect(result.outcome == .synced)
    }

    @Test("ids and a step this device cannot show are not read as the cook undoing them")
    func reconcileDoesNotUndoWhatThisDeviceCannotShow() async {
        // The server is on step 5 of the newer recipe with "salt" checked. This device has three steps, so it shows
        // step 3 (index 2) and no salt. The cook here checks "b".
        let known = Self.server(revision: 4, Self.progress(step: 5, ingredients: ["salt"]))
        let shown = Self.progress(step: 2, ingredients: ["b"])
        let accepted = Self.server(revision: 5, Self.progress(step: 5, ingredients: ["salt", "b"]))
        let client = ScriptedCookSessionClient(patch: [.state(accepted)])
        let result = await Self.reconcile(client, local: shown, known: known, pull: false)

        #expect(await client.patches.map(\.changes) == [CookSyncChanges(checkedIngredientIDs: ["salt", "b"])])
        #expect(result.server == accepted)

        // Moving to another step here is a real change and is sent, fitted to this device's recipe.
        let moved = ScriptedCookSessionClient(patch: [.state(Self.server(revision: 5, Self.progress(step: 1, ingredients: ["salt"])))])
        _ = await Self.reconcile(moved, local: Self.progress(step: 1), known: known, pull: false)
        #expect(await moved.patches.map(\.changes) == [CookSyncChanges(activeStepIndex: 1)])
    }

    @Test("when the server refuses ids this device kept, the change is sent again fitted to this device's recipe")
    func reconcileRetriesFittedWhenKeptIDsAreRefused() async {
        // The web checked "pepper", then the recipe was edited: pepper removed. The server still holds the pepper
        // check but refuses any list that names it. This device has the edited recipe and checks "a".
        let known = Self.server(revision: 2, Self.progress(step: 7, ingredients: ["pepper"]))
        let accepted = Self.server(revision: 3, Self.progress(step: 2, ingredients: ["a"]))
        let client = ScriptedCookSessionClient(patch: [.rejected, .state(accepted)])
        let result = await Self.reconcile(client, local: Self.progress(step: 2, ingredients: ["a"]), known: known, pull: false)

        #expect(await client.patches.map(\.changes) == [
            CookSyncChanges(checkedIngredientIDs: ["pepper", "a"]),
            CookSyncChanges(activeStepIndex: 2, checkedIngredientIDs: ["a"])
        ])
        #expect(result == CookSyncReconciliation(progress: accepted.progress, server: accepted, outcome: .synced))

        // Refused again, fitted: the device shows the server's progress, as before.
        let refused = ScriptedCookSessionClient(read: [.state(known)], patch: [.rejected, .rejected])
        let adopted = await Self.reconcile(refused, local: Self.progress(step: 2, ingredients: ["a"]), known: known, pull: false)
        #expect(await refused.calls == ["patch", "patch", "read"])
        #expect(adopted.server == known)
    }

    @Test("only this device's own changes are fitted to its recipe")
    func normalizingKeepsWhatTheServerHolds() {
        let server = Self.progress(step: 7, scale: 80, ingredients: ["salt"], outputs: ["o9"])
        let kept = Self.progress(step: 7, scale: 80, ingredients: ["salt", "a", "zzz", "a"], outputs: ["o9", "x"])
            .normalized(to: Self.bounds, keeping: server)
        #expect(kept == Self.progress(step: 7, scale: 80, ingredients: ["salt", "a"], outputs: ["o9"]))
        let changed = Self.progress(step: 9, scale: 99).normalized(to: Self.bounds, keeping: server)
        #expect(changed == Self.progress(step: 2, scale: 50))

        let restored = Self.progress(step: 2, ingredients: ["a"]).restoringUnknown(from: server, bounds: Self.bounds)
        #expect(restored == Self.progress(step: 7, ingredients: ["a", "salt"], outputs: ["o9"]))
        #expect(Self.progress(step: 1).restoringUnknown(from: server, bounds: Self.bounds).activeStepIndex == 1)
        #expect(Self.progress(step: 0).restoringUnknown(from: Self.progress(step: -3), bounds: Self.bounds).activeStepIndex == -3)
        #expect(Self.progress(step: 1, ingredients: ["a"]).restoringUnknown(from: Self.progress(step: 1, ingredients: ["b"]), bounds: Self.bounds) == Self.progress(step: 1, ingredients: ["a"]))
    }

    @Test("a refused change with no session on the server falls back to the defaults")
    func reconcileRejectedWithoutSession() async {
        let client = ScriptedCookSessionClient(read: [.state(nil)], patch: [.rejected])
        let result = await Self.reconcile(client, local: Self.progress(step: 1), known: Self.server(), pull: false)
        #expect(result == CookSyncReconciliation(progress: .initial, server: nil, outcome: .synced))
    }

    @Test("a refused change whose follow-up read fails keeps the device's progress")
    func reconcileRejectedReadFails() async {
        let local = Self.progress(step: 1)
        let known = Self.server()
        let client = ScriptedCookSessionClient(read: [.transient(retryAfterSeconds: nil)], patch: [.rejected])
        let result = await Self.reconcile(client, local: local, known: known, pull: false)
        #expect(result == CookSyncReconciliation(progress: local, server: known, outcome: .retryLater))
    }

    @Test("failures keep the device's progress and say what to do next")
    func reconcileFailures() async {
        let local = Self.progress(step: 1)
        let known = Self.server(revision: 1)
        let cases: [(CookSyncResult, CookSyncOutcome)] = [
            (.transient(retryAfterSeconds: 3), .retryLater),
            (.unauthenticated, .signedOut),
            (.stopped, .off),
            (.missing, .off),
            (.rejected, .off),
            (.conflict(known), .off)
        ]
        for (answer, outcome) in cases {
            // Failing the read.
            let readFails = await Self.reconcile(ScriptedCookSessionClient(read: [answer]), local: local, known: known)
            #expect(readFails == CookSyncReconciliation(progress: local, server: known, outcome: outcome))
            // Failing the start.
            let startFails = await Self.reconcile(
                ScriptedCookSessionClient(read: [.state(nil)], start: [answer]),
                local: local,
                known: known
            )
            #expect(startFails == CookSyncReconciliation(progress: local, server: known, outcome: outcome))
            // Failing the send: answers that have their own handling are covered by the tests above.
            switch answer {
            case .missing, .rejected, .conflict:
                continue
            default:
                let patchFails = await Self.reconcile(
                    ScriptedCookSessionClient(patch: [answer]),
                    local: local,
                    known: known,
                    pull: false
                )
                #expect(patchFails == CookSyncReconciliation(progress: local, server: known, outcome: outcome))
            }
        }
        // A start that answers "no session" cannot be used either.
        let nullStart = await Self.reconcile(
            ScriptedCookSessionClient(read: [.state(nil)], start: [.state(nil)]),
            local: local
        )
        #expect(nullStart == CookSyncReconciliation(progress: local, server: nil, outcome: .off))
    }

    @Test("a server that keeps moving ends the exchange after four rounds")
    func reconcileGivesUpAfterFourRounds() async {
        let known = Self.server(revision: 0)
        let moving = (1...4).map { CookSyncResult.conflict(Self.server(revision: $0)) }
        let client = ScriptedCookSessionClient(patch: moving)
        let result = await Self.reconcile(client, local: Self.progress(step: 1), known: known, pull: false)
        #expect(result == CookSyncReconciliation(progress: Self.progress(step: 1), server: known, outcome: .retryLater))
        #expect(await client.patches.count == CookSessionReconciler.maxRounds)
    }

    @Test("the default mutation id is a fresh lowercase UUID")
    func defaultMutationID() async {
        let client = ScriptedCookSessionClient(patch: [.state(Self.server(revision: 1, Self.progress(step: 1)))])
        _ = await CookSessionReconciler(client: client).reconcile(
            recipeID: "r1",
            local: Self.progress(step: 1),
            known: Self.server(),
            pull: false,
            bounds: Self.bounds
        )
        let id = await client.patches.first?.mutationID ?? ""
        #expect(UUID(uuidString: id) != nil)
        #expect(id == id.lowercased())
    }

    // MARK: Cook mode progress mapping

    @Test("cook mode progress maps onto the server's shape and back, keeping completed steps local")
    func progressMapping() throws {
        let recipe = NativeLiveStoreCookFixtures.recipe
        var progress = CookModeProgress.starting(recipe: recipe, startedAt: "2026-10-05T00:00:00Z")
        progress = try progress.markingStepCompleted("step_1", updatedAt: "t1")
        progress = progress.advancing()
        progress = try progress.togglingIngredient(id: "ing_a", checked: true, updatedAt: "t2")
        #expect(progress.syncProgress == Self.progress(step: 1, ingredients: ["ing_a"]))
        #expect(progress.syncBounds == CookSyncBounds(stepCount: 2, ingredientIDs: ["ing_a", "ing_b"], stepOutputIDs: []))

        let applied = progress.applyingSyncProgress(Self.progress(step: 0, scale: 2, ingredients: ["ing_b"]), updatedAt: "t3")
        #expect(applied.activeStepIndex == 0)
        #expect(applied.scaleFactor == 2)
        #expect(applied.checkedIngredientIDs == ["ing_b"])
        #expect(applied.completedStepIDs == ["step_1"])
        #expect(applied.updatedAt == "t3")
    }

    @Test("app snapshots remember the server state and still open without it")
    func snapshotPersistence() throws {
        let progress = CookModeProgress(recipeID: "r1", stepIDs: ["s1"], startedAt: "t0")
        let base = NativeAppSnapshot.bootstrap(shoppingList: nil, savedAt: "t0")
        let server = Self.server(revision: 2, Self.progress(ingredients: ["a"]))
        let updated = base.updatingCookSync(progress: progress, server: server, recipeID: "r1", savedAt: "t1")
        #expect(updated.cookSessionServerByRecipeID["r1"] == server)
        #expect(updated.cookProgress(for: "r1") == progress)
        let reopened = try JSONDecoder().decode(NativeAppSnapshot.self, from: JSONEncoder().encode(updated))
        #expect(reopened == updated)
        #expect(updated.updatingCookSync(progress: nil, server: nil, recipeID: "r1", savedAt: "t2").cookSessionServerByRecipeID["r1"] == nil)
        // An app snapshot saved before cook sync existed has no server state.
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
        legacy.removeValue(forKey: "cookSessionServerByRecipeID")
        let decoded = try JSONDecoder().decode(NativeAppSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.cookSessionServerByRecipeID.isEmpty)
    }
}

enum NativeLiveStoreCookFixtures {
    static let recipe = Recipe.cookSyncFixture(id: "recipe_cook_sync")
}

actor ScriptedCookURLSession: URLSessionPerforming {
    enum Response {
        case json(Int, String, retryAfter: String? = nil)
        case nonHTTP
        case failure(URLError)
    }

    private var responses: [Response]
    private(set) var requests: [URLRequest] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        switch responses.removeFirst() {
        case .json(let status, let body, let retryAfter):
            var headers = ["Content-Type": "application/json"]
            if let retryAfter {
                headers["Retry-After"] = retryAfter
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            return (Data(body.utf8), response)
        case .nonHTTP:
            return (Data(), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        case .failure(let error):
            throw error
        }
    }
}

actor ScriptedCookSessionClient: CookSessionClient {
    struct Patch: Equatable {
        let server: CookServerSnapshot
        let changes: CookSyncChanges
        let mutationID: String
    }

    private var reads: [CookSyncResult]
    private var starts: [CookSyncResult]
    private var patchResults: [CookSyncResult]
    private(set) var calls: [String] = []
    private(set) var patches: [Patch] = []

    init(read: [CookSyncResult] = [], start: [CookSyncResult] = [], patch: [CookSyncResult] = []) {
        reads = read
        starts = start
        patchResults = patch
    }

    func read(recipeID _: String) async -> CookSyncResult {
        calls.append("read")
        // A call nothing scripted answers stops the exchange; tests assert on `calls` and `patches`.
        return reads.isEmpty ? .stopped : reads.removeFirst()
    }

    func start(recipeID _: String) async -> CookSyncResult {
        calls.append("start")
        // A call nothing scripted answers stops the exchange; tests assert on `calls` and `patches`.
        return starts.isEmpty ? .stopped : starts.removeFirst()
    }

    func patch(recipeID _: String, server: CookServerSnapshot, changes: CookSyncChanges, mutationID: String) async -> CookSyncResult {
        calls.append("patch")
        patches.append(Patch(server: server, changes: changes, mutationID: mutationID))
        // A call nothing scripted answers stops the exchange; tests assert on `calls` and `patches`.
        return patchResults.isEmpty ? .stopped : patchResults.removeFirst()
    }
}

extension Recipe {
    /// A two-step recipe with two ingredients, for cook sync tests.
    static func cookSyncFixture(id: String) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        return Recipe(
            id: id,
            title: "Cook Sync Soup",
            description: "Sync across devices.",
            servings: "2",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "By ari",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: "2026-10-05T00:00:00.000Z",
            updatedAt: "2026-10-05T00:00:00.000Z",
            steps: [
                RecipeStep(
                    id: "step_1",
                    stepNum: 1,
                    stepTitle: "Chop",
                    description: "Chop.",
                    duration: 5,
                    ingredients: [RecipeIngredient(id: "ing_a", name: "onion", quantity: 1, unit: "each")]
                ),
                RecipeStep(
                    id: "step_2",
                    stepNum: 2,
                    stepTitle: "Simmer",
                    description: "Simmer.",
                    duration: 20,
                    ingredients: [RecipeIngredient(id: "ing_b", name: "stock", quantity: 2, unit: "cup")]
                )
            ],
            cookbooks: [],
            recentSpoons: []
        )
    }
}
