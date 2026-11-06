import Foundation
import OuroReins
import SpoonjoyCore

/// The recipe editors open, by visit. What the two share is the rule for which visit a draft belongs to and how long it
/// lives: `AppNavigationState.editorIdentity(for:)` and `SpoonjoyShell.openEditorIdentities`, both in Core. The app
/// keeps each draft in the editor view's `@State` under `.id(navigation.editorIdentity(for:))`, so SwiftUI holds it
/// while that identity stays on a stack; here `RecipeEditorVisits` stands in for that `@State` and is pruned to the
/// same identities. That SwiftUI keeps the state for a live identity is SwiftUI's guarantee, not tested here. The rest
/// is what the editor view keeps in `@State` over it: the paste sheet, the discard question, a refusal and a conflict
/// the server answered.
public struct SpoonjoyReinsEditorPages {
    public internal(set) var visits = RecipeEditorVisits()
    var scratch: [String: SpoonjoyReinsEditorScratch] = [:]

    mutating func close(_ identity: String) {
        scratch[identity] = nil
        visits.keep(only: visits.identities.subtracting([identity]))
    }
}

struct SpoonjoyReinsEditorScratch {
    /// The step the paste sheet is open on, its text and the rows it parsed.
    var pasteStepID: String?
    var pasteText = ""
    var pasteRows: [RecipeEditorIngredientDraft] = []
    /// Where Cancel was going when the editor asked to discard the changes.
    var pendingExit: AppRoute?
    var blockedMessage: String?
    var runtimeConflict: RecipeEditorConflict?
}

struct EditorText: ReinsInput { let text: String }
struct EditorStepText: ReinsInput { let step: Int; let text: String }
struct EditorStep: ReinsInput { let step: Int }
struct EditorIngredientText: ReinsInput { let step: Int; let ingredient: Int; let text: String }

extension SpoonjoyReinsShell {
    /// The editor plans offline while the shell shows it is offline (`PlatformNavigationView.recipeEditorConnectivity`).
    var editorConnectivity: RecipeEditorConnectivity {
        RecipeEditorConnectivity(display: store.offlineIndicatorState.display)
    }

    func editorNode(_ id: String?) -> ReinsNode {
        let route = AppRoute.recipeEditor(id: id)
        let identity = navigation.editorIdentity(for: route)
        guard let viewModel = content.recipeEditorViewModel(id: id, connectivity: editorConnectivity, now: timestamp) else {
            return notFoundNode(route)
        }
        let visit = page.editors.visits.open(identity, with: viewModel)
        let scratch = page.editors.scratch[identity] ?? SpoonjoyReinsEditorScratch()
        // `RecipeEditorView.liveViewModel` and `activeViewModel`.
        let live = viewModel.keepingRecipe(of: visit.opened)
        let active = scratch.runtimeConflict.map { live.replacingConflict($0) } ?? live
        let draft = visit.draft
        let editor = active.updatingDraft(draft)

        var state: [String: ReinsValue] = [
            "mode": id == nil ? "create" : "edit",
            "id": id.map(ReinsValue.string) ?? .null,
            "title": .string(draft.title),
            "servings": draft.servings.map(ReinsValue.string) ?? .null,
            "connectivity": .string(editor.connectivity == .online ? "online" : "offline"),
            "canSave": .bool(editor.canSubmit),
            "hasChanges": .bool(draft != live.draft),
            "steps": .array(draft.steps.map { step in
                [
                    "number": .number(Double(step.stepNum)),
                    "title": step.title.map(ReinsValue.string) ?? .null,
                    "description": .string(step.description),
                    "ingredients": .array(step.ingredients.map(Self.ingredientValue)),
                ]
            }),
            "blocked": scratch.blockedMessage.map(ReinsValue.string) ?? .null,
            "conflict": active.conflictBanner.map { ["title": .string($0.title), "message": .string($0.message)] } ?? .null,
        ]

        // The paste sheet covers the editor until it adds or cancels.
        if let stepID = scratch.pasteStepID, let step = draft.steps.first(where: { $0.id == stepID }) {
            state["paste"] = [
                "step": .number(Double(step.stepNum)),
                "text": .string(scratch.pasteText),
                "rows": .array(scratch.pasteRows.map(Self.ingredientValue)),
            ]
            var actions = [
                ReinsAction("setPasteText", "Paste ingredient text, one per line", input: EditorText.self) { [unowned self] in
                    self.setPasteText($0.text, identity: identity)
                },
                ReinsAction("cancelPaste", "Cancel the paste") { [unowned self] in self.editScratch(identity) { $0.pasteStepID = nil } },
            ]
            if !scratch.pasteRows.isEmpty {
                actions.append(ReinsAction("addPasted", "Add the parsed ingredients to the step") { [unowned self] in
                    self.addPasted(identity: identity)
                })
            }
            return ReinsNode("editor", state: .object(state), child: ReinsNode("paste", state: state["paste"]!, actions: actions))
        }

        // Cancel with unsaved changes asks first, and nothing else on the page can be reached until it's answered.
        if let exit = scratch.pendingExit {
            state["confirm"] = ["title": "Discard your changes?", "choices": ["Discard Changes", "Keep Editing"]]
            return ReinsNode("editor", state: .object(state), actions: [
                ReinsAction("discard", "Discard Changes") { [unowned self] in self.closeEditor(identity, to: exit) },
                ReinsAction("keepEditing", "Keep Editing") { [unowned self] in self.editScratch(identity) { $0.pendingExit = nil } },
            ])
        }

        let stepSchema = ReinsSchema.object(properties: ["step": .integer], required: ["step"])
        var actions = [
            ReinsAction("setTitle", "Change the title", input: EditorText.self) { [unowned self] input in
                self.editDraft(identity) { $0.title = input.text }
            },
            ReinsAction("setServings", "Change the servings", input: EditorText.self) { [unowned self] input in
                self.editDraft(identity) { $0.servings = input.text.isEmpty ? nil : input.text }
            },
            ReinsAction("setStepTitle", "Change a step's title", input: EditorStepText.self) { [unowned self] input in
                self.editStep(identity, input.step) { $0.title = input.text }
            },
            ReinsAction("moveStepUp", "Move a step up", input: EditorStep.self) { [unowned self] input in
                self.moveStep(identity, input.step, by: -1)
            }.narrowed(stepSchema),
            ReinsAction("moveStepDown", "Move a step down", input: EditorStep.self) { [unowned self] input in
                self.moveStep(identity, input.step, by: 1)
            }.narrowed(stepSchema),
            ReinsAction("pasteIngredients", "Paste ingredients into a step", input: EditorStep.self) { [unowned self] input in
                guard let step = self.step(identity, input.step) else { return }
                self.editScratch(identity) { $0.pasteStepID = step.id; $0.pasteText = ""; $0.pasteRows = [] }
            }.narrowed(stepSchema),
            ReinsAction("addIngredient", "Add an ingredient to a step", input: EditorStep.self) { [unowned self] input in
                guard let step = self.step(identity, input.step) else { return }
                self.editDraft(identity) { $0.addIngredient(id: "local_ingredient_\(UUID().uuidString.lowercased())", toStep: step.id) }
            }.narrowed(stepSchema),
            ReinsAction("typeIngredient", "Type into an ingredient's name; end with a newline to press Return", input: EditorIngredientText.self) { [unowned self] input in
                self.typeIngredient(identity, input)
            },
            ReinsAction("cancel", "Cancel") { [unowned self] in self.cancelEditor(identity) },
        ]
        if editor.canSubmit {
            actions.append(ReinsAction("save", "Save") { [unowned self] in await self.saveEditor(identity) })
        }
        return ReinsNode("editor", state: .object(state), actions: actions)
    }

    private static func ingredientValue(_ ingredient: RecipeEditorIngredientDraft) -> ReinsValue {
        [
            "name": .string(ingredient.name),
            "quantity": .string(RecipeQuantity.format(ingredient.quantity)),
            "unit": ingredient.unit.map(ReinsValue.string) ?? .null,
        ]
    }

    // MARK: The editor's handlers (RecipeEditorView), over the visit's draft

    private func editScratch(_ identity: String, _ change: (inout SpoonjoyReinsEditorScratch) -> Void) {
        var scratch = page.editors.scratch[identity] ?? SpoonjoyReinsEditorScratch()
        change(&scratch)
        page.editors.scratch[identity] = scratch
    }

    private func editDraft(_ identity: String, _ change: (inout RecipeEditorDraft) -> Void) {
        guard var visit = page.editors.visits[identity] else { return }
        change(&visit.draft)
        page.editors.visits.record(visit, for: identity)
    }

    private func step(_ identity: String, _ number: Int) -> RecipeEditorStepDraft? {
        page.editors.visits[identity]?.draft.steps.first { $0.stepNum == number }
    }

    private func editStep(_ identity: String, _ number: Int, _ change: (inout RecipeEditorStepDraft) -> Void) {
        editDraft(identity) { draft in
            guard let index = draft.steps.firstIndex(where: { $0.stepNum == number }) else { return }
            change(&draft.steps[index])
        }
    }

    private func moveStep(_ identity: String, _ number: Int, by offset: Int) {
        guard let step = step(identity, number) else { return }
        var outcome: RecipeEditorMoveOutcome?
        editDraft(identity) { outcome = $0.moveStep(id: step.id, by: offset) }
        // `RecipeEditorView.showMoveOutcome`.
        editScratch(identity) { scratch in
            if case .blocked(let message)? = outcome {
                scratch.blockedMessage = message
            } else {
                scratch.blockedMessage = nil
            }
        }
    }

    private func setPasteText(_ text: String, identity: String) {
        editScratch(identity) { scratch in
            scratch.pasteText = text
            scratch.pasteRows = RecipeEditorIngredientDraft.pasted(text) { "local_ingredient_\(UUID().uuidString.lowercased())" }
        }
    }

    private func addPasted(identity: String) {
        guard let scratch = page.editors.scratch[identity], let stepID = scratch.pasteStepID else { return }
        editDraft(identity) { $0.addIngredients(RecipeEditorIngredientDraft.addable(scratch.pasteRows), toStep: stepID) }
        editScratch(identity) { $0.pasteStepID = nil }
    }

    private func typeIngredient(_ identity: String, _ input: EditorIngredientText) {
        editStep(identity, input.step) { step in
            let index = input.ingredient - 1
            guard step.ingredients.indices.contains(index) else { return }
            step.ingredients[index].typeName(input.text)
        }
    }

    /// `RecipeEditorView.leave(to:)`: Cancel asks first when there is work that would be lost.
    private func cancelEditor(_ identity: String) {
        guard let visit = page.editors.visits[identity] else { return }
        let live = (content.recipeEditorViewModel(id: visit.draft.recipeID, connectivity: editorConnectivity, now: timestamp) ?? visit.opened)
            .keepingRecipe(of: visit.opened)
        if visit.draft != live.draft {
            editScratch(identity) { $0.pendingExit = visit.draft.exitRoute }
        } else {
            closeEditor(identity, to: visit.draft.exitRoute)
        }
    }

    /// The editor's `close`, which is the shell's `openRoute`: the editor leaves the stack, and its visit ends.
    private func closeEditor(_ identity: String, to route: AppRoute) {
        page.editors.close(identity)
        navigate(to: route)
    }

    /// `RecipeEditorView.save()` and `plan(_:)`: the draft's changes become one submission, sent the way the shell
    /// sends it (`PlatformNavigationView.handleRecipeEditorPlan`, through `RecipeEditorPlanRunner`).
    private func saveEditor(_ identity: String) async {
        guard let visit = page.editors.visits[identity],
              let viewModel = content.recipeEditorViewModel(id: visit.draft.recipeID, connectivity: editorConnectivity, now: timestamp) else {
            return
        }
        let scratch = page.editors.scratch[identity] ?? SpoonjoyReinsEditorScratch()
        let live = viewModel.keepingRecipe(of: visit.opened)
        let active = scratch.runtimeConflict.map { live.replacingConflict($0) } ?? live
        // The app stamps each ID with the second it saved in; the journey clock stands still, so a save also gets a
        // nonce, keeping two saves in one journey apart.
        let stamp = "\(Int(fixtures.now().timeIntervalSince1970))-\(UUID().uuidString.prefix(8).lowercased())"
        let actions = RecipeEditorDraftChangePlanner.actions(original: live.draft, draft: visit.draft) { "\($0)-\(stamp)" }
        let editor = active.updatingDraft(visit.draft)
        do {
            let submission = try editor.submission(for: actions)
            switch submission.kind {
            case .blocked(let reason):
                editScratch(identity) { $0.blockedMessage = reason }
                return
            case .nothing:
                break
            case .batch(let mutations, let drainImmediately):
                let result = try await store.queueMutations(mutations, drainImmediately: drainImmediately)
                if drainImmediately {
                    let attention = RecipeEditorBatchAttention(after: result, mutations: mutations, recipeID: visit.draft.recipeID)
                    if attention != .none {
                        editScratch(identity) { scratch in
                            if case .conflict(let conflict) = attention { scratch.runtimeConflict = conflict }
                            scratch.blockedMessage = attention.message
                        }
                        return
                    }
                }
            case .single(_, let plan):
                try await RecipeEditorPlanRunner.perform(
                    plan,
                    queuedMutations: content.queuedMutations,
                    queueMutation: { try await self.store.queueMutation($0) },
                    queueMutations: { try await self.store.queueMutations($0, drainImmediately: $1) },
                    execute: { try await self.store.executeRecipeEditorRequest($0) }
                )
            }
            if let route = submission.successRoute {
                closeEditor(identity, to: route)
            } else {
                editScratch(identity) { $0.blockedMessage = nil }
            }
        } catch {
            editScratch(identity) { $0.blockedMessage = String(describing: error) }
        }
    }
}
