import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native spoon cook-log surface parity")
struct SpoonCookLogSurfaceTests {
    private static let createdAt = "2026-06-27T16:00:00.000Z"
    fileprivate static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("live spoon cook-log repository fetches public recipe spoons")
    func liveRepositoryFetchesPublicRecipeSpoons() async throws {
        let list = SpoonCookLogListData(
            spoons: [
                Self.spoon(id: "spoon/newer", note: "More lemon next time.")
            ],
            nextCursor: PaginationCursor(rawValue: "spoon.after")!,
            hasMore: true
        )
        let transport = RecordingSpoonCookLogAPITransport(envelope: APIEnvelope(
            requestID: "req_spoon_list",
            data: list
        ))
        let repository = LiveSpoonCookLogRepository(
            transport: transport,
            configuration: Self.configuration
        )

        let result = try await repository.fetchCookLog(
            recipeID: "recipe/lemon",
            cursor: PaginationCursor(rawValue: "spoon.before"),
            limit: 20
        )
        let request = try #require(transport.requests.first)

        #expect(result.spoons == list.spoons)
        #expect(result.nextCursor == PaginationCursor(rawValue: "spoon.after"))
        #expect(result.hasMore)
        #expect(request.method == .get)
        #expect(request.url.path == "/api/v1/recipes/recipe%2Flemon/spoons")
        #expect(request.queryItems == [
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "cursor", value: "spoon.before")
        ])
        #expect(request.headers["Authorization"] == nil)
        #expect(request.responseCachePolicy == .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300))
    }

    @Test("cook-log list data decodes defaults and summary-projected spoons")
    func cookLogListDataDecodesDefaultsAndSummaryProjectedSpoons() throws {
        let spoon = Self.spoon(id: "spoon/projected", note: "Bright.")
        let summary = RecipeDetailSpoonSummary(rows: [
            RecipeDetailSpoonRow(spoon: spoon)
        ])

        let summaryData = SpoonCookLogData(summary: summary)
        #expect(summaryData.spoons == [spoon])
        #expect(summaryData.nextCursor == nil)
        #expect(summaryData.hasMore == false)

        let encodedList = try JSONEncoder().encode(["spoons": [spoon]])
        let decodedList = try JSONDecoder().decode(SpoonCookLogListData.self, from: encodedList)
        #expect(decodedList.spoons == [spoon])
        #expect(decodedList.nextCursor == nil)
        #expect(decodedList.hasMore == false)

        let emptyList = try JSONDecoder().decode(SpoonCookLogListData.self, from: Data("{}".utf8))
        #expect(emptyList.spoons.isEmpty)
        #expect(emptyList.nextCursor == nil)
        #expect(emptyList.hasMore == false)

        let decodedData = try JSONDecoder().decode(SpoonCookLogData.self, from: Data("{}".utf8))
        #expect(decodedData == SpoonCookLogData(spoons: []))
        let pagedList = SpoonCookLogListData(spoons: [spoon], nextCursor: PaginationCursor(rawValue: "spoon.after"), hasMore: true)
        #expect(SpoonCookLogData(list: pagedList).hasMore)
    }

    @Test("cook-log view model exposes ownership empty queued and conflict states")
    func cookLogViewModelExposesOwnershipEmptyQueuedAndConflictStates() throws {
        let queued = [
            NativeQueuedMutation.spoonCreate(
                recipeID: "recipe/lemon",
                clientMutationID: "cm_spoon_note",
                note: "Loved it.",
                nextTime: nil,
                cookedAt: nil,
                photoURL: nil,
                useAsRecipeCover: false,
                createdAt: Self.createdAt
            ),
            NativeQueuedMutation.spoonDelete(
                recipeID: "recipe/other",
                spoonID: "spoon/other",
                clientMutationID: "cm_other_spoon",
                createdAt: Self.createdAt
            )
        ]
        let conflicts = [
            NativeSyncConflict(
                clientMutationID: "cm_spoon_note",
                kind: .validation,
                serverRevision: .updatedAt(Self.createdAt),
                message: "Cook log changed elsewhere."
            )
        ]
        let viewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: [
                Self.spoon(id: "spoon/owned", chefID: "chef_ari", username: "ari", note: "Silky.", nextTime: "More lemon.", photoURL: URL(string: "https://spoonjoy.app/photos/spoons/lemon.jpg")!),
                Self.spoon(id: "spoon/friend", chefID: "chef_jules", username: "jules", note: "Good cold.", cookedAt: nil),
                Self.spoon(id: "spoon/deleted", deletedAt: Self.createdAt)
            ]),
            currentChefID: "chef_ari",
            queuedMutations: queued,
            conflicts: conflicts,
            connectivity: .online,
            now: { Self.createdAt }
        )

        #expect(viewModel.rows.map(\.id) == ["spoon/owned", "spoon/friend"])
        #expect(viewModel.rows[0].isOwnedByCurrentChef)
        #expect(viewModel.rows[0].canEdit)
        #expect(viewModel.rows[0].canDelete)
        #expect(viewModel.rows[0].chefLine == "ari cooked this")
        #expect(viewModel.rows[0].cookedAtLabel == "Jun 27, 2026")
        #expect(viewModel.rows[0].photoURL == URL(string: "https://spoonjoy.app/photos/spoons/lemon.jpg")!)
        #expect(!viewModel.rows[1].canEdit)
        #expect(viewModel.rows[1].cookedAtLabel == "Jun 27, 2026")
        #expect(viewModel.emptyState == nil)
        #expect(viewModel.queuedWorkSummary == "1 cook-log change waiting to sync")
        #expect(viewModel.conflictBanner == SpoonCookLogConflictBanner(
            localClientMutationID: "cm_spoon_note",
            message: "Cook log changed elsewhere.",
            actionTitle: "Discard local cook-log change"
        ))
        #expect(viewModel.offlineIndicator.display == .conflict(recordID: "cm_spoon_note", mutationID: "cm_spoon_note"))

        let offlineEmpty = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        )
        #expect(offlineEmpty.emptyState == SpoonCookLogEmptyState(
            title: "No cooks logged yet",
            message: "Log what changed in the kitchen so the next cook starts smarter.",
            systemImage: "fork.knife"
        ))
        #expect(offlineEmpty.offlineIndicator.display == .offline)
    }

    @Test("cook-log view model enforces staged media policy")
    func cookLogViewModelEnforcesStagedMediaPolicy() throws {
        let policy = NativeMediaStagingPolicy.offlineProductContract
        let queuedPhoto = NativeQueuedMutation.spoonCreatePhoto(
            recipeID: "recipe/lemon",
            photo: NativeStagedMediaUpload(
                localStageID: "stage_spoon_policy",
                fileName: "spoon.webp",
                contentType: "image/webp",
                data: Data([0x01, 0x02, 0x03])
            ),
            clientMutationID: "cm_spoon_policy",
            note: nil,
            nextTime: nil,
            cookedAt: nil,
            useAsRecipeCover: false,
            createdAt: Self.createdAt
        )
        let viewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: [queuedPhoto],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        )

        #expect(viewModel.stagedMediaUsage == SpoonCookLogStagedMediaUsage(byteCount: 3, fileCount: 1))
        #expect(viewModel.evaluateNewPhoto(byteCount: 4) == .accepted)
        #expect(viewModel.evaluateNewPhoto(byteCount: policy.maxIndividualUserSelectedBytes + 1) == .rejected(.individualFileTooLarge(limitBytes: policy.maxIndividualUserSelectedBytes)))

        let draftPhoto = NativeStagedMediaUpload(
            localStageID: "stage_spoon_draft_policy",
            fileName: "draft.webp",
            contentType: "image/webp",
            data: Data([0x04, 0x05])
        )
        let draftMediaUsage = SpoonCookLogStagedMediaUsage(drafts: [
            SpoonCookLogDraftState(
                recipeID: "recipe/lemon",
                note: nil,
                nextTime: nil,
                stagedPhoto: draftPhoto,
                useAsRecipeCover: true,
                updatedAt: Self.createdAt
            )
        ])
        #expect(SpoonCookLogStagedMediaUsage(drafts: [
            SpoonCookLogDraftState(
                recipeID: "recipe/lemon",
                note: "Text-only draft.",
                nextTime: nil,
                stagedPhoto: nil,
                useAsRecipeCover: false,
                updatedAt: Self.createdAt
            )
        ]) == .zero)
        let draftUsageViewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: [queuedPhoto],
            conflicts: [],
            connectivity: .offline,
            draftMediaUsage: draftMediaUsage,
            now: { Self.createdAt }
        )
        #expect(draftUsageViewModel.stagedMediaUsage == SpoonCookLogStagedMediaUsage(byteCount: 5, fileCount: 2))

        let byteCapMutation = try Self.decodedQueuedPhotoMutation(byteCount: policy.maxUnsyncedUserSelectedBytesPerAccount, clientMutationID: "cm_spoon_byte_cap")
        let byteCapViewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: [byteCapMutation],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        )
        #expect(byteCapViewModel.evaluateNewPhoto(byteCount: 1) == .rejected(.accountByteCapReached(limitBytes: policy.maxUnsyncedUserSelectedBytesPerAccount, silentEvictionAllowed: false)))

        let fullDraftPhoto = NativeStagedMediaUpload(
            localStageID: "stage_spoon_draft_full",
            fileName: "draft-full.webp",
            contentType: "image/webp",
            byteCount: policy.maxUnsyncedUserSelectedBytesPerAccount
        )
        let draftCapViewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            draftMediaUsage: SpoonCookLogStagedMediaUsage(drafts: [
                SpoonCookLogDraftState(
                    recipeID: "recipe/lemon",
                    note: nil,
                    nextTime: nil,
                    stagedPhoto: fullDraftPhoto,
                    useAsRecipeCover: false,
                    updatedAt: Self.createdAt
                )
            ]),
            now: { Self.createdAt }
        )
        let replacingFullDraft = SpoonCookLogPhotoAttachment(
            localStageID: fullDraftPhoto.localStageID,
            fileName: fullDraftPhoto.fileName,
            contentType: fullDraftPhoto.contentType,
            data: Data(),
            byteCount: fullDraftPhoto.byteCount
        )
        #expect(draftCapViewModel.evaluateNewPhoto(byteCount: 1) == .rejected(.accountByteCapReached(limitBytes: policy.maxUnsyncedUserSelectedBytesPerAccount, silentEvictionAllowed: false)))
        #expect(draftCapViewModel.evaluateNewPhoto(byteCount: 1, replacing: replacingFullDraft) == .accepted)

        let fullFileQueue = (0..<policy.maxUnsyncedUserSelectedFilesPerAccount).map { index in
            NativeQueuedMutation.spoonCreatePhoto(
                recipeID: "recipe/lemon",
                photo: NativeStagedMediaUpload(
                    localStageID: "stage_spoon_file_\(index)",
                    fileName: "spoon.webp",
                    contentType: "image/webp",
                    data: Data([0x01])
                ),
                clientMutationID: "cm_spoon_file_\(index)",
                note: nil,
                nextTime: nil,
                cookedAt: nil,
                useAsRecipeCover: false,
                createdAt: Self.createdAt
            )
        }
        let fileCapViewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: fullFileQueue,
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        )
        #expect(fileCapViewModel.stagedMediaUsage.fileCount == policy.maxUnsyncedUserSelectedFilesPerAccount)
        #expect(fileCapViewModel.evaluateNewPhoto(byteCount: 1) == .rejected(.accountFileCapReached(limitFiles: policy.maxUnsyncedUserSelectedFilesPerAccount, silentEvictionAllowed: false)))
    }

    @Test("cook-log view model covers equality queued online synced and skipped conflicts")
    func cookLogViewModelCoversEqualityQueuedOnlineSyncedAndSkippedConflicts() throws {
        let queued = NativeQueuedMutation.spoonUpdate(
            recipeID: "recipe/lemon",
            spoonID: "spoon/owned",
            clientMutationID: "cm_update_owned",
            note: "Sharper.",
            nextTime: nil,
            cookedAt: nil,
            photoURL: nil,
            createdAt: Self.createdAt
        )
        let viewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: [Self.spoon(id: "spoon/owned", chefID: "chef_ari")]),
            currentChefID: "chef_ari",
            queuedMutations: [queued],
            conflicts: [
                NativeSyncConflict(
                    clientMutationID: "cm_unrelated",
                    kind: .validation,
                    serverRevision: .updatedAt(Self.createdAt),
                    message: "Different local edit."
                ),
                NativeSyncConflict(
                    clientMutationID: "cm_update_owned",
                    kind: .validation,
                    serverRevision: .updatedAt(Self.createdAt),
                    message: "Cook log changed elsewhere."
                )
            ],
            connectivity: .online,
            now: { Self.createdAt }
        )
        let sameViewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: [Self.spoon(id: "spoon/owned", chefID: "chef_ari")]),
            currentChefID: "chef_ari",
            queuedMutations: [queued],
            conflicts: viewModel.conflicts,
            connectivity: .online,
            now: { "different-clock" }
        )
        let differentRecipe = SpoonCookLogViewModel(
            recipeID: "recipe/lime",
            data: viewModel.data,
            currentChefID: "chef_ari",
            queuedMutations: [queued],
            conflicts: viewModel.conflicts,
            connectivity: .online,
            now: { Self.createdAt }
        )

        #expect(viewModel == sameViewModel)
        #expect(viewModel != differentRecipe)
        #expect(viewModel.conflictBanner?.localClientMutationID == "cm_update_owned")
        #expect(viewModel.offlineIndicator.display == .conflict(recordID: "cm_update_owned", mutationID: "cm_update_owned"))

        let queuedOnline = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: viewModel.data,
            currentChefID: "chef_ari",
            queuedMutations: [queued],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        #expect(queuedOnline.offlineIndicator.display == .queuedWork(count: 1, oldestClientMutationID: "cm_update_owned"))

        let synced = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: viewModel.data,
            currentChefID: "chef_ari",
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        #expect(synced.offlineIndicator.display == .synced)
        #expect(synced.queuedWorkSummary == nil)

        let secondQueued = NativeQueuedMutation.spoonDelete(
            recipeID: "recipe/lemon",
            spoonID: "spoon/owned",
            clientMutationID: "cm_delete_owned",
            createdAt: Self.createdAt
        )
        let pluralQueued = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: viewModel.data,
            currentChefID: "chef_ari",
            queuedMutations: [queued, secondQueued],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        #expect(pluralQueued.queuedWorkSummary == "2 cook-log changes waiting to sync")
    }

    @Test("online spoon actions plan exact REST mutations with offline fallbacks")
    func onlineSpoonActionsPlanExactRESTMutationsWithOfflineFallbacks() throws {
        let viewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: [Self.spoon(id: "spoon/owned", chefID: "chef_ari")]),
            currentChefID: "chef_ari",
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )

        let create = try viewModel.plan(.create(
            note: " Loved it. ",
            nextTime: " more lemon ",
            cookedAt: "2026-06-27T15:30:00.000Z",
            photo: nil,
            photoURL: nil,
            useAsRecipeCover: false,
            clientMutationID: "cm_create_note"
        ))
        try assertSpoonJSONRequest(
            try spoonRemoteRequest(from: create),
            method: .post,
            path: "/api/v1/recipes/recipe%2Flemon/spoons",
            expected: [
                "clientMutationId": "cm_create_note",
                "note": "Loved it.",
                "nextTime": "more lemon",
                "cookedAt": "2026-06-27T15:30:00.000Z",
                "photoUrl": NSNull(),
                "useAsRecipeCover": false
            ]
        )
        let createFallback = try requireSpoonMutation(create.offlineFallbackMutation, "create fallback")
        #expect(createFallback.queueableKind == .spoonCreate)
        #expect(createFallback.dependencyKey == "recipe:recipe/lemon")
        try assertSpoonJSONRequest(
            try spoonQueuedRequest(from: createFallback),
            method: .post,
            path: "/api/v1/recipes/recipe%2Flemon/spoons",
            expected: [
                "clientMutationId": "cm_create_note",
                "note": "Loved it.",
                "nextTime": "more lemon",
                "cookedAt": "2026-06-27T15:30:00.000Z",
                "photoUrl": NSNull(),
                "useAsRecipeCover": false
            ]
        )

        let update = try viewModel.plan(.update(
            spoonID: "spoon/owned",
            note: nil,
            nextTime: "Less salt.",
            cookedAt: nil,
            photoURL: nil,
            clientMutationID: "cm_update_note"
        ))
        try assertSpoonJSONRequest(
            try spoonRemoteRequest(from: update),
            method: .patch,
            path: "/api/v1/recipes/recipe%2Flemon/spoons/spoon%2Fowned",
            expected: [
                "clientMutationId": "cm_update_note",
                "note": NSNull(),
                "nextTime": "Less salt.",
                "cookedAt": NSNull(),
                "photoUrl": NSNull()
            ]
        )
        #expect(try requireSpoonMutation(update.offlineFallbackMutation, "update fallback").queueableKind == .spoonUpdate)

        let delete = try viewModel.plan(.delete(spoonID: "spoon/owned", clientMutationID: "cm_delete_spoon"))
        let deleteRequest = try spoonRemoteRequest(from: delete)
        #expect(deleteRequest.method == .delete)
        #expect(deleteRequest.url.path == "/api/v1/recipes/recipe%2Flemon/spoons/spoon%2Fowned")
        #expect(deleteRequest.headers["X-Client-Mutation-Id"] == "cm_delete_spoon")
        #expect(deleteRequest.body == nil)
        #expect(try requireSpoonMutation(delete.offlineFallbackMutation, "delete fallback").queueableKind == .spoonDelete)
    }

    @Test("spoon actions expose success messages and block unauthorized or empty edits")
    func spoonActionsExposeSuccessMessagesAndBlockUnauthorizedOrEmptyEdits() throws {
        #expect(SpoonCookLogAction.create(note: "Cooked.", nextTime: nil, cookedAt: nil, photo: nil, photoURL: nil, useAsRecipeCover: false, clientMutationID: "cm_create").successMessage == "Cook logged.")
        #expect(SpoonCookLogAction.update(spoonID: "spoon/owned", note: "Updated.", nextTime: nil, cookedAt: nil, photoURL: nil, clientMutationID: "cm_update").successMessage == "Cook log updated.")
        #expect(SpoonCookLogAction.delete(spoonID: "spoon/owned", clientMutationID: "cm_delete").successMessage == "Cook log deleted.")

        let viewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: [
                Self.spoon(id: "spoon/owned", chefID: "chef_ari"),
                Self.spoon(id: "spoon/friend", chefID: "chef_jules", username: "jules")
            ]),
            currentChefID: "chef_ari",
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )

        let unauthorizedUpdate = try viewModel.plan(.update(
            spoonID: "spoon/friend",
            note: "Nope.",
            nextTime: nil,
            cookedAt: nil,
            photoURL: nil,
            clientMutationID: "cm_update_friend"
        ))
        #expect(unauthorizedUpdate.blockedReason == "Only the cook who logged this can edit it.")

        let emptyUpdate = try viewModel.plan(.update(
            spoonID: "spoon/owned",
            note: "   ",
            nextTime: nil,
            cookedAt: nil,
            photoURL: nil,
            clientMutationID: "cm_update_empty"
        ))
        #expect(emptyUpdate.blockedReason == "A cook log needs a note, next-time thought, or photo.")

        let unauthorizedDelete = try viewModel.plan(.delete(
            spoonID: "spoon/friend",
            clientMutationID: "cm_delete_friend"
        ))
        #expect(unauthorizedDelete.blockedReason == "Only the cook who logged this can delete it.")
    }

    @Test("photo spoon actions plan multipart uploads and offline staged media")
    func photoSpoonActionsPlanMultipartUploadsAndOfflineStagedMedia() throws {
        let viewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        )
        let photo = SpoonCookLogPhotoAttachment(
            localStageID: "stage_spoon_photo",
            fileName: "spoon.webp",
            contentType: "image/webp",
            data: Data([0x52, 0x49, 0x46, 0x46])
        )

        let plan = try viewModel.plan(.create(
            note: "Photo cook.",
            nextTime: nil,
            cookedAt: nil,
            photo: photo,
            photoURL: nil,
            useAsRecipeCover: true,
            clientMutationID: "cm_photo"
        ))

        #expect(plan.remoteRequestBuilder == nil)
        #expect(plan.offlineFallbackMutation == nil)
        let queued = try requireSpoonMutation(plan.queuedMutation, "offline photo")
        #expect(queued.queueableKind == .spoonCreatePhoto)
        let request = try spoonQueuedRequest(from: queued)
        #expect(request.method == .post)
        #expect(request.url.path == "/api/v1/recipes/recipe%2Flemon/spoons")
        let bodyString = spoonBodyString(from: request)
        #expect(bodyString?.contains(#"name="photo"; filename="spoon.webp""#) == true)
        #expect(bodyString?.contains(#"name="useAsRecipeCover""#) == true)
        #expect(bodyString?.contains("true") == true)

        let onlineViewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        let restoredPhoto = SpoonCookLogPhotoAttachment(
            localStageID: "stage_restored_spoon_photo",
            fileName: "spoon.webp",
            contentType: "image/webp",
            data: Data()
        )
        let restoredPlan = try onlineViewModel.plan(.create(
            note: "Restored photo draft.",
            nextTime: nil,
            cookedAt: nil,
            photo: restoredPhoto,
            photoURL: nil,
            useAsRecipeCover: false,
            clientMutationID: "cm_restored_photo"
        ))
        #expect(restoredPlan.remoteRequestBuilder == nil)
        #expect(try requireSpoonMutation(restoredPlan.queuedMutation, "restored photo").queueableKind == .spoonCreatePhoto)
    }

    @Test("cook-log draft state normalizes text and persists staged photo metadata only")
    func cookLogDraftStateNormalizesTextAndPersistsStagedPhotoMetadataOnly() throws {
        let stagedPhoto = NativeStagedMediaUpload(
            localStageID: "stage_spoon_draft",
            fileName: "spoon.jpg",
            contentType: "image/jpeg",
            data: Data([0xFF, 0xD8])
        )
        let draft = SpoonCookLogDraftState(
            recipeID: " recipe/lemon ",
            note: " Loved it. ",
            nextTime: " more lemon ",
            stagedPhoto: stagedPhoto,
            useAsRecipeCover: true,
            updatedAt: Self.createdAt
        )

        #expect(draft.recipeID == "recipe/lemon")
        #expect(draft.note == "Loved it.")
        #expect(draft.nextTime == "more lemon")
        #expect(draft.hasContent)
        #expect(draft.stagedPhoto == stagedPhoto)
        #expect(draft.persistable?.useAsRecipeCover == true)

        let decoded = try JSONDecoder().decode(
            SpoonCookLogDraftState.self,
            from: try JSONEncoder().encode(draft)
        )
        #expect(decoded == draft)
        #expect(decoded.stagedPhoto?.data.isEmpty == true)

        let empty = SpoonCookLogDraftState(
            recipeID: "recipe/lemon",
            note: "   ",
            nextTime: nil,
            stagedPhoto: nil,
            useAsRecipeCover: true,
            updatedAt: Self.createdAt
        )
        #expect(!empty.hasContent)
        #expect(empty.persistable == nil)

        let blankRecipeID = SpoonCookLogDraftState(
            recipeID: "   ",
            note: "Keep visible.",
            nextTime: nil,
            stagedPhoto: nil,
            useAsRecipeCover: false,
            updatedAt: Self.createdAt
        )
        #expect(blankRecipeID.recipeID == "   ")
    }

    @Test("empty spoon create is blocked before reaching the API")
    func emptySpoonCreateIsBlockedBeforeAPI() throws {
        let viewModel = SpoonCookLogViewModel(
            recipeID: "recipe/lemon",
            data: SpoonCookLogData(spoons: []),
            currentChefID: "chef_ari",
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )

        let plan = try viewModel.plan(.create(
            note: "   ",
            nextTime: nil,
            cookedAt: nil,
            photo: nil,
            photoURL: nil,
            useAsRecipeCover: false,
            clientMutationID: "cm_empty"
        ))

        #expect(plan.blockedReason == "Add a note, next-time thought, or photo before logging this cook.")
        #expect(plan.remoteRequestBuilder == nil)
        #expect(plan.queuedMutation == nil)
        #expect(plan.offlineFallbackMutation == nil)
    }

    @Test("recipe detail wires the native spoon cook-log surface")
    func recipeDetailWiresNativeSpoonCookLogSurface() throws {
        let detailSource = try readSpoonCookLogRepoFile("Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift")
        let spoonSource = try readSpoonCookLogRepoFile("Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift")
        let navigationSource = try readSpoonCookLogRepoFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")

        #expect(detailSource.contains("SpoonCookLogView("))
        #expect(detailSource.contains("spoonRepository.fetchCookLog"))
        #expect(detailSource.contains(".onChange(of: snapshotViewModel)"))
        #expect(detailSource.contains("while true"))
        #expect(detailSource.contains("seenCursors"))
        #expect(detailSource.contains("RecipeDetailCookLogPaginationError"))
        #expect(detailSource.contains(".id(viewModel.id)"))
        #expect(spoonSource.contains("PhotosPicker"))
        #expect(spoonSource.contains("useAsRecipeCover"))
        #expect(spoonSource.contains("run(.create("))
        #expect(spoonSource.contains("run(.update("))
        #expect(spoonSource.contains("run(.delete("))
        #expect(spoonSource.contains("evaluateNewPhoto"))
        #expect(spoonSource.contains("replacing: stagedPhoto"))
        #expect(spoonSource.contains("mediaRejectionMessage"))
        #expect(spoonSource.contains("conflictDidRequestReview"))
        #expect(!spoonSource.contains("RecipeCoverImage(url: row.photoURL)"))
        #expect(spoonSource.contains("Image(systemName: \"fork.knife.circle\")"))
        #expect(spoonSource.contains("supportedSpoonPhotoContentTypes"))
        #expect(spoonSource.contains("Unsupported photo format. Choose a JPEG, PNG, or WebP image."))
        #expect(spoonSource.contains("draftDidChange"))
        let sheetRange = try #require(spoonSource.range(of: ".sheet(item: $editingRow)"))
        let rowRange = try #require(spoonSource.range(of: "private func spoonRow"))
        #expect(sheetRange.lowerBound < rowRange.lowerBound)
        #expect(detailSource.contains("spoonCookLogDraft"))
        #expect(navigationSource.contains("spoonCookLogRepository"))
        #expect(navigationSource.contains("recordSpoonCookLogDraft"))
        #expect(navigationSource.contains("performSpoonCookLogAction"))
        #expect(navigationSource.contains("discardSpoonCookLogConflict"))
        #expect(navigationSource.contains("SpoonCookLogStagedMediaUsage(drafts:"))
    }

    private static func decodedQueuedPhotoMutation(byteCount: Int, clientMutationID: String) throws -> NativeQueuedMutation {
        try JSONDecoder().decode(
            NativeQueuedMutation.self,
            from: Data(
                """
                {
                  "schemaVersion": 1,
                  "id": "native:\(clientMutationID)",
                  "clientMutationId": "\(clientMutationID)",
                  "createdAt": "\(Self.createdAt)",
                  "retryCount": 0,
                  "kind": {
                    "type": "spoon.createPhoto",
                    "recipeId": "recipe/lemon",
                    "photo": {
                      "localStageId": "stage_\(clientMutationID)",
                      "fileName": "spoon.webp",
                      "contentType": "image/webp",
                      "byteCount": \(byteCount)
                    },
                    "note": null,
                    "nextTime": null,
                    "cookedAt": null,
                    "useAsRecipeCover": false
                  }
                }
                """.utf8
            )
        )
    }

    private static func spoon(
        id: String,
        chefID: String = "chef_ari",
        username: String = "ari",
        note: String? = "Loved it.",
        nextTime: String? = nil,
        photoURL: URL? = nil,
        deletedAt: String? = nil,
        cookedAt: String? = "2026-06-27T15:00:00.000Z"
    ) -> RecipeDetailRecentSpoon {
        RecipeDetailRecentSpoon(
            id: id,
            chefID: chefID,
            recipeID: "recipe/lemon",
            cookedAt: cookedAt,
            photoURL: photoURL,
            note: note,
            nextTime: nextTime,
            deletedAt: deletedAt,
            createdAt: "2026-06-27T15:00:00.000Z",
            updatedAt: Self.createdAt,
            chef: ChefSummary(id: chefID, username: username)
        )
    }
}

private final class RecordingSpoonCookLogAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    private let envelope: APIEnvelope<SpoonCookLogListData>
    private(set) var requests: [APIRequest] = []

    init(envelope: APIEnvelope<SpoonCookLogListData>) {
        self.envelope = envelope
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        requests.append(try request.urlRequest(configuration: configuration))
        guard valueType == SpoonCookLogListData.self else {
            throw SpoonCookLogSurfaceTestFailure("Unexpected value type \(valueType).")
        }
        return envelope as! APIEnvelope<Value>
    }
}

private func spoonRemoteRequest(from plan: SpoonCookLogMutationPlan) throws -> APIRequest {
    guard let builder = plan.remoteRequestBuilder else {
        throw SpoonCookLogSurfaceTestFailure("Expected an online spoon action to provide a remote request builder.")
    }
    return try builder.urlRequest(configuration: SpoonCookLogSurfaceTests.configuration)
}

private func spoonQueuedRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: SpoonCookLogSurfaceTests.configuration)
}

private func requireSpoonMutation(_ mutation: NativeQueuedMutation?, _ label: String) throws -> NativeQueuedMutation {
    guard let mutation else {
        throw SpoonCookLogSurfaceTestFailure("Expected \(label) to provide a native queued mutation.")
    }
    return mutation
}

private func assertSpoonJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: Any],
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    #expect(request.method == method, sourceLocation: sourceLocation)
    #expect(request.url.path == path, sourceLocation: sourceLocation)
    let body = try spoonJSONBody(from: request)
    #expect(NSDictionary(dictionary: body).isEqual(to: expected), sourceLocation: sourceLocation)
}

private func spoonJSONBody(from request: APIRequest) throws -> [String: Any] {
    let data = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func spoonBodyString(from request: APIRequest) -> String? {
    guard let body = request.body else {
        return nil
    }
    return String(data: body, encoding: .utf8)
}

private func readSpoonCookLogRepoFile(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private struct SpoonCookLogSurfaceTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
