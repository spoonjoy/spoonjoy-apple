import Foundation
import Testing
@testable import SpoonjoyCore

/// Two sync passes on the one shared store, as when the app is syncing and a Siri or Shortcuts intent sends the edit it
/// just queued (`SpoonjoyIntentStateWriter.syncQueued` builds its own `NativeSyncEngine` on the app's store).
///
/// Found by a `/statechart` model of the drain: with two passes at once, the second pass sent its own stale copy of an
/// edit that still pointed at a new recipe's (or shopping item's) temporary id, and then wrote that copy back over the
/// one the first pass had pointed at the real id.
struct NativeSyncDrainTurnsTests {
    private let now = Date(timeIntervalSince1970: 1_780_010_000)
    private let configuration = APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "sj_access")
    private let scope = NativeSyncExecutionScope(expectedAccountID: "chef_ari", environment: .local)

    @Test("a Siri sync that starts while the app is syncing never sends or keeps a step at the new recipe's temporary id")
    func overlappingPassDoesNotRevertRemappedStep() async throws {
        let earlier = NativeQueuedMutation.shoppingCheckItem(itemID: "item_milk", checked: true, clientMutationID: "cm_milk", createdAt: "2026-06-16T09:00:00.000Z")
        let create = try NativeQueuedMutation.recipeCreate(clientMutationID: "cm_create", title: "Soup", description: nil, servings: nil, steps: [], createdAt: "2026-06-16T09:01:00.000Z")
        let localRecipeID = try #require(create.optimisticRecipeID)
        let rename = NativeQueuedMutation.recipeUpdate(recipeID: localRecipeID, clientMutationID: "cm_rename", title: "Better soup", description: nil, servings: nil, createdAt: "2026-06-16T09:02:00.000Z")
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: try NativeMutationQueue(mutations: [earlier, create, rename]))

        // The app's sync: the milk check is held open; then the recipe is created; then the rename hits a network blip.
        let appTransport = ScriptedGateTransport(script: [
            .init(held: true, result: .success(serverRevision: nil)),
            .init(held: false, result: .success(serverRevision: nil, idRemaps: [NativeSyncIDRemap(localID: localRecipeID, serverID: "recipe_server_soup")])),
            .init(held: false, result: .retry(afterSeconds: 60, message: "offline")),
        ])
        // Siri's sync: anything it sends for the rename is answered as the server answers a rename of a recipe id it
        // has never seen.
        let siriTransport = ScriptedGateTransport(script: [
            .init(held: true, result: .success(serverRevision: nil)),
            .init(held: false, result: .conflict(kind: .validation, serverRevision: nil, message: "Recipe not found")),
        ])
        let app = NativeSyncEngine(store: store, transport: appTransport, clock: { now })
        let siri = NativeSyncEngine(store: store, transport: siriTransport, clock: { now })

        let appPass = Task { [configuration, scope] in try await app.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: scope) }
        await appTransport.waitForHeldSend()
        let siriPass = Task { [configuration, scope] in try await siri.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: scope) }
        // Siri's sync has started: it is either sending from the queue it loaded, or waiting for the app's to finish.
        #expect(await Self.eventually { await siriTransport.hasHeldSend() || NativeSyncDrainTurns.waitingCount(on: store) == 1 })

        await appTransport.release()
        _ = try await appPass.value
        let afterApp = try await store.loadQueue().mutations
        #expect(afterApp.map(\.clientMutationID) == ["cm_rename"])
        #expect(afterApp.first?.recipeID == "recipe_server_soup")

        await siriTransport.release()
        let siriReport = try await siriPass.value

        let siriRenames = await siriTransport.sent().filter { $0.clientMutationID == "cm_rename" }
        #expect(siriRenames.allSatisfy { $0.recipeID == "recipe_server_soup" })
        #expect(siriReport.conflicts.isEmpty)
        let queued = try await store.loadQueue().mutations
        #expect(queued.map(\.clientMutationID) == ["cm_rename"])
        #expect(queued.first?.recipeID == "recipe_server_soup")
        #expect(queued.first?.lastError == "offline")
    }

    @Test("a Siri sync that starts while the app is syncing never drops a check of a shopping item just added")
    func overlappingPassDoesNotDropCheckOfNewShoppingItem() async throws {
        let earlier = NativeQueuedMutation.shoppingCheckItem(itemID: "item_eggs", checked: true, clientMutationID: "cm_eggs", createdAt: "2026-06-16T09:00:00.000Z")
        let add = NativeQueuedMutation.shoppingAddItem(name: "Milk", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: "cm_add", createdAt: "2026-06-16T09:01:00.000Z")
        let check = NativeQueuedMutation.shoppingCheckItem(itemID: "item_local_cm_add", checked: true, clientMutationID: "cm_check", createdAt: "2026-06-16T09:02:00.000Z")
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: try NativeMutationQueue(mutations: [earlier, add, check]))

        // The app's sync: eggs held open; milk is added on the server; then the check hits a network blip.
        let appTransport = ScriptedGateTransport(script: [
            .init(held: true, result: .success(serverRevision: nil)),
            .init(held: false, result: .success(serverRevision: nil, idRemaps: [NativeSyncIDRemap(localID: "item_local_cm_add", serverID: "item_server_milk")])),
            .init(held: false, result: .retry(afterSeconds: 60, message: "offline")),
        ])
        // Siri's sync: a check of an item id the server has never seen is a 404, which the real transport counts as
        // done (`APITransportTests.shoppingItemAlreadyRemovedCountsAsDone`), so it answers success here.
        let siriTransport = ScriptedGateTransport(script: [
            .init(held: true, result: .success(serverRevision: nil)),
            .init(held: false, result: .success(serverRevision: nil)),
        ])
        let app = NativeSyncEngine(store: store, transport: appTransport, clock: { now })
        let siri = NativeSyncEngine(store: store, transport: siriTransport, clock: { now })

        let appPass = Task { [configuration, scope] in try await app.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: scope) }
        await appTransport.waitForHeldSend()
        let siriPass = Task { [configuration, scope] in try await siri.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: scope) }
        #expect(await Self.eventually { await siriTransport.hasHeldSend() || NativeSyncDrainTurns.waitingCount(on: store) == 1 })

        await appTransport.release()
        _ = try await appPass.value
        await siriTransport.release()
        _ = try await siriPass.value

        let sentChecks = await (appTransport.sent() + siriTransport.sent()).filter { $0.clientMutationID == "cm_check" }
        #expect(sentChecks.allSatisfy { $0.dependencyKey == "shopping:item:item_server_milk" })
        let queued = try await store.loadQueue().mutations
        #expect(queued.map(\.clientMutationID) == ["cm_check"])
        #expect(queued.first?.dependencyKey == "shopping:item:item_server_milk")
    }

    @Test("Siri stops waiting for the app's sync at its deadline, and its edit stays queued for the app to send")
    func siriGivesUpWaitingAndLeavesItsEditQueued() async throws {
        let earlier = NativeQueuedMutation.shoppingCheckItem(itemID: "item_eggs", checked: true, clientMutationID: "cm_eggs", createdAt: "2026-06-16T09:00:00.000Z")
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: try NativeMutationQueue(mutations: [earlier]))
        let appTransport = ScriptedGateTransport(script: [.init(held: true, result: .success(serverRevision: nil))])
        let siriTransport = ScriptedGateTransport(script: [])
        let app = NativeSyncEngine(store: store, transport: appTransport, clock: { now })
        let siri = NativeSyncEngine(store: store, transport: siriTransport, clock: { now })

        let appPass = Task { [configuration, scope] in try await app.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: scope) }
        await appTransport.waitForHeldSend()

        let milk = NativeQueuedMutation.shoppingCheckItem(itemID: "item_milk", checked: true, clientMutationID: "cm_siri_milk", createdAt: "2026-06-16T09:01:00.000Z")
        try await store.appendMutations([milk], accountID: "chef_ari", environment: .local)
        // Siri's deadline passes once its sync is waiting for the app's.
        let outcome = await NativeIntentWriteSync.drain(
            clientMutationIDs: ["cm_siri_milk"],
            sleep: { _ in _ = await Self.eventually { NativeSyncDrainTurns.waitingCount(on: store) == 1 } }
        ) { [configuration, scope] in
            try await siri.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: scope)
        }

        #expect(outcome == .pending)
        #expect(await siriTransport.sent().isEmpty)
        #expect(NativeSyncDrainTurns.waitingCount(on: store) == 0)

        await appTransport.release()
        _ = try await appPass.value
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_siri_milk"])

        // The app's next sync sends it.
        let report = try await app.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: scope)
        #expect(report.drainedClientMutationIDs == ["cm_siri_milk"])
        #expect(try await store.loadQueue().mutations.isEmpty)
    }

    @Test("passes on one store run one at a time, in the order they asked, and passes on different stores do not wait")
    func passesTakeTurnsPerStore() async throws {
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: NativeMutationQueue())
        let otherStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: NativeMutationQueue())
        let log = PassLog()
        let firstGate = ScriptedGateTransport(script: [.init(held: true, result: .success(serverRevision: nil))])

        let first = Task {
            try await NativeSyncDrainTurns.run(on: store) {
                await log.record("first starts")
                _ = try await firstGate.send(.shoppingCheckItem(itemID: "item_a", checked: true, clientMutationID: "cm_a", createdAt: "2026-06-16T09:00:00.000Z"), configuration: configuration)
                await log.record("first ends")
            }
        }
        await firstGate.waitForHeldSend()
        let second = Task { try await NativeSyncDrainTurns.run(on: store) { await log.record("second") } }
        #expect(await Self.eventually { NativeSyncDrainTurns.waitingCount(on: store) == 1 })
        let third = Task { try await NativeSyncDrainTurns.run(on: store) { await log.record("third") } }
        #expect(await Self.eventually { NativeSyncDrainTurns.waitingCount(on: store) == 2 })
        try await NativeSyncDrainTurns.run(on: otherStore) { await log.record("other store") }

        await firstGate.release()
        try await first.value
        try await second.value
        try await third.value
        #expect(await log.entries == ["first starts", "other store", "first ends", "second", "third"])
        #expect(NativeSyncDrainTurns.waitingCount(on: store) == 0)
    }

    @Test("a pass that throws still hands the turn to the next one")
    func throwingPassHandsTheTurnOn() async throws {
        struct Boom: Error {}
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: NativeMutationQueue())
        await #expect(throws: Boom.self) {
            try await NativeSyncDrainTurns.run(on: store) { throw Boom() }
        }
        let ran = try await NativeSyncDrainTurns.run(on: store) { true }
        #expect(ran)
    }

    @Test("a pass already cancelled when it asks never takes the turn, and the store stays free for the next pass")
    func cancelledBeforeAskingNeverTakesTheTurn() async throws {
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: NativeMutationQueue())
        let log = PassLog()
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await NativeSyncDrainTurns.run(on: store) { await log.record("cancelled pass") }
        }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(NativeSyncDrainTurns.waitingCount(on: store) == 0)
        let ran = try await NativeSyncDrainTurns.run(on: store) { true }
        #expect(ran)
        #expect(await log.entries.isEmpty)
    }

    /// Polls `condition` for up to five seconds.
    static func eventually(_ condition: @Sendable () async -> Bool) async -> Bool {
        for _ in 0..<5_000 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return await condition()
    }
}

actor PassLog {
    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
    }
}

/// Answers each send from a script. A held step waits until `release()`; after a release, later held steps do not wait.
actor ScriptedGateTransport: NativeSyncTransport {
    struct Step: Sendable {
        let held: Bool
        let result: NativeSyncMutationResult
    }

    private var script: [Step]
    private var sentMutations: [NativeQueuedMutation] = []
    private var heldWaiters: [CheckedContinuation<Void, Never>] = []
    private var gate: CheckedContinuation<Void, Never>?
    private var heldStarted = false
    private var released = false

    init(script: [Step]) {
        self.script = script
    }

    func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        .success(cursor: nil, tombstones: [])
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        sentMutations.append(mutation)
        let step = script.isEmpty ? Step(held: false, result: .success(serverRevision: nil)) : script.removeFirst()
        if step.held, !released {
            heldStarted = true
            heldWaiters.forEach { $0.resume() }
            heldWaiters = []
            await withCheckedContinuation { gate = $0 }
        }
        return step.result
    }

    func hasHeldSend() -> Bool { heldStarted }

    func waitForHeldSend() async {
        if heldStarted { return }
        await withCheckedContinuation { heldWaiters.append($0) }
    }

    func release() {
        released = true
        gate?.resume()
        gate = nil
    }

    func sent() -> [NativeQueuedMutation] { sentMutations }
}
