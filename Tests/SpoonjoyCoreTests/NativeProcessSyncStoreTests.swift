import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("One sync store per app directory in a process")
struct NativeProcessSyncStoreTests {
    @Test("the app and an intent share one store, so an edit either queues is kept by the other's next save")
    func appAndIntentShareOneStore() async throws {
        let appDirectory = try Self.makeAppDirectory()
        let appStore = NativeProcessSyncStore.shared(appDirectory: appDirectory)
        let intentStore = NativeProcessSyncStore.shared(appDirectory: appDirectory)
        #expect(ObjectIdentifier(appStore) == ObjectIdentifier(intentStore))

        let fromSiri = NativeQueuedMutation.shoppingAddItem(name: "eggs", quantity: 6, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: "cm_siri_eggs", createdAt: "2026-10-09T08:00:00.000Z")
        let fromApp = NativeQueuedMutation.shoppingCheckItem(itemID: "item_milk", checked: true, clientMutationID: "cm_app_milk", createdAt: "2026-10-09T08:00:01.000Z")
        try await intentStore.appendMutations([fromSiri], accountID: "chef_ari", environment: .production)
        try await appStore.appendMutations([fromApp], accountID: "chef_ari", environment: .production)

        #expect(try await intentStore.loadQueue().mutations == [fromSiri, fromApp])
        let reopened = try FileBackedNativeSyncStore(fileURL: appDirectory.appendingPathComponent(NativeProcessSyncStore.syncStoreFileName))
        #expect(try await reopened.loadQueue().mutations == [fromSiri, fromApp])
    }

    @Test("a store file that cannot be opened reports it on use and is opened again once it is readable")
    func unreadableStoreIsNotCached() async throws {
        let appDirectory = try Self.makeAppDirectory()
        let fileURL = appDirectory.appendingPathComponent(NativeProcessSyncStore.syncStoreFileName)
        try Data("not json".utf8).write(to: fileURL)

        let unavailable = NativeProcessSyncStore.shared(appDirectory: appDirectory)
        await #expect(throws: NativeSyncStoreError.self) {
            try await unavailable.loadQueue()
        }

        try FileManager.default.removeItem(at: fileURL)
        let recovered = NativeProcessSyncStore.shared(appDirectory: appDirectory)
        #expect(try await recovered.loadQueue().mutations.isEmpty)
        #expect(ObjectIdentifier(recovered) == ObjectIdentifier(NativeProcessSyncStore.shared(appDirectory: appDirectory)))
    }

    private static func makeAppDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("process-sync-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
