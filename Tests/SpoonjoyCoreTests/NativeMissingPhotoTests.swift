import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("A queued photo that is gone from the device holds only its own edit")
struct NativeMissingPhotoTests {
    private static let configuration = APIClientConfiguration.spoonjoyProduction
    private static let now = Date(timeIntervalSince1970: 1_781_600_000)
    private static let scope = NativeSyncExecutionScope(expectedAccountID: "chef_ari", environment: .production)

    @Test("the edit whose photo is gone becomes a conflict to discard, and the other edits still sync")
    func missingPhotoBecomesConflict() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("missing-photo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let media = NativeStagedMediaDirectory(directoryURL: directory.appendingPathComponent("media", isDirectory: true))
        // The photo was staged with the edit and later removed from disk.
        let photo = NativeStagedMediaUpload(localStageID: "stage_gone", fileName: "me.jpg", contentType: "image/jpeg", data: Data([1, 2, 3]))
        let photoEdit = NativeQueuedMutation.profilePhotoUpload(photo: photo, clientMutationID: "cm_photo", createdAt: "2026-10-09T08:00:00.000Z")
        let otherEdit = NativeQueuedMutation.shoppingAddItem(name: "milk", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: "cm_milk", createdAt: "2026-10-09T08:00:01.000Z")
        let fileURL = directory.appendingPathComponent("sync.json")
        try JSONFileStore<NativeSyncSnapshot>(fileURL: fileURL).save(NativeSyncSnapshot(
            accountID: "chef_ari",
            environment: .production,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [photoEdit, otherEdit])
        ))

        let store = try FileBackedNativeSyncStore(fileURL: fileURL, mediaResolver: media)
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_photo", "cm_milk"])
        // New edits can still be queued.
        let later = NativeQueuedMutation.shoppingAddItem(name: "eggs", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: "cm_eggs", createdAt: "2026-10-09T08:00:02.000Z")
        try await store.appendMutations([later], accountID: "chef_ari", environment: .production)

        let transport = PhotoRecordingTransport()
        let report = try await NativeSyncEngine(store: store, transport: transport, clock: { Self.now }).bootstrapAndDrain(
            configuration: Self.configuration,
            trigger: .launch,
            scope: Self.scope
        )

        #expect(await transport.sentClientMutationIDs() == ["cm_milk", "cm_eggs"])
        #expect(report.conflicts.map(\.clientMutationID) == ["cm_photo"])
        #expect(report.conflicts.first?.message == NativeQueuedMutation.missingStagedPhotoMessage)
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_photo"])

        // Discard clears it.
        try await store.removeMutations(clientMutationIDs: ["cm_photo"], accountID: "chef_ari", environment: .production)
        #expect(try await store.loadQueue().mutations.isEmpty)
    }

    @Test("a photo still on disk is read when the edit is sent")
    func presentPhotoIsResolved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("present-photo-\(UUID().uuidString)", isDirectory: true)
        let media = NativeStagedMediaDirectory(directoryURL: directory)
        let photo = NativeStagedMediaUpload(localStageID: "stage_here", fileName: "me.jpg", contentType: "image/jpeg", data: Data([4, 5, 6]))
        try media.save(photo)
        let stored = NativeQueuedMutation.profilePhotoUpload(
            photo: NativeStagedMediaUpload(localStageID: "stage_here", fileName: "me.jpg", contentType: "image/jpeg", byteCount: 3),
            clientMutationID: "cm_photo",
            createdAt: "2026-10-09T08:00:00.000Z"
        )
        #expect(stored.missingStagedMediaStageIDs == ["stage_here"])
        let resolved = try stored.resolvingStagedMedia(using: media)
        #expect(resolved.missingStagedMediaStageIDs.isEmpty)
        #expect(resolved.stagedMediaUploadByteCount == 3)
    }
}

private actor PhotoRecordingTransport: NativeSyncTransport {
    private var sent: [String] = []

    func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        .success(cursor: nil, tombstones: [])
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        sent.append(mutation.clientMutationID)
        return .success(serverRevision: nil)
    }

    func sentClientMutationIDs() -> [String] {
        sent
    }
}
