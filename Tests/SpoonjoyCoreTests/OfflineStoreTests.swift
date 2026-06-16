import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Offline store and mutation queue")
struct OfflineStoreTests {
    @Test("JSON file store saves loads deletes and reports file source")
    func jsonFileStoreSavesLoadsDeletesAndReportsFileSource() throws {
        try withTemporaryDirectory { directory in
            let store = JSONFileStore<OfflineSnapshot>(fileURL: directory.appendingPathComponent("snapshot.json"))
            let snapshot = try offlineSnapshot()

            #expect(try store.load() == nil)

            try store.save(snapshot)
            let loaded = try #require(try store.load())
            #expect(loaded.source == .file)
            #expect(loaded.value == snapshot)

            try store.delete()
            #expect(try store.load() == nil)
        }
    }

    @Test("corrupt JSON recovers from fallback without overwriting the corrupt file")
    func corruptJSONRecoversFromFallbackWithoutOverwritingTheCorruptFile() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("snapshot.json")
            try Data("{ nope".utf8).write(to: fileURL)
            let fallback = try offlineSnapshot(capturedAt: "2026-06-16T08:45:00.000Z")
            let fallbackData = try JSONEncoder().encode(fallback)
            let store = JSONFileStore<OfflineSnapshot>(fileURL: fileURL, fallbackData: fallbackData)

            let loaded = try #require(try store.load())

            #expect(loaded.source == .fallbackAfterCorruption)
            #expect(loaded.value == fallback)
            #expect(try String(contentsOf: fileURL, encoding: .utf8) == "{ nope")
        }
    }

    @Test("sync checkpoint persists trimmed durable shopping cursor")
    func syncCheckpointPersistsTrimmedDurableShoppingCursor() throws {
        try withTemporaryDirectory { directory in
            let cursor = try #require(ShoppingSyncCursor(rawValue: " 2026.cursor.before "))
            let checkpoint = try SyncCheckpoint(shoppingCursor: cursor, updatedAt: "2026-06-16T08:46:00.000Z")
            let store = JSONFileStore<SyncCheckpoint>(fileURL: directory.appendingPathComponent("checkpoint.json"))

            try store.save(checkpoint)
            let loaded = try #require(try store.load()?.value)
            let updated = try loaded.updatingShoppingCursor(
                try #require(ShoppingSyncCursor(rawValue: "2026.cursor.after")),
                at: "2026-06-16T08:47:00.000Z"
            )

            #expect(loaded.shoppingCursor == ShoppingSyncCursor(rawValue: "2026.cursor.before"))
            #expect(updated.shoppingCursor == ShoppingSyncCursor(rawValue: "2026.cursor.after"))
            #expect(updated.updatedAt == "2026-06-16T08:47:00.000Z")
            #expect(throws: SyncCheckpointError.self) {
                try SyncCheckpoint(shoppingCursor: nil, updatedAt: " \n ")
            }
        }
    }

    @Test("offline snapshot restores shopping list checkpoint and pending mutations")
    func offlineSnapshotRestoresShoppingListCheckpointAndPendingMutations() throws {
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let checkpoint = try SyncCheckpoint(
            shoppingCursor: try #require(ShoppingSyncCursor(rawValue: shoppingList.nextCursor)),
            updatedAt: shoppingList.updatedAt
        )
        let queue = try MutationQueue().appending(shoppingAddMutation())
        let snapshot = OfflineSnapshot(
            schemaVersion: 1,
            capturedAt: "2026-06-16T08:48:00.000Z",
            shoppingList: shoppingList,
            syncCheckpoint: checkpoint,
            pendingMutations: queue
        )

        let restored = try snapshot.restore()

        #expect(restored.shoppingList == shoppingList)
        #expect(restored.syncCheckpoint == checkpoint)
        #expect(restored.pendingMutations == queue)
        #expect(restored.pendingMutationCount == 1)
        #expect(throws: OfflineSnapshotError.self) {
            try OfflineSnapshot(
                schemaVersion: 1,
                capturedAt: "2026-06-16T08:49:00.000Z",
                shoppingList: nil,
                syncCheckpoint: checkpoint,
                pendingMutations: .init()
            ).restore()
        }
    }

    @Test("mutation queue serializes shopping mutations and rejects duplicates")
    func mutationQueueSerializesShoppingMutationsAndRejectsDuplicates() throws {
        let add = shoppingAddMutation(clientMutationID: "mutation-add-eggs")
        let check = QueuedMutation(
            id: "queued-check-eggs",
            clientMutationID: "mutation-check-eggs",
            createdAt: "2026-06-16T08:50:00.000Z",
            kind: .shoppingCheck(itemID: "item_eggs", checked: true)
        )
        let remove = QueuedMutation(
            id: "queued-delete-eggs",
            clientMutationID: "mutation-delete-eggs",
            createdAt: "2026-06-16T08:51:00.000Z",
            kind: .shoppingDelete(itemID: "item_eggs")
        )
        let queue = try MutationQueue()
            .appending(add)
            .appending(check)
            .appending(remove)
        let data = try JSONEncoder().encode(queue)
        let json = try #require(String(data: data, encoding: .utf8))
        let decoded = try JSONDecoder().decode(MutationQueue.self, from: data)

        #expect(decoded == queue)
        #expect(decoded.mutations.map(\.clientMutationID) == [
            "mutation-add-eggs",
            "mutation-check-eggs",
            "mutation-delete-eggs"
        ])
        #expect(json.contains("shoppingAdd"))
        #expect(json.contains("shoppingCheck"))
        #expect(json.contains("shoppingDelete"))
        #expect(queue.removing(clientMutationID: "mutation-check-eggs").mutations.map(\.clientMutationID) == [
            "mutation-add-eggs",
            "mutation-delete-eggs"
        ])
        #expect(throws: MutationQueueError.self) {
            try queue.appending(shoppingAddMutation(clientMutationID: "mutation-add-eggs"))
        }
    }

    private func offlineSnapshot(capturedAt: String = "2026-06-16T08:44:00.000Z") throws -> OfflineSnapshot {
        let shoppingList = try ShoppingListState.decodeFromBundle()
        return OfflineSnapshot(
            schemaVersion: 1,
            capturedAt: capturedAt,
            shoppingList: shoppingList,
            syncCheckpoint: try SyncCheckpoint(
                shoppingCursor: try #require(ShoppingSyncCursor(rawValue: shoppingList.nextCursor)),
                updatedAt: shoppingList.updatedAt
            ),
            pendingMutations: try MutationQueue().appending(shoppingAddMutation())
        )
    }

    private func shoppingAddMutation(clientMutationID: String = "mutation-add-eggs") -> QueuedMutation {
        QueuedMutation(
            id: "queued-add-eggs",
            clientMutationID: clientMutationID,
            createdAt: "2026-06-16T08:49:00.000Z",
            kind: .shoppingAdd(
                name: "eggs",
                quantity: 12,
                unit: "each",
                categoryKey: "dairy",
                iconKey: "egg"
            )
        )
    }

    private func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-offline-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        return try body(directory)
    }
}
