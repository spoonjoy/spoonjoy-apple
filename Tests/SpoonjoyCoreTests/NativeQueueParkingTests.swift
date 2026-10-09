import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Pending edits survive signing in again and switching accounts")
struct NativeQueueParkingTests {
    private static let configuration = APIClientConfiguration.spoonjoyProduction
    private static let now = Date(timeIntervalSince1970: 1_781_600_000)

    @Test("signing in again as the same account sends the edits that were waiting")
    func signingInAgainSendsWaitingEdits() async throws {
        let waiting = Self.edit("cm_waiting_milk")
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .production,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [waiting])
        )
        let transport = AccountSyncTransport(accountID: "chef_ari")
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { Self.now })

        // A fresh sign-in has no account id until this first sync names it.
        let report = try await engine.bootstrapAndDrain(
            configuration: Self.configuration,
            trigger: .launch,
            scope: NativeSyncExecutionScope(expectedAccountID: nil, environment: .production)
        )

        #expect(await transport.sentClientMutationIDs() == ["cm_waiting_milk"])
        #expect(report.drainedClientMutationIDs == ["cm_waiting_milk"])
        #expect(try await store.loadQueue().mutations.isEmpty)
    }

    @Test("an edit made before the account is known keeps the stored queue and cache, then goes to the account the sync confirms")
    func editBeforeAccountIsKnownJoinsConfirmedAccount() async throws {
        let waiting = Self.edit("cm_waiting_milk")
        let cached = NativeSyncCachedRecord(kind: .profile, resourceID: "chef_ari", payload: .object(["username": .string("ari")]), serverRevision: .updatedAt("2026-10-09T07:00:00.000Z"))
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .production,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [waiting]),
            cachedRecords: [cached]
        )

        let early = Self.edit("cm_early_eggs")
        let dropped = Self.edit("cm_early_dropped")
        let queued = try await store.appendMutations([early, dropped], accountID: nil, environment: .production)
        let afterRemove = try await store.removeMutations(clientMutationIDs: ["cm_early_dropped"], accountID: nil, environment: .production)

        #expect(queued.mutations.map(\.clientMutationID) == ["cm_early_eggs", "cm_early_dropped"])
        #expect(afterRemove.mutations.map(\.clientMutationID) == ["cm_early_eggs"])
        let snapshot = await store.loadSnapshot()
        #expect(snapshot.queue.mutations.map(\.clientMutationID) == ["cm_waiting_milk"])
        #expect(snapshot.cachedRecords == [cached])
        #expect(snapshot.queue(accountID: nil, environment: .production).mutations.map(\.clientMutationID) == ["cm_early_eggs"])
        #expect(snapshot.queue(accountID: nil, environment: .preview).mutations.isEmpty)
        #expect(snapshot.queue(accountID: "chef_someone_else", environment: .production).mutations.isEmpty)

        let transport = AccountSyncTransport(accountID: "chef_ari")
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { Self.now })
        _ = try await engine.bootstrapAndDrain(
            configuration: Self.configuration,
            trigger: .launch,
            scope: NativeSyncExecutionScope(expectedAccountID: nil, environment: .production)
        )

        #expect(await transport.sentClientMutationIDs() == ["cm_waiting_milk", "cm_early_eggs"])
        let drained = await store.loadSnapshot()
        #expect(drained.queue.mutations.isEmpty)
        #expect(drained.parkedQueues.isEmpty)
    }

    @Test("on disk, an edit made before the account is known is kept apart, survives reopening, and goes to the confirmed account")
    func fileStoreKeepsEditsBeforeAccountIsKnown() async throws {
        try await Self.withDirectory { directory in
            let fileURL = directory.appendingPathComponent("sync.json")
            let waiting = Self.edit("cm_waiting_milk")
            let store = try FileBackedNativeSyncStore(
                fileURL: fileURL,
                fallback: NativeSyncSnapshot(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: try NativeMutationQueue(mutations: [waiting]))
            )
            let queued = try await store.appendMutations([Self.edit("cm_early_eggs")], accountID: nil, environment: .production)
            #expect(queued.mutations.map(\.clientMutationID) == ["cm_early_eggs"])
            #expect(try await store.loadQueue().mutations == [waiting])

            let reopened = try FileBackedNativeSyncStore(fileURL: fileURL)
            #expect(try await reopened.loadSnapshot().queue(accountID: nil, environment: .production).mutations.map(\.clientMutationID) == ["cm_early_eggs"])

            let transport = AccountSyncTransport(accountID: "chef_ari")
            _ = try await NativeSyncEngine(store: reopened, transport: transport, clock: { Self.now }).bootstrapAndDrain(
                configuration: Self.configuration,
                trigger: .launch,
                scope: NativeSyncExecutionScope(expectedAccountID: nil, environment: .production)
            )
            #expect(await transport.sentClientMutationIDs() == ["cm_waiting_milk", "cm_early_eggs"])
            #expect(try await reopened.loadSnapshot().parkedQueues.isEmpty)

            // The same account in another environment is another scope: its edits are kept apart too.
            try await reopened.saveQueue(try NativeMutationQueue(mutations: [Self.edit("cm_preview")]), accountID: "chef_ari", environment: .preview)
            let preview = try await reopened.loadSnapshot()
            #expect(preview.environment == .preview)
            #expect(preview.queue.mutations.map(\.clientMutationID) == ["cm_preview"])
        }
    }

    @Test("switching accounts keeps the first account's edits, unsent, until that account signs in again")
    func switchingAccountsParksEditsUntilTheAccountReturns() async throws {
        try await Self.withDirectory { directory in
            let fileURL = directory.appendingPathComponent("sync.json")
            let first = Self.edit("cm_first_account")
            let store = try FileBackedNativeSyncStore(
                fileURL: fileURL,
                fallback: NativeSyncSnapshot(accountID: "chef_first", environment: .production, checkpoint: nil, queue: try NativeMutationQueue(mutations: [first]))
            )

            let second = AccountSyncTransport(accountID: "chef_second")
            _ = try await NativeSyncEngine(store: store, transport: second, clock: { Self.now }).bootstrapAndDrain(
                configuration: Self.configuration,
                trigger: .launch,
                scope: NativeSyncExecutionScope(expectedAccountID: "chef_second", environment: .production)
            )

            #expect(await second.sentClientMutationIDs().isEmpty)
            let switched = try await store.loadSnapshot()
            #expect(switched.accountID == "chef_second")
            #expect(switched.queue.mutations.isEmpty)
            #expect(switched.parkedQueues == [NativeParkedMutationQueue(accountID: "chef_first", environment: .production, queue: try NativeMutationQueue(mutations: [first]))])

            let reopened = try FileBackedNativeSyncStore(fileURL: fileURL)
            #expect(try await reopened.loadSnapshot().parkedQueues == switched.parkedQueues)

            let firstAgain = AccountSyncTransport(accountID: "chef_first")
            _ = try await NativeSyncEngine(store: reopened, transport: firstAgain, clock: { Self.now }).bootstrapAndDrain(
                configuration: Self.configuration,
                trigger: .launch,
                scope: NativeSyncExecutionScope(expectedAccountID: "chef_first", environment: .production)
            )

            #expect(await firstAgain.sentClientMutationIDs() == ["cm_first_account"])
            let returned = try await reopened.loadSnapshot()
            #expect(returned.queue.mutations.isEmpty)
            #expect(returned.parkedQueues.isEmpty)
        }
    }

    @Test("saving a queue for another account keeps that account's parked edits, and the saved copy of an edit wins")
    func scopedSaveKeepsParkedEdits() async throws {
        let parked = Self.edit("cm_parked", name: "parked copy")
        let alsoParked = Self.edit("cm_also_parked")
        let saved = Self.edit("cm_parked", name: "saved copy")
        let current = Self.edit("cm_current")

        let memory = InMemoryNativeSyncStore(accountID: "chef_first", environment: .production, checkpoint: nil, queue: try NativeMutationQueue(mutations: [parked, alsoParked]))
        await memory.saveQueue(try NativeMutationQueue(mutations: [current]), accountID: "chef_second", environment: .production)
        await memory.saveQueue(try NativeMutationQueue(mutations: [saved]), accountID: "chef_first", environment: .production)
        let memorySnapshot = await memory.loadSnapshot()
        #expect(memorySnapshot.queue.mutations == [alsoParked, saved])
        #expect(memorySnapshot.parkedQueues == [NativeParkedMutationQueue(accountID: "chef_second", environment: .production, queue: try NativeMutationQueue(mutations: [current]))])

        try await Self.withDirectory { directory in
            let file = try FileBackedNativeSyncStore(
                fileURL: directory.appendingPathComponent("sync.json"),
                fallback: NativeSyncSnapshot(accountID: "chef_first", environment: .production, checkpoint: nil, queue: try NativeMutationQueue(mutations: [parked, alsoParked]))
            )
            try await file.saveQueue(try NativeMutationQueue(mutations: [current]), accountID: "chef_second", environment: .production)
            try await file.saveQueue(try NativeMutationQueue(mutations: [saved]), accountID: "chef_first", environment: .production)
            #expect(try await file.loadSnapshot().queue.mutations == [alsoParked, saved])
        }
    }

    @Test("parked edits for one account collect in one place, and a store from before account scoping keeps nothing")
    func parkingMergesAndDropsUnscopedQueues() throws {
        let one = Self.edit("cm_one")
        let two = Self.edit("cm_two")
        let parked = NativeMutationQueueParking.parking(
            try NativeMutationQueue(mutations: [two, one]),
            accountID: "chef_ari",
            environment: .production,
            in: [NativeParkedMutationQueue(accountID: "chef_ari", environment: .production, queue: try NativeMutationQueue(mutations: [one]))]
        )
        #expect(parked == [NativeParkedMutationQueue(accountID: "chef_ari", environment: .production, queue: try NativeMutationQueue(mutations: [one, two]))])
        #expect(NativeMutationQueueParking.parking(try NativeMutationQueue(mutations: [one]), accountID: nil, environment: nil, in: []).isEmpty)
    }

    @Test("an edit with neither an account nor an environment, made while the store serves an account, is kept for nobody")
    func editWithNoScopeIsNotParked() async throws {
        let active = Self.edit("cm_active")
        let unscoped = Self.edit("cm_unscoped")

        let memory = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: try NativeMutationQueue(mutations: [active]))
        _ = try await memory.appendMutations([unscoped], accountID: nil, environment: nil)
        let memorySnapshot = await memory.loadSnapshot()
        #expect(memorySnapshot.queue.mutations == [active])
        #expect(memorySnapshot.parkedQueues.isEmpty)

        try await Self.withDirectory { directory in
            let file = try FileBackedNativeSyncStore(
                fileURL: directory.appendingPathComponent("sync.json"),
                fallback: NativeSyncSnapshot(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: try NativeMutationQueue(mutations: [active]))
            )
            _ = try await file.appendMutations([unscoped], accountID: nil, environment: nil)
            let fileSnapshot = try await file.loadSnapshot()
            #expect(fileSnapshot.queue.mutations == [active])
            #expect(fileSnapshot.parkedQueues.isEmpty)
        }
    }

    @Test("store files written before parked edits existed still open")
    func snapshotWithoutParkedQueuesDecodes() throws {
        let snapshot = try JSONDecoder().decode(NativeSyncSnapshot.self, from: Data(#"{"accountID":"chef_ari","environment":"production"}"#.utf8))
        #expect(snapshot.parkedQueues.isEmpty)
        let parked = NativeSyncSnapshot(checkpoint: nil, queue: NativeMutationQueue(), parkedQueues: [
            NativeParkedMutationQueue(accountID: "chef_ari", environment: .production, queue: try NativeMutationQueue(mutations: [Self.edit("cm_one")]))
        ])
        #expect(try JSONDecoder().decode(NativeSyncSnapshot.self, from: JSONEncoder().encode(parked)) == parked)
    }

    private static func edit(_ clientMutationID: String, name: String = "milk") -> NativeQueuedMutation {
        .shoppingAddItem(name: name, quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: clientMutationID, createdAt: "2026-10-09T08:00:00.000Z")
    }

    private static func withDirectory(_ body: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("queue-parking-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try await body(directory)
    }
}

/// Answers the bootstrap as `accountID` and accepts every edit.
private actor AccountSyncTransport: NativeSyncTransport {
    private let accountID: String
    private var sent: [String] = []

    init(accountID: String) {
        self.accountID = accountID
    }

    func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        .syncData(NativeSyncData(
            freshness: NativeSyncFreshness(
                accountID: accountID,
                environment: .production,
                schemaVersion: 1,
                sourceEndpoint: "/api/v1/me/sync",
                generatedAt: "2026-10-09T08:00:00.000Z",
                lastValidatedAt: "2026-10-09T08:00:00.000Z"
            ),
            entries: [],
            nextCursor: PaginationCursor(rawValue: "cursor.\(accountID)"),
            hasMore: false
        ))
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        sent.append(mutation.clientMutationID)
        return .success(serverRevision: nil)
    }

    func sentClientMutationIDs() -> [String] {
        sent
    }
}
