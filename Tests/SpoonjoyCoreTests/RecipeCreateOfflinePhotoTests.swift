import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Recipe created offline with a photo")
struct RecipeCreateOfflinePhotoTests {
    private let now = Date(timeIntervalSince1970: 1_780_010_000)
    private let configuration = APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "sj_access")
    private var scope: NativeSyncExecutionScope { NativeSyncExecutionScope(expectedAccountID: "chef_ari", environment: .local) }

    private static let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAGklEQVR4nGP8z8Dwn4GBgYGJAQYGBgYGABQEAQMC7u1YAAAAAElFTkSuQmCC")!

    private static func photo() -> NativeStagedMediaUpload {
        NativeStagedMediaUpload(localStageID: "recipe-create-photo-test", fileName: "cover.png", contentType: "image/png", data: png)
    }

    private static func create() throws -> NativeQueuedMutation {
        try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_create_offline",
            title: "Offline Toast",
            description: nil,
            servings: nil,
            steps: [RecipeStepDraft(stepNum: 1, stepTitle: nil, description: "Toast it.", duration: nil, ingredients: [], outputStepNums: [])],
            createdAt: "2026-06-16T09:00:00.000Z"
        )
    }

    private static func queued() throws -> [NativeQueuedMutation] {
        RecipeCreateOfflineQueue.mutations(
            create: try create(),
            photo: photo(),
            clientMutationID: "cm_cover_offline",
            createdAt: "2026-06-16T09:00:01.000Z"
        )
    }

    private static let createSuccess = NativeSyncMutationResult.success(serverRevision: nil, idRemaps: [
        NativeSyncIDRemap(localID: "recipe_local_cm_create_offline", serverID: "recipe_server_1"),
        NativeSyncIDRemap(localID: "step_local_cm_create_offline_1", serverID: "step_server_1")
    ])

    @Test("pairs the create with a cover upload addressed to the local recipe id")
    func pairsCreateWithCoverUpload() throws {
        let mutations = try Self.queued()
        #expect(mutations.map(\.queueableKind) == [.recipeCreate, .coverUpload])
        #expect(mutations[1].recipeID == "recipe_local_cm_create_offline")
        #expect(mutations[1].stagedMediaUploadStageIDs == ["recipe-create-photo-test"])
    }

    @Test("anything but a create is queued alone")
    func nonCreateIsQueuedAlone() {
        let update = NativeQueuedMutation.recipeUpdate(recipeID: "r1", clientMutationID: "cm_u", title: "T", description: nil, servings: nil, createdAt: "2026-06-16T09:00:00.000Z")
        let mutations = RecipeCreateOfflineQueue.mutations(create: update, photo: Self.photo(), clientMutationID: "cm_c", createdAt: "2026-06-16T09:00:01.000Z")
        #expect(mutations.map(\.clientMutationID) == ["cm_u"])
    }

    @Test("reconnect sends the create, then the upload to the server's recipe id")
    func reconnectSendsCreateThenUpload() async throws {
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: try NativeMutationQueue(mutations: Self.queued()))
        let transport = PhotoQueueTransport(results: [Self.createSuccess, .success(serverRevision: nil)])
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: scope)

        #expect(report.drainedClientMutationIDs == ["cm_create_offline", "cm_cover_offline"])
        #expect(await transport.paths == ["/api/v1/me/sync", "/api/v1/recipes", "/api/v1/recipes/recipe_server_1/image"])
        #expect(await transport.uploadBodyContainedPhoto)
        #expect(try await store.loadQueue().mutations.isEmpty)
    }

    @Test("the photo survives a relaunch while queued, then uploads and its file is deleted")
    func photoSurvivesRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("recipe-photo-queue-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("sync.json")
        let media = NativeStagedMediaDirectory(directoryURL: directory.appendingPathComponent("media", isDirectory: true))
        let fallback = NativeSyncSnapshot(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: NativeMutationQueue(), cachedRecords: [], tombstones: [])

        // First launch: the app queues both and saves the photo file, then goes away.
        let queued = try Self.queued()
        for mutation in queued { try mutation.saveStagedMedia(to: media) }
        let first = try FileBackedNativeSyncStore(fileURL: storeURL, mediaResolver: media, fallback: fallback)
        try await first.saveQueue(try NativeMutationQueue(mutations: queued))
        let stagedFile = directory.appendingPathComponent("media", isDirectory: true)
        #expect(try FileManager.default.contentsOfDirectory(atPath: stagedFile.path).count == 1)

        // Second launch: a new store reads the queue and the photo from disk.
        let second = try FileBackedNativeSyncStore(fileURL: storeURL, mediaResolver: media)
        let transport = PhotoQueueTransport(results: [Self.createSuccess, .success(serverRevision: nil)])
        let engine = NativeSyncEngine(store: second, transport: transport, clock: { now })
        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .launch, scope: scope)

        #expect(report.drainedClientMutationIDs == ["cm_create_offline", "cm_cover_offline"])
        #expect(await transport.uploadBodyContainedPhoto)
        media.deleteMedia(ofDrained: report.drainedMutations)
        #expect(try FileManager.default.contentsOfDirectory(atPath: stagedFile.path).isEmpty)
    }

    @Test("deleting drained media leaves other kinds' files alone")
    func deleteMediaSkipsOtherKinds() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("recipe-photo-skip-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let media = NativeStagedMediaDirectory(directoryURL: directory)
        let spoon = NativeQueuedMutation.spoonCreatePhoto(recipeID: "r1", photo: Self.photo(), clientMutationID: "cm_s", note: nil, nextTime: nil, cookedAt: nil, useAsRecipeCover: false, createdAt: "2026-06-16T09:00:00.000Z")
        try spoon.saveStagedMedia(to: media)
        media.deleteMedia(ofDrained: [spoon])
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)
    }

    @Test("an upload the server turns down is held with its message, not dropped")
    func uploadFailureSurfacesAsConflict() async throws {
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: try NativeMutationQueue(mutations: Self.queued()))
        let transport = PhotoQueueTransport(results: [
            Self.createSuccess,
            .conflict(kind: .validation, serverRevision: nil, message: "Photo is not a supported image.")
        ])
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: scope)

        #expect(report.drainedClientMutationIDs == ["cm_create_offline"])
        #expect(report.conflicts.map(\.clientMutationID) == ["cm_cover_offline"])
        #expect(report.conflicts.first?.message == "Photo is not a supported image.")
        let remaining = try await store.loadQueue().mutations
        #expect(remaining.map(\.clientMutationID) == ["cm_cover_offline"])
        #expect(remaining.first?.lastError == "Photo is not a supported image.")
        #expect(remaining.first?.recipeID == "recipe_server_1")
    }

    @Test("a create the server turns down holds its photo upload")
    func createFailureHoldsUpload() async throws {
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: try NativeMutationQueue(mutations: Self.queued()))
        let transport = PhotoQueueTransport(results: [.conflict(kind: .validation, serverRevision: nil, message: "Title is required.")])
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: scope)

        #expect(report.drainedClientMutationIDs.isEmpty)
        #expect(await transport.paths == ["/api/v1/me/sync", "/api/v1/recipes"])
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_create_offline", "cm_cover_offline"])
    }

    @Test("the camera is offered only where the device has one")
    func cameraOfferedOnlyWhereAvailable() {
        #expect(RecipePhotoSource.available(cameraAvailable: false) == [.library])
        #expect(RecipePhotoSource.available(cameraAvailable: true) == [.library, .camera])
        let upload = RecipePhotoSource.cameraUpload(jpegData: Data([1, 2, 3]), stageID: "stage_cam")
        #expect(upload.localStageID == "stage_cam")
        #expect(upload.contentType == "image/jpeg")
        #expect(upload.fileName == "cover.jpg")
        #expect(upload.data == Data([1, 2, 3]))
    }
}

private actor PhotoQueueTransport: NativeSyncTransport {
    private var results: [NativeSyncMutationResult]
    private(set) var paths: [String] = []
    private(set) var uploadBodyContainedPhoto = false

    init(results: [NativeSyncMutationResult]) {
        self.results = results
    }

    func bootstrap(request: APIRequest, configuration: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        paths.append(request.url.path)
        return .success(cursor: nil, tombstones: [])
    }

    func send(_ mutation: NativeQueuedMutation, configuration: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        let request = try mutation.requestBuilder().urlRequest(configuration: configuration)
        paths.append(request.url.path)
        if mutation.queueableKind == .coverUpload, let body = request.body, !body.isEmpty {
            uploadBodyContainedPhoto = true
        }
        return results.isEmpty ? .success(serverRevision: nil) : results.removeFirst()
    }
}
