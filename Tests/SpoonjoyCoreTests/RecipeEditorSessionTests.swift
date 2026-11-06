import Foundation
import Testing
@testable import SpoonjoyCore

/// The glue the recipe editor, the recipe page, Search and Add a recipe share between SwiftUI and Ouro Reins: which
/// editor visit's draft is on screen, what a Save sends and how the shell sends it, the held-change banner's copy, a
/// search run, the recipe page's saved scale, and the editor's small edits.
@Suite("Recipe editor session glue")
struct RecipeEditorSessionTests {
    static let now: @Sendable () -> String = { "2026-06-25T12:30:00.000Z" }

    // MARK: Visits

    @Test("an editor visit keeps its draft until it leaves the stacks")
    func visitsKeepDrafts() throws {
        var visits = RecipeEditorVisits()
        let editor = Self.editor()
        let opened = visits.open("edit#1", with: editor)
        #expect(opened.draft == editor.draft)
        var visit = opened
        visit.draft.title = "Changed"
        visits.record(visit, for: "edit#1")
        #expect(visits.open("edit#1", with: editor).draft.title == "Changed", "a visit already open keeps its draft")
        #expect(visits["edit#1"]?.opened.draft == editor.draft)
        _ = visits.open("edit#2", with: editor)
        #expect(visits.identities == ["edit#1", "edit#2"])
        visits.keep(only: ["edit#2"])
        #expect(visits.identities == ["edit#2"])
        #expect(visits["edit#1"] == nil)
    }

    @Test("the open editor visits are those on a tab's stack and the one on screen")
    func openEditorIdentities() {
        var shell = SpoonjoyShell(route: .kitchen)
        #expect(shell.openEditorIdentities.isEmpty)
        shell.select(.recipes)
        shell.navigate(to: .recipeDetail(id: "recipe_a", presentation: .detail))
        shell.navigate(to: .recipeEditor(id: "recipe_a"))
        let identity = shell.navigation.editorIdentity(for: .recipeEditor(id: "recipe_a"))
        #expect(shell.openEditorIdentities == [identity])
        shell.select(.kitchen)
        #expect(shell.openEditorIdentities == [identity], "the editor left open on Recipes keeps its visit")
    }

    @Test("the editor plans offline exactly while the shell shows it is offline")
    func connectivity() {
        #expect(RecipeEditorConnectivity(display: .offline) == .offline)
        #expect(RecipeEditorConnectivity(display: .synced) == .online)
    }

    // MARK: Content state

    @Test("the session's account owns new recipes, whether the session is fresh or needs a refresh")
    func sessionAccountID() throws {
        let session = try Self.session(accountID: "chef_ari")
        #expect(Self.content(auth: .signedOut).sessionAccountID == nil)
        #expect(Self.content(auth: .authenticated(session)).sessionAccountID == "chef_ari")
        #expect(Self.content(auth: .refreshRequired(session)).sessionAccountID == "chef_ari")
    }

    @Test("a recipe's held change is the first conflict whose queued mutation edits it")
    func recipeEditorConflict() {
        let mutation = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_lemon_pantry_pasta", clientMutationID: "cm_edit", title: "T", description: nil, servings: nil, createdAt: Self.now())
        let other = NativeQueuedMutation.recipeUpdate(recipeID: "recipe_other", clientMutationID: "cm_other", title: "T", description: nil, servings: nil, createdAt: Self.now())
        let content = Self.content(queued: [other, mutation], conflicts: [
            Self.conflict("cm_orphan"),
            Self.conflict("cm_other"),
            Self.conflict("cm_edit"),
        ])
        #expect(content.recipeEditorConflict(for: "recipe_lemon_pantry_pasta")?.localClientMutationID == "cm_edit")
        #expect(content.recipeEditorConflict(for: "recipe_none") == nil)
    }

    @Test("the editor opens blank for a new recipe, on the loaded recipe, and not at all for one not loaded")
    func recipeEditorViewModel() throws {
        let signedOut = Self.content(auth: .signedOut)
        let blank = try #require(signedOut.recipeEditorViewModel(id: nil, connectivity: .offline, now: Self.now))
        #expect(blank.draft.recipeID == nil)
        #expect(blank.draft.currentChefID == "signed-out")
        #expect(blank.connectivity == .offline)
        let content = Self.content(auth: .authenticated(try Self.session(accountID: "chef_ari")))
        #expect(content.recipeEditorViewModel(id: "recipe_missing", connectivity: .online, now: Self.now) == nil)
        let edit = try #require(content.recipeEditorViewModel(id: "recipe_lemon_pantry_pasta", connectivity: .online, now: Self.now))
        #expect(edit.draft.title == "Lemon Pantry Pasta")
        #expect(edit.draft.currentChefID == "chef_ari")
    }

    // MARK: Submission

    @Test("a save is blocked, sends nothing, sends one change, or queues a batch that drains only online")
    func submissions() throws {
        let editor = Self.editor()
        let ids: (String) -> String = { "cm_\($0)" }

        var blank = editor.draft
        blank.steps[0].ingredients[0].name = " "
        let blocked = try editor.updatingDraft(blank).submission(for: RecipeEditorDraftChangePlanner.actions(original: editor.draft, draft: blank, clientMutationID: ids))
        #expect(blocked.kind == .blocked("Name every ingredient."))
        #expect(blocked.successRoute == nil)

        let nothing = try editor.submission(for: RecipeEditorDraftChangePlanner.actions(original: editor.draft, draft: editor.draft, clientMutationID: ids))
        #expect(nothing.kind == .nothing)
        #expect(nothing.successRoute == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))

        var renamed = editor.draft
        renamed.title = "Lemon Pasta"
        let single = try editor.updatingDraft(renamed).submission(for: RecipeEditorDraftChangePlanner.actions(original: editor.draft, draft: renamed, clientMutationID: ids))
        guard case .single(let action, let plan) = single.kind else {
            Issue.record("a title change is one change: \(single.kind)")
            return
        }
        #expect(action == .save(clientMutationID: "cm_recipe-save"))
        #expect(plan.sendsChange)

        var twoChanges = renamed
        twoChanges.addIngredient(id: "local_ingredient_new", toStep: "step_boil")
        twoChanges.steps[0].ingredients[1].name = "salt"
        twoChanges.steps[0].ingredients[1].unit = "tsp"
        let actions = RecipeEditorDraftChangePlanner.actions(original: editor.draft, draft: twoChanges, clientMutationID: ids)
        let online = try editor.updatingDraft(twoChanges).submission(for: actions)
        guard case .batch(let mutations, true) = online.kind else {
            Issue.record("two changes online are a batch drained at once: \(online.kind)")
            return
        }
        #expect(mutations.count == 2)
        let offlineEditor = try #require(Self.content(auth: .authenticated(try Self.session(accountID: "chef_ari")))
            .recipeEditorViewModel(id: "recipe_lemon_pantry_pasta", connectivity: .offline, now: Self.now))
        let offline = try offlineEditor.updatingDraft(twoChanges).submission(for: actions)
        guard case .batch(_, false) = offline.kind else {
            Issue.record("two changes offline are a queued batch: \(offline.kind)")
            return
        }
    }

    @Test("a batch sends each plan's queued mutation or its offline fallback, and a plan with neither is refused")
    func batchMutations() throws {
        let queued = Self.mutation("cm_queued")
        let fallback = Self.mutation("cm_fallback")
        #expect(try RecipeEditorSubmission.batchMutations([
            RecipeEditorMutationPlan(queuedMutation: queued),
            RecipeEditorMutationPlan(offlineFallbackMutation: fallback),
        ]) == [queued, fallback])
        #expect(throws: RecipeEditorPlanningError.missingQueuedMutation) {
            try RecipeEditorSubmission.batchMutations([RecipeEditorMutationPlan(remoteRequestBuilder: Self.request)])
        }
    }

    // MARK: Batch attention

    @Test("after an online batch the editor closes, shows the server's conflict, or says what is still queued")
    func batchAttention() {
        let mutation = Self.mutation("cm_a")
        let held = NativeSyncConflict(clientMutationID: "cm_a", kind: .recipeEdit(Self.editConflict), serverRevision: nil, message: NativeRecipeEditConflict.message)
        #expect(RecipeEditorBatchAttention(after: Self.result(conflicts: [held]), mutations: [mutation], recipeID: "recipe_a") == .none,
                "a held recipe edit is chosen on the recipe page")

        let turnedDown = Self.conflict("cm_a")
        #expect(RecipeEditorBatchAttention(after: Self.result(conflicts: [turnedDown]), mutations: [mutation], recipeID: "recipe_other")
            == .conflict(RecipeEditorConflict(resourceID: "recipe_lemon_pantry_pasta", serverRevision: nil, localClientMutationID: "cm_a", message: "Turned down")))
        #expect(RecipeEditorBatchAttention(after: Self.result(conflicts: [turnedDown]), mutations: [], recipeID: "recipe_other")
            == .conflict(RecipeEditorConflict(resourceID: "recipe_other", serverRevision: nil, localClientMutationID: "cm_a", message: "Turned down")))
        let orphan = RecipeEditorBatchAttention(after: Self.result(conflicts: [turnedDown]), mutations: [], recipeID: nil)
        #expect(orphan == .conflict(RecipeEditorConflict(resourceID: "cm_a", serverRevision: nil, localClientMutationID: "cm_a", message: "Turned down")))
        #expect(orphan.message == "Turned down")

        #expect(RecipeEditorBatchAttention(after: Self.result(drained: [], remaining: ["cm_a"]), mutations: [], recipeID: nil) == .none)
        #expect(RecipeEditorBatchAttention(after: Self.result(drained: ["cm_a"], remaining: []), mutations: [], recipeID: nil) == .none)
        #expect(RecipeEditorBatchAttention.none.message == nil)
        let one = RecipeEditorBatchAttention(after: Self.result(drained: ["cm_a"], remaining: ["cm_b"]), mutations: [], recipeID: nil)
        #expect(one == .stillQueued(count: 1, oldestClientMutationID: "cm_b"))
        #expect(one.message == "One recipe edit is still queued. Review the offline status before leaving the editor.")
        let two = RecipeEditorBatchAttention(after: Self.result(drained: ["cm_a"], remaining: ["cm_b", "cm_c"]), mutations: [], recipeID: nil)
        #expect(two.message == "2 recipe edits are still queued. Review the offline status before leaving the editor.")
    }

    // MARK: Plan runner

    @Test("a plan is queued, waits behind a queued change, is sent, or falls back to the queue offline and on a conflict")
    @MainActor
    func planRunner() async throws {
        let log = Log()
        func run(_ plan: RecipeEditorMutationPlan, queued: [NativeQueuedMutation] = [], failing error: (any Error)? = nil) async throws {
            try await RecipeEditorPlanRunner.perform(
                plan,
                queuedMutations: queued,
                queueMutation: { log.calls.append("queue \($0.clientMutationID)") },
                queueMutations: { mutations, drain in
                    log.calls.append("batch \(mutations.map(\.clientMutationID)) \(drain)")
                    return Self.result(drained: [], remaining: [])
                },
                execute: { _ in
                    log.calls.append("send")
                    if let error { throw error }
                }
            )
        }
        let fallback = Self.mutation("cm_fallback")

        try await run(RecipeEditorMutationPlan(queuedMutation: Self.mutation("cm_queued")))
        try await run(RecipeEditorMutationPlan(offlineFallbackMutation: fallback), queued: [Self.mutation("cm_earlier")])
        try await run(RecipeEditorMutationPlan())
        try await run(RecipeEditorMutationPlan(remoteRequestBuilder: Self.request, offlineFallbackMutation: fallback), queued: [Self.mutation("cm_elsewhere", recipeID: "recipe_other")])
        try await run(RecipeEditorMutationPlan(remoteRequestBuilder: Self.request, offlineFallbackMutation: fallback), failing: Self.offline)
        try await run(RecipeEditorMutationPlan(remoteRequestBuilder: Self.request, offlineFallbackMutation: fallback), failing: Self.editConflictError)
        #expect(log.calls == [
            "queue cm_queued",
            "batch [\"cm_fallback\"] true",
            "send",
            "send", "queue cm_fallback",
            "send", "batch [\"cm_fallback\"] true",
        ])

        await #expect(throws: Self.offline) { try await run(RecipeEditorMutationPlan(remoteRequestBuilder: Self.request), failing: Self.offline) }
        await #expect(throws: Self.editConflictError) { try await run(RecipeEditorMutationPlan(remoteRequestBuilder: Self.request), failing: Self.editConflictError) }
    }

    // MARK: Held-change banner

    @Test("the held-change banner names a conflict, or an edit the server turned down")
    func heldChangeCopy() {
        #expect(NativeRecipeEditConflict.heldChangeTitle(Self.editConflict) == "This recipe changed somewhere else")
        #expect(NativeRecipeEditConflict.heldChangeTitle(nil) == "A change to this recipe was not saved")
        #expect(NativeRecipeEditConflict.heldChangeMessage(Self.editConflict, serverMessage: "No") == NativeRecipeEditConflict.choicePrompt)
        #expect(NativeRecipeEditConflict.heldChangeMessage(nil, serverMessage: "No") == "No")
    }

    // MARK: Search

    @Test("a search run is a page, cancelled, or a failure, and Search shows each")
    func searchRun() async throws {
        let state = SearchState(query: "basil", scope: .all)
        let page = SearchSurfacePage(query: "basil", scope: .all, limit: 20, isAuthenticated: true, results: [], source: .live(requestID: "req", validatedAt: Date(timeIntervalSince1970: 0)))
        let found = await SearchSurfaceRun.run(state, in: Search(outcome: .success(page)))
        #expect(found == .page(page))
        #expect(await SearchSurfaceRun.run(state, in: Search(outcome: .failure(SearchSurfaceRepositoryError.cancelled))) == .cancelled)
        #expect(await SearchSurfaceRun.run(state, in: Search(outcome: .failure(SearchSurfaceRepositoryError.offline))) == .failed(.offline))
        #expect(await SearchSurfaceRun.run(state, in: Search(outcome: .failure(Self.offline))) == .failed(.searchFailed(message: String(describing: Self.offline))))
        #expect(SearchSurfaceRun.limit == 20)

        let content = Self.content()
        #expect(content.searchSurfaceViewModel(after: .cancelled, state: state, cachedPage: nil) == nil)
        #expect(content.searchSurfaceViewModel(after: found, state: state, cachedPage: nil)?.state.query == "basil")
        #expect(content.searchSurfaceViewModel(after: .failed(.offline), state: state, cachedPage: nil)?.errorState != nil)
    }

    // MARK: Catalogs

    @Test("Everyone's catalog falls back to this device's, and My Recipes lists the loaded recipes it holds")
    @MainActor
    func catalogs() async throws {
        let content = Self.content(auth: .authenticated(try Self.session(accountID: "chef_ari")))
        let everyone = RecipeCatalogViewModel(repository: content.everyoneRecipeCatalogRepository(live: FailingCatalog()))
        try await everyone.load(query: nil, limit: 48)
        #expect(everyone.state.rows.map(\.id) == content.recipeCatalog.rows.map(\.id))
        let mine = RecipeCatalogViewModel(repository: content.personalRecipeCatalogRepository(page: content.myRecipesCatalog))
        try await mine.load(query: nil, limit: 48)
        #expect(mine.state.rows.map(\.id) == ["recipe_lemon_pantry_pasta"])
    }

    // MARK: Recipe page progress

    @Test("the recipe page's scale and checks are saved per recipe and drop checks on ingredients it no longer has")
    func recipePageProgress() throws {
        let defaults = try #require(UserDefaults(suiteName: "recipe-page-progress-\(UUID().uuidString)"))
        let store = RecipePageProgressStore(defaults: defaults)
        let screen = RecipeDetailScreenViewModel(
            result: RecipeCatalogDetailResult(recipe: Self.recipe, source: Self.content().recipeCatalog.source),
            context: RecipeDetailContext(currentChefID: nil, availableCookbooks: [], savedInCookbookIDs: [], hasIngredientsInShoppingList: false, now: Date(timeIntervalSince1970: 0))
        )
        #expect(store.checks(for: screen) == .cleared)
        var progress = RecipePageChecks.cleared
        progress.scaleFactor = 1.5
        progress.toggleIngredient("ingredient_spaghetti")
        progress.toggleIngredient("ingredient_gone")
        progress.toggleIngredient("ingredient_gone")
        let dependency = try #require(screen.stepSections.flatMap(\.dependencies).first?.id)
        progress.checkedStepDependencyIDs = ["dependency_gone", dependency]
        #expect(progress.checkedIngredientIDs == ["ingredient_spaghetti"])
        progress.toggleIngredient("ingredient_ghost")
        store.save(progress, recipeID: screen.id, updatedAt: Self.now())
        #expect(store.checks(for: screen) == RecipePageChecks(scaleFactor: 1.5, checkedIngredientIDs: ["ingredient_spaghetti"], checkedStepDependencyIDs: [dependency]))
        #expect(progress.snapshot(updatedAt: "t").checkedIngredientIDs == ["ingredient_ghost", "ingredient_spaghetti"])
    }

    @Test("a pasted link becomes a link capture draft; a link the importer refuses makes none")
    func pastedLink() throws {
        let url = try #require(URL(string: "https://example.com/recipes/soup"))
        let draft = try #require(CaptureDraft.pastedLink(url, createdAt: Date(timeIntervalSince1970: 0), id: "paste-1"))
        #expect(draft.id == "paste-1")
        #expect(draft.previewLines.contains { $0.contains("https://example.com/recipes/soup") })
        let fixed = Date(timeIntervalSince1970: 1_780_000_000)
        #expect(CaptureDraft.pastedLink(try #require(URL(string: "file:///etc/hosts")), createdAt: fixed) == nil)
        #expect(CaptureDraft.pastedLink(url, createdAt: fixed)?.id.hasPrefix("paste-") == true)
    }

    // MARK: Editor edits

    @Test("the editor's small edits: paste, Return in a name, add a row, and where Cancel goes")
    func draftEditing() {
        var counter = 0
        let rows = RecipeEditorIngredientDraft.pasted("2 large eggs\n1 tbsp soy sauce") {
            counter += 1
            return "local_\(counter)"
        }
        #expect(rows.map(\.id) == ["local_1", "local_2"])
        #expect(rows.map(\.name) == ["eggs", "soy sauce"])
        var unnamed = rows
        unnamed[1].name = "  "
        #expect(RecipeEditorIngredientDraft.addable(unnamed).map(\.id) == ["local_1"])

        var row = RecipeEditorIngredientDraft(id: "r", name: "", quantity: 1, unit: nil)
        #expect(row.typeName("2 cups rice") == false)
        #expect(row.name == "2 cups rice")
        #expect(row.typeName("2 cups rice\n") == true)
        #expect(row == RecipeEditorIngredientDraft(id: "r", name: "rice", quantity: 2, unit: "cup"))

        var draft = Self.editor().draft
        #expect(draft.exitRoute == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        draft.addIngredient(id: "local_new", toStep: "step_finish")
        #expect(draft.steps[1].ingredients.last == RecipeEditorIngredientDraft(id: "local_new", name: "", quantity: 1, unit: nil))
        let unchanged = draft
        draft.addIngredients(rows, toStep: "step_missing")
        #expect(draft == unchanged)
        draft.addIngredients(rows, toStep: "step_boil")
        #expect(draft.steps[0].ingredients.suffix(2).map(\.id) == ["local_1", "local_2"])
        #expect(RecipeEditorDraft.blank(currentChefID: "chef_ari").exitRoute == .recipes)
    }

    @Test("the Serves stepper stops at the ends of its range")
    func servesStepping() {
        let serves = RecipeServes(servings: "4")
        #expect(serves.steppedUp(1) == serves.incremented(1))
        #expect(serves.steppedDown(1) == serves.decremented(1))
        #expect(serves.steppedUp(RecipeServes.maximumScale) == RecipeServes.maximumScale)
        #expect(serves.steppedDown(RecipeServes.minimumScale) == RecipeServes.minimumScale)
    }
}

// MARK: - Fixtures

extension RecipeEditorSessionTests {
    static let request = APIRequestBuilder(method: .patch, pathComponents: ["api", "v1", "recipes", "recipe_lemon_pantry_pasta"], queryItems: [])
    static let offline = APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .retrySameRequest(afterSeconds: nil))
    static let editConflictError = APITransportError(
        kind: .apiError,
        requestID: "req",
        statusCode: 409,
        apiError: APIError(requestID: "req", code: NativeRecipeServerVersion.editConflictCode, message: "Changed", status: 409),
        retryDecision: .doNotRetry
    )
    static let editConflict = NativeRecipeEditConflict(
        fields: [NativeRecipeEditConflict.Field(field: .title, mine: "Mine", theirs: "Theirs")],
        unconflicted: [],
        server: NativeRecipeServerVersion(fields: NativeRecipeFields(title: "Theirs", description: nil, servings: nil), updatedAt: "2026-06-26T00:00:00.000Z")
    )

    static func mutation(_ id: String, recipeID: String = "recipe_lemon_pantry_pasta") -> NativeQueuedMutation {
        NativeQueuedMutation.recipeUpdate(recipeID: recipeID, clientMutationID: id, title: "T", description: nil, servings: nil, createdAt: now())
    }

    static func conflict(_ id: String) -> NativeSyncConflict {
        NativeSyncConflict(clientMutationID: id, kind: .validation, serverRevision: nil, message: "Turned down")
    }

    static func result(conflicts: [NativeSyncConflict] = [], drained: [String] = [], remaining: [String] = []) -> NativeQueuedMutationBatchResult {
        NativeQueuedMutationBatchResult(submittedClientMutationIDs: drained + remaining, drainedClientMutationIDs: drained, remainingSubmittedClientMutationIDs: remaining, submittedConflicts: conflicts)
    }

    static func session(accountID: String) throws -> AuthSession {
        try AuthSession(clientID: "cm_native_spoonjoy", accessToken: "sj_access", refreshToken: "ort_refresh", tokenType: "Bearer", expiresAt: Date(timeIntervalSince1970: 4_000_000_000), scope: NativeAuthSession.defaultScope, accountID: accountID)
    }

    static func content(auth: NativeAuthSessionState = .signedOut, queued: [NativeQueuedMutation] = [], conflicts: [NativeSyncConflict] = []) -> NativeShellContentState {
        NativeShellContentState.empty(
            authSessionState: auth,
            environment: .production,
            configuration: APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!),
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        .copy(recipes: [recipe], queuedMutations: queued, syncConflicts: conflicts)
    }

    static func editor() -> RecipeEditorViewModel {
        RecipeEditorViewModel(mode: .edit(recipe: recipe, currentChefID: "chef_ari"), connectivity: .online, now: now)
    }

    static let recipe = Recipe(
        id: "recipe_lemon_pantry_pasta",
        title: "Lemon Pantry Pasta",
        description: "Bright pantry pasta.",
        servings: "4",
        chef: ChefSummary(id: "chef_ari", username: "ari"),
        coverImageURL: nil,
        coverProvenanceLabel: nil,
        coverSourceType: nil,
        coverVariant: nil,
        href: "/recipes/recipe_lemon_pantry_pasta",
        canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta")!,
        attribution: RecipeAttribution(
            creditText: "Lemon Pantry Pasta by ari on Spoonjoy",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta")!,
            sourceURLRaw: nil,
            sourceHost: nil,
            sourceRecipe: nil
        ),
        createdAt: "2026-06-25T12:00:00.000Z",
        updatedAt: "2026-06-25T12:20:00.000Z",
        steps: [
            RecipeStep(id: "step_boil", stepNum: 1, stepTitle: "Boil pasta", description: "Boil spaghetti.", duration: 10, ingredients: [
                RecipeIngredient(id: "ingredient_spaghetti", name: "spaghetti", quantity: 1, unit: "lb"),
            ]),
            RecipeStep(id: "step_finish", stepNum: 2, stepTitle: "Finish", description: "Toss with lemon.", duration: 3, ingredients: [
                RecipeIngredient(id: "ingredient_lemon", name: "lemon", quantity: 1, unit: "each"),
            ], usingSteps: [
                RecipeStepOutputUse(id: "use_boil", inputStepNum: 2, outputStepNum: 1, outputOfStep: RecipeStepOutputReference(stepNum: 1, stepTitle: "Boil pasta")),
            ]),
        ],
        cookbooks: []
    )
}

@MainActor
private final class Log {
    var calls: [String] = []
}

private struct Search: SearchSurfaceRepository {
    let outcome: Result<SearchSurfacePage, any Error>

    func search(request _: SearchSurfaceRequest) async throws -> SearchSurfacePage {
        try outcome.get()
    }

    func recentSearches(limit _: Int) async throws -> [SearchSurfaceRecentQuery] { [] }
}

private struct FailingCatalog: RecipeCatalogRepository {
    func listRecipes(request _: RecipeCatalogListRequest) async throws -> RecipeCatalogPage {
        throw APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .retrySameRequest(afterSeconds: nil))
    }

    func recipeDetail(id _: String) async throws -> RecipeCatalogDetailResult {
        throw APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .retrySameRequest(afterSeconds: nil))
    }
}
