import Foundation
import Testing
@testable import SpoonjoyCore

/// Recipe edits send only the changed fields with the version they were based on, and a `409 edit_conflict`
/// is settled field by field: sent again when nobody else changed those fields, held with both versions when
/// someone did, and never overwritten without the cook's choice.
@Suite("Recipe edit conflicts")
struct NativeRecipeEditTests {
    static let base = NativeRecipeFields(title: "Soup", description: "Warm.", servings: "2")
    static let baseUpdatedAt = "2026-10-01T08:00:00.000Z"
    static let serverUpdatedAt = "2026-10-01T09:00:00.000Z"
    static let createdAt = "2026-10-01T08:30:00.000Z"

    static func edit(title: String = "Soup", description: String? = "Warm.", servings: String? = "2") -> NativeRecipeEdit {
        NativeRecipeEdit(
            from: base,
            to: NativeRecipeFields(title: title, description: description, servings: servings),
            expectedUpdatedAt: baseUpdatedAt
        )
    }

    static func server(title: String = "Soup", description: String? = "Warm.", servings: String? = "2") -> NativeRecipeServerVersion {
        NativeRecipeServerVersion(fields: NativeRecipeFields(title: title, description: description, servings: servings), updatedAt: serverUpdatedAt)
    }

    static func body(_ builder: APIRequestBuilder) throws -> NSDictionary {
        let data = try #require(builder.body)
        return try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    // MARK: Fields and edits

    @Test("fields are trimmed, and an empty description or servings is no value")
    func fieldsAreNormalized() {
        let fields = NativeRecipeFields(title: "  Soup \n", description: "  ", servings: " 4 ")
        #expect(fields == NativeRecipeFields(title: "Soup", description: nil, servings: "4"))
        #expect(fields[.title] == "Soup")
        #expect(fields[.description] == nil)
        #expect(fields[.servings] == "4")
        #expect(NativeRecipeEditField.allCases.map(\.label) == ["Title", "Description", "Servings"])
    }

    @Test("an edit holds only the changed fields, each with the value it started from")
    func editHoldsOnlyChangedFields() {
        let edit = Self.edit(title: "Better Soup", description: nil)
        #expect(edit.changes == [
            NativeRecipeFieldChange(field: .title, value: "Better Soup", base: NativeRecipeFieldBase("Soup")),
            NativeRecipeFieldChange(field: .description, value: nil, base: NativeRecipeFieldBase("Warm."))
        ])
        #expect(edit.expectedUpdatedAt == Self.baseUpdatedAt)
        #expect(!edit.isEmpty)
        #expect(Self.edit().isEmpty)
    }

    // MARK: Merging with the current recipe

    @Test("a field nobody else changed is sent again on top of the current version")
    func untouchedFieldIsResent() {
        let merge = Self.edit(title: "Better Soup").merged(with: Self.server(description: "Changed on the web."))
        #expect(merge == .resend(NativeRecipeEdit(
            changes: [NativeRecipeFieldChange(field: .title, value: "Better Soup", base: NativeRecipeFieldBase("Soup"))],
            expectedUpdatedAt: Self.serverUpdatedAt
        )))
    }

    @Test("an edit the server already has needs nothing")
    func editAlreadySaved() {
        #expect(Self.edit(title: "Better Soup").merged(with: Self.server(title: "Better Soup")) == .alreadySaved)
    }

    @Test("a field changed elsewhere too is a conflict carrying both values and the cook's other changes")
    func fieldChangedElsewhereConflicts() {
        let server = Self.server(title: "Their Soup", servings: "6")
        let conflictMerge = Self.edit(title: "My Soup", description: "Hot.").merged(with: server)
        guard case .conflict(let conflict) = conflictMerge else {
            Issue.record("Expected a conflict; got \(conflictMerge)")
            return
        }
        #expect(conflict.fields == [NativeRecipeEditConflict.Field(field: .title, mine: "My Soup", theirs: "Their Soup")])
        #expect(conflict.unconflicted == [NativeRecipeFieldChange(field: .description, value: "Hot.", base: NativeRecipeFieldBase("Warm."))])
        #expect(conflict.server == server)
        #expect(NativeRecipeEditConflict.message.contains("Choose which version to keep"))
    }

    @Test("a field whose starting value is unknown conflicts unless the server already has it")
    func unknownBaseConflicts() {
        let legacy = NativeRecipeEdit(changes: [NativeRecipeFieldChange(field: .title, value: "My Soup", base: nil)], expectedUpdatedAt: nil)
        guard case .conflict(let conflict) = legacy.merged(with: Self.server()) else {
            Issue.record("Expected a conflict")
            return
        }
        #expect(conflict.fields.map(\.field) == [.title])
        #expect(legacy.merged(with: Self.server(title: "My Soup")) == .alreadySaved)
    }

    // MARK: The cook's choice

    @Test("keeping my edit sends every changed field on top of the current version")
    func keepingMine() throws {
        let conflict = NativeRecipeEditConflict(
            fields: [NativeRecipeEditConflict.Field(field: .servings, mine: "4", theirs: "6")],
            unconflicted: [NativeRecipeFieldChange(field: .title, value: "My Soup", base: NativeRecipeFieldBase("Soup"))],
            server: Self.server(servings: "6")
        )
        #expect(conflict.resolved(keeping: .mine) == NativeRecipeEdit(
            changes: [
                NativeRecipeFieldChange(field: .title, value: "My Soup", base: NativeRecipeFieldBase("Soup")),
                NativeRecipeFieldChange(field: .servings, value: "4", base: NativeRecipeFieldBase("6"))
            ],
            expectedUpdatedAt: Self.serverUpdatedAt
        ))
        #expect(conflict.resolved(keeping: .theirs) == NativeRecipeEdit(
            changes: [NativeRecipeFieldChange(field: .title, value: "My Soup", base: NativeRecipeFieldBase("Soup"))],
            expectedUpdatedAt: Self.serverUpdatedAt
        ))
    }

    @Test("keeping the saved version of the only changed field leaves nothing to send")
    func keepingTheirsLeavesNothing() {
        let conflict = NativeRecipeEditConflict(
            fields: [NativeRecipeEditConflict.Field(field: .title, mine: "My Soup", theirs: "Their Soup")],
            unconflicted: [],
            server: Self.server(title: "Their Soup")
        )
        #expect(conflict.resolved(keeping: .theirs) == nil)
    }

    // MARK: The recorded 409

    @Test("the recorded 409 edit_conflict carries the current recipe")
    func recordedConflictDecodes() throws {
        let apiError = try Self.recordedConflictError()
        let server = try #require(NativeRecipeServerVersion(editConflict: apiError))
        #expect(server.fields == NativeRecipeFields(title: "Lemon Pantry Pasta", description: "Bright weeknight pasta from the pantry.", servings: "4"))
        #expect(server.updatedAt == "2026-01-01T00:00:00.000Z")
        let transportError = APITransportError(kind: .apiError, requestID: apiError.requestID, statusCode: 409, apiError: apiError, retryDecision: APIRetryPolicy.decision(for: apiError))
        #expect(transportError.isRecipeEditConflict)
        #expect(transportError.retryDecision == .doNotRetry)
    }

    @Test("only an edit_conflict with a recipe and a version is read as the current recipe")
    func otherErrorsAreNotEditConflicts() {
        func error(code: String = "edit_conflict", details: [String: JSONValue]) -> APIError {
            APIError(requestID: "req", code: code, message: "No.", status: 409, details: details)
        }
        let recipe: JSONValue = .object(["title": .string("Soup"), "description": .null, "updatedAt": .string("2026-10-01T10:00:00.000Z")])
        #expect(NativeRecipeServerVersion(editConflict: error(code: "idempotency_conflict", details: ["recipe": recipe])) == nil)
        #expect(NativeRecipeServerVersion(editConflict: error(details: [:])) == nil)
        #expect(NativeRecipeServerVersion(editConflict: error(details: ["recipe": .object(["title": .null])])) == nil)
        #expect(NativeRecipeServerVersion(editConflict: error(details: ["recipe": .object(["title": .string("Soup")])])) == nil)
        // Without currentUpdatedAt the recipe's own updatedAt is the version.
        #expect(NativeRecipeServerVersion(editConflict: error(details: ["recipe": recipe])) == NativeRecipeServerVersion(
            fields: NativeRecipeFields(title: "Soup", description: nil, servings: nil),
            updatedAt: "2026-10-01T10:00:00.000Z"
        ))
        let notFound = APITransportError(kind: .apiError, requestID: nil, statusCode: 404, apiError: error(details: [:]), retryDecision: .doNotRetry)
        #expect(!notFound.isRecipeEditConflict)
        let offline = APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        #expect(!offline.isRecipeEditConflict)
    }

    static func recordedConflictError() throws -> APIError {
        let url = V2APIRecordingContractTests.directory.appendingPathComponent("recipe-update-edit-conflict.json")
        let recording = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let body = try JSONSerialization.data(withJSONObject: try #require(recording["body"]))
        guard case .failure(let apiError) = try APIEnvelope<JSONValue>.decodeResult(body) else {
            throw V2APIRecordingContractTests.RecordingError(description: "recipe-update-edit-conflict is not an error envelope")
        }
        return apiError
    }

    // MARK: Requests and the queue

    @Test("the online request and the queued edit send the same body, with only the changed fields")
    func requestsSendOnlyChangedFields() throws {
        let edit = Self.edit(title: "Better Soup", servings: nil)
        let online = try RecipeWriteRequests.updateRecipe(id: "recipe_soup", clientMutationID: "cm_edit", edit: edit)
        let queued = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_soup", clientMutationID: "cm_edit", edit: edit, createdAt: Self.createdAt)
        let expected: NSDictionary = [
            "clientMutationId": "cm_edit",
            "title": "Better Soup",
            "servings": NSNull(),
            "expectedUpdatedAt": Self.baseUpdatedAt
        ]
        #expect(try Self.body(online) == expected)
        #expect(try Self.body(try queued.requestBuilder()) == expected)
        #expect(online.method == .patch)
        #expect(online.pathComponents == ["api", "v1", "recipes", "recipe_soup"])
        #expect(try queued.requestBuilder().pathComponents == online.pathComponents)

        let unversioned = try RecipeWriteRequests.updateRecipe(
            id: "recipe_soup",
            clientMutationID: "cm_plain",
            edit: NativeRecipeEdit(changes: [NativeRecipeFieldChange(field: .description, value: "Hot.", base: nil)], expectedUpdatedAt: nil)
        )
        #expect(try Self.body(unversioned) == ["clientMutationId": "cm_plain", "description": "Hot."])
    }

    @Test("a queued edit keeps its version and starting values through the stored queue")
    func queuedEditSurvivesStorage() throws {
        let edit = Self.edit(title: "Better Soup", description: nil)
        let queued = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_soup", clientMutationID: "cm_edit", edit: edit, createdAt: Self.createdAt)
        let stored = try JSONDecoder().decode(NativeQueuedMutation.self, from: JSONEncoder().encode(queued))
        #expect(stored.recipeEdit == edit)
        #expect(stored.recipeID == "recipe_soup")
        #expect(stored.dependencyKey == "recipe:recipe_soup")

        let legacy = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_soup", clientMutationID: "cm_old", title: "Soup", description: nil, servings: "2", createdAt: Self.createdAt)
        #expect(legacy.recipeEdit == NativeRecipeEdit(
            changes: [
                NativeRecipeFieldChange(field: .title, value: "Soup", base: nil),
                NativeRecipeFieldChange(field: .description, value: nil, base: nil),
                NativeRecipeFieldChange(field: .servings, value: "2", base: nil)
            ],
            expectedUpdatedAt: nil
        ))
        #expect(NativeQueuedMutation.recipeDelete(recipeID: "recipe_soup", clientMutationID: "cm_delete", createdAt: Self.createdAt).recipeEdit == nil)
    }

    @Test("replacing a queued edit keeps its identity and drops fields it no longer sends")
    func replacingQueuedEdit() throws {
        let queued = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_soup", clientMutationID: "cm_edit", edit: Self.edit(title: "Better Soup", description: nil), createdAt: Self.createdAt)
            .recordingError("Held.")
        let rebased = NativeRecipeEdit(
            changes: [NativeRecipeFieldChange(field: .title, value: "Better Soup", base: NativeRecipeFieldBase("Soup"))],
            expectedUpdatedAt: Self.serverUpdatedAt
        )
        let replaced = queued.replacingRecipeEdit(rebased)
        #expect(replaced.id == queued.id)
        #expect(replaced.clientMutationID == "cm_edit")
        #expect(replaced.createdAt == Self.createdAt)
        #expect(replaced.lastError == "Held.")
        #expect(replaced.recipeEdit == rebased)
        #expect(try Self.body(try replaced.requestBuilder()) == [
            "clientMutationId": "cm_edit",
            "title": "Better Soup",
            "expectedUpdatedAt": Self.serverUpdatedAt
        ])
    }

    @Test("settling a held edit rewrites or removes only that edit in the queue")
    func settlingHeldEditInQueue() {
        let held = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_soup", clientMutationID: "cm_held", edit: Self.edit(title: "Better Soup"), createdAt: Self.createdAt)
        let other = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_stew", clientMutationID: "cm_other", edit: Self.edit(servings: "6"), createdAt: Self.createdAt)
        let rebased = NativeRecipeEdit(
            changes: [NativeRecipeFieldChange(field: .title, value: "Better Soup", base: NativeRecipeFieldBase("Their Soup"))],
            expectedUpdatedAt: Self.serverUpdatedAt
        )

        let kept = NativeQueuedMutation.settlingRecipeEdit("cm_held", with: rebased, in: [held, other])
        #expect(kept.map(\.clientMutationID) == ["cm_held", "cm_other"])
        #expect(kept.first?.recipeEdit == rebased)
        #expect(kept.last == other)

        let dropped = NativeQueuedMutation.settlingRecipeEdit("cm_held", with: nil, in: [held, other])
        #expect(dropped == [other])
    }

    @Test("a queued edit shows only the fields it changes on the recipe")
    func optimisticEditKeepsUnchangedFields() throws {
        let recipe = try Self.recordedRecipe()
        let edit = NativeRecipeEdit(
            from: NativeRecipeFields(recipe: recipe),
            to: NativeRecipeFields(title: "Lemon Pasta", description: recipe.description, servings: recipe.servings),
            expectedUpdatedAt: recipe.updatedAt
        )
        let queued = NativeQueuedMutation.recipeUpdate(recipeID: recipe.id, clientMutationID: "cm_edit", edit: edit, createdAt: Self.createdAt)
        let shown = try #require(queued.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: recipe.chef, now: Self.createdAt).first)
        #expect(shown.title == "Lemon Pasta")
        #expect(shown.description == recipe.description)
        #expect(shown.servings == recipe.servings)
        #expect(shown.updatedAt == Self.createdAt)

        let cleared = NativeQueuedMutation.recipeUpdate(recipeID: recipe.id, clientMutationID: "cm_clear", edit: NativeRecipeEdit(
            from: NativeRecipeFields(recipe: recipe),
            to: NativeRecipeFields(title: recipe.title, description: nil, servings: recipe.servings),
            expectedUpdatedAt: recipe.updatedAt
        ), createdAt: Self.createdAt)
        let clearedRecipe = try #require(cleared.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: recipe.chef, now: Self.createdAt).first)
        #expect(clearedRecipe.description == nil)
        #expect(clearedRecipe.servings == recipe.servings)
    }

    /// The recipe in the recorded 409, decoded with the app's model.
    static func recordedRecipe() throws -> Recipe {
        let apiError = try recordedConflictError()
        let recipe = try #require(apiError.details["recipe"])
        return try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe))
    }

    // MARK: The editor

    @Test("the editor sends the changed fields based on the version it opened, and nothing when nothing changed")
    func editorPlansPartialEdit() throws {
        let recipe = try Self.recordedRecipe()
        let editor = RecipeEditorViewModel(mode: .edit(recipe: recipe, currentChefID: recipe.chef.id), connectivity: .online, now: { Self.createdAt })

        let unchanged = try editor.plan(.save(clientMutationID: "cm_nothing"))
        #expect(editor.recipeEdit.isEmpty)
        #expect(!unchanged.sendsChange)
        #expect(unchanged.successRoute == .recipeDetail(id: recipe.id, presentation: .detail))
        #expect(unchanged.blockedReason == nil)

        var draft = editor.draft
        draft.servings = "6"
        let changed = editor.updatingDraft(draft)
        let plan = try changed.plan(.save(clientMutationID: "cm_servings"))
        #expect(plan.sendsChange)
        #expect(changed.recipeEdit == NativeRecipeEdit(
            changes: [NativeRecipeFieldChange(field: .servings, value: "6", base: NativeRecipeFieldBase("4"))],
            expectedUpdatedAt: recipe.updatedAt
        ))
        #expect(try Self.body(try #require(plan.remoteRequestBuilder)) == [
            "clientMutationId": "cm_servings",
            "servings": "6",
            "expectedUpdatedAt": recipe.updatedAt
        ])
        let fallback = try #require(plan.offlineFallbackMutation)
        #expect(fallback.recipeEdit == changed.recipeEdit)
        #expect(fallback.createdAt == Self.createdAt)

        let create = RecipeEditorViewModel(mode: .create(currentChefID: "chef", draft: .blank(currentChefID: "chef")), connectivity: .online, now: { Self.createdAt })
        #expect(create.recipeEdit.isEmpty)
        #expect(RecipeEditorMutationPlan(blockedReason: "No.").sendsChange == false)
        #expect(RecipeEditorMutationPlan(queuedMutation: fallback).sendsChange)
    }

    @Test("an editor keeps the version it opened when the recipe refreshes behind it")
    func editorKeepsOpenedVersion() throws {
        let opened = try Self.recordedRecipe()
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(opened)) as? [String: Any])
        json["title"] = "Saved elsewhere"
        json["updatedAt"] = Self.serverUpdatedAt
        let refreshed = try JSONDecoder().decode(Recipe.self, from: JSONSerialization.data(withJSONObject: json))
        let openedEditor = RecipeEditorViewModel(mode: .edit(recipe: opened, currentChefID: opened.chef.id), connectivity: .online, now: { Self.createdAt })
        let conflict = RecipeEditorConflict(resourceID: opened.id, serverRevision: nil, localClientMutationID: "cm_held", message: "Held.")
        let live = RecipeEditorViewModel(
            mode: .edit(recipe: refreshed, currentChefID: opened.chef.id),
            connectivity: .offline,
            conflict: conflict,
            queuedRecipeMutations: [],
            now: { Self.createdAt }
        )

        let kept = live.keepingRecipe(of: openedEditor)
        #expect(kept.draft == openedEditor.draft)
        #expect(kept.connectivity == .offline)
        #expect(kept.conflict == conflict)
        var draft = kept.draft
        draft.title = "Mine"
        #expect(kept.updatingDraft(draft).recipeEdit == NativeRecipeEdit(
            changes: [NativeRecipeFieldChange(field: .title, value: "Mine", base: NativeRecipeFieldBase(opened.title))],
            expectedUpdatedAt: opened.updatedAt
        ))
    }

    @Test("a held recipe edit conflict reaches the recipe page with both versions")
    func heldConflictCarriesBothVersions() {
        let conflict = NativeRecipeEditConflict(
            fields: [NativeRecipeEditConflict.Field(field: .title, mine: "My Soup", theirs: "Their Soup")],
            unconflicted: [],
            server: Self.server(title: "Their Soup")
        )
        let editConflict = NativeSyncConflict(clientMutationID: "cm_edit", kind: .recipeEdit(conflict), serverRevision: .updatedAt(Self.serverUpdatedAt), message: NativeRecipeEditConflict.message)
        let held = RecipeEditorConflict(resourceID: "recipe_soup", syncConflict: editConflict)
        #expect(held.recipeEdit == conflict)
        #expect(held.localClientMutationID == "cm_edit")
        #expect(held.serverRevision == .updatedAt(Self.serverUpdatedAt))
        #expect(held.message == NativeRecipeEditConflict.message)

        let validation = NativeSyncConflict(clientMutationID: "cm_step", kind: .validation, serverRevision: nil, message: "Step numbers must be unique.")
        #expect(RecipeEditorConflict(resourceID: "recipe_soup", syncConflict: validation).recipeEdit == nil)

        func batch(_ conflicts: [NativeSyncConflict]) -> NativeQueuedMutationBatchResult {
            NativeQueuedMutationBatchResult(submittedClientMutationIDs: ["cm_edit"], drainedClientMutationIDs: [], remainingSubmittedClientMutationIDs: ["cm_edit"], submittedConflicts: conflicts)
        }
        #expect(batch([validation, editConflict]).holdsRecipeEditChoice)
        #expect(!batch([validation]).holdsRecipeEditChoice)
        #expect(!batch([]).holdsRecipeEditChoice)
    }

    // MARK: Sending a queued edit

    static let configuration = APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "sj_access")

    static func conflictResponse(title: String, description: String? = "Warm.", servings: String? = "2", updatedAt: String = serverUpdatedAt) throws -> (Data, URLResponse) {
        let recipe: [String: Any] = ["id": "recipe_soup", "title": title, "description": description ?? NSNull(), "servings": servings ?? NSNull(), "updatedAt": updatedAt]
        return try response(409, [
            "ok": false,
            "requestId": "req_conflict",
            "error": [
                "code": "edit_conflict",
                "message": "The recipe changed after expectedUpdatedAt; nothing was updated",
                "status": 409,
                "details": ["reason": "recipe_changed", "expectedUpdatedAt": baseUpdatedAt, "currentUpdatedAt": updatedAt, "recipe": recipe]
            ]
        ])
    }

    static func response(_ status: Int, _ body: [String: Any]) throws -> (Data, URLResponse) {
        let url = URL(string: "https://spoonjoy.app/api/v1/recipes/recipe_soup")!
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (try JSONSerialization.data(withJSONObject: body), response)
    }

    static var accepted: [String: Any] { ["ok": true, "requestId": "req_ok", "data": ["updated": true]] }

    static func send(_ edit: NativeRecipeEdit, responses: [(Data, URLResponse)]) async throws -> (NativeSyncMutationResult, [NSDictionary]) {
        let session = EditConflictURLSession(responses: responses)
        let transport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: session))
        let mutation = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_soup", clientMutationID: "cm_edit", edit: edit, createdAt: createdAt)
        let result = try await transport.send(mutation, configuration: configuration)
        let bodies = try await session.requests().map { request in
            let data = try #require(request.httpBody)
            return try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
        }
        return (result, bodies)
    }

    @Test("a turned-down edit nobody else touched is sent again once, on the current version")
    func transportResendsCleanEdit() async throws {
        let (result, bodies) = try await Self.send(
            Self.edit(title: "Better Soup"),
            responses: [try Self.conflictResponse(title: "Soup", description: "Changed on the web."), try Self.response(200, Self.accepted)]
        )
        #expect(result == .success(serverRevision: nil))
        #expect(bodies == [
            ["clientMutationId": "cm_edit", "title": "Better Soup", "expectedUpdatedAt": Self.baseUpdatedAt],
            ["clientMutationId": "cm_edit", "title": "Better Soup", "expectedUpdatedAt": Self.serverUpdatedAt]
        ])
    }

    @Test("a turned-down edit to a field changed elsewhere is held with both versions")
    func transportHoldsConflict() async throws {
        let (result, bodies) = try await Self.send(Self.edit(title: "My Soup"), responses: [try Self.conflictResponse(title: "Their Soup")])
        #expect(result == .conflict(
            kind: .recipeEdit(NativeRecipeEditConflict(
                fields: [NativeRecipeEditConflict.Field(field: .title, mine: "My Soup", theirs: "Their Soup")],
                unconflicted: [],
                server: Self.server(title: "Their Soup")
            )),
            serverRevision: .updatedAt(Self.serverUpdatedAt),
            message: NativeRecipeEditConflict.message
        ))
        #expect(bodies.count == 1)
    }

    @Test("a turned-down edit the server already has counts as done")
    func transportAcceptsAlreadySaved() async throws {
        let (result, bodies) = try await Self.send(Self.edit(title: "My Soup"), responses: [try Self.conflictResponse(title: "My Soup")])
        #expect(result == .success(serverRevision: .updatedAt(Self.serverUpdatedAt)))
        #expect(bodies.count == 1)
    }

    @Test("a recipe that changes again between the two requests is compared again on the next sync, never overwritten")
    func transportStopsAfterOneResend() async throws {
        let (retry, retryBodies) = try await Self.send(
            Self.edit(title: "My Soup"),
            responses: [try Self.conflictResponse(title: "Soup"), try Self.conflictResponse(title: "Soup", updatedAt: "2026-10-01T09:30:00.000Z")]
        )
        #expect(retry == .retry(afterSeconds: NativeSyncRetrySchedule().baseDelaySeconds(forRetryCount: 0), message: NativeRecipeEditConflict.message))
        #expect(retryBodies.count == 2)

        let (held, _) = try await Self.send(
            Self.edit(title: "My Soup"),
            responses: [try Self.conflictResponse(title: "Soup"), try Self.conflictResponse(title: "Their Soup", updatedAt: "2026-10-01T09:30:00.000Z")]
        )
        guard case .conflict(.recipeEdit(let conflict), .updatedAt("2026-10-01T09:30:00.000Z"), _) = held else {
            Issue.record("Expected a held conflict; got \(held)")
            return
        }
        #expect(conflict.fields == [NativeRecipeEditConflict.Field(field: .title, mine: "My Soup", theirs: "Their Soup")])

        let (rejected, _) = try await Self.send(
            Self.edit(title: "My Soup"),
            responses: [
                try Self.conflictResponse(title: "Soup"),
                try Self.response(400, ["ok": false, "requestId": "req_bad", "error": ["code": "validation_error", "message": "Title is taken.", "status": 400]])
            ]
        )
        #expect(rejected == .conflict(kind: .validation, serverRevision: nil, message: "Title is taken."))
    }

    @Test("a 409 that is not a readable edit conflict is held like any turned-down change")
    func transportFallsBackForOtherConflicts() async throws {
        let unreadable = try Self.response(409, ["ok": false, "requestId": "req_conflict", "error": ["code": "edit_conflict", "message": "Changed.", "status": 409]])
        let (result, _) = try await Self.send(Self.edit(title: "My Soup"), responses: [unreadable])
        #expect(result == .conflict(kind: .validation, serverRevision: nil, message: "Changed."))
    }
}

private actor EditConflictURLSession: URLSessionPerforming {
    private var responses: [(Data, URLResponse)]
    private var captured: [URLRequest] = []

    init(responses: [(Data, URLResponse)]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        captured.append(request)
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return responses.removeFirst()
    }

    func requests() -> [URLRequest] {
        captured
    }
}
