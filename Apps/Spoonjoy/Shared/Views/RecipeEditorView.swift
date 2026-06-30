import Foundation
import SpoonjoyCore
import SwiftUI

struct RecipeEditorView: View {
    let viewModel: RecipeEditorViewModel
    let mutationDidPlan: @MainActor @Sendable (RecipeEditorMutationPlan) async throws -> Void
    let mutationsDidQueue: @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult
    let conflictDidDiscardLocalChange: @MainActor @Sendable (RecipeEditorConflict) async throws -> Void
    let close: @MainActor @Sendable (AppRoute) -> Void
    let shellOfflineIndicatorState: OfflineIndicatorState?
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var draft: RecipeEditorDraft
    @State private var blockedMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var isSubmitting = false
    @State private var conflictOverride = false
    @State private var runtimeConflict: RecipeEditorConflict?
    @State private var offlineDisplayOverride: OfflineIndicatorDisplay?

    init(
        viewModel: RecipeEditorViewModel,
        mutationDidPlan: @escaping @MainActor @Sendable (RecipeEditorMutationPlan) async throws -> Void,
        mutationsDidQueue: @escaping @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        conflictDidDiscardLocalChange: @escaping @MainActor @Sendable (RecipeEditorConflict) async throws -> Void,
        close: @escaping @MainActor @Sendable (AppRoute) -> Void,
        shellOfflineIndicatorState: OfflineIndicatorState? = nil,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.mutationDidPlan = mutationDidPlan
        self.mutationsDidQueue = mutationsDidQueue
        self.conflictDidDiscardLocalChange = conflictDidDiscardLocalChange
        self.close = close
        self.shellOfflineIndicatorState = shellOfflineIndicatorState
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _draft = State(initialValue: viewModel.draft)
    }

    var body: some View {
        Form {
            if let blockedMessage {
                Label(blockedMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(KitchenTableTheme.tomato)
            }

            if let conflictBanner = activeViewModel.conflictBanner {
                Section("Conflict") {
                    Text(conflictBanner.title)
                        .font(.headline)
                    Text(conflictBanner.message)
                        .font(KitchenTableTheme.bodyNote)
                    HStack {
                        Button("Review") {
                            reviewConflict()
                        }
                        Button(conflictBanner.discardActionTitle) {
                            Task {
                                await discardLocalChange()
                            }
                        }
                    }
                }
            }

            Section("Recipe") {
                TextField("Title", text: $draft.title)
                TextEditor(text: descriptionText)
                    .frame(minHeight: 88)
                TextField("Servings", text: servingsText)
            }

            Section("Steps") {
                ForEach($draft.steps) { $step in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Step \(step.stepNum)")
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                removeStep(id: step.id)
                            } label: {
                                Label("Delete Step", systemImage: "trash")
                            }
                            .labelStyle(.iconOnly)
                            .disabled(isSubmitting)
                        }

                        TextField("Step title", text: optionalText($step.title))
                        TextEditor(text: $step.description)
                            .frame(minHeight: 72)
                        Stepper(value: durationBinding($step.duration), in: 0...7200, step: 30) {
                            Text("Duration \(step.duration ?? 0) seconds")
                        }

                        let priorSteps = priorSteps(for: step)
                        if !priorSteps.isEmpty {
                            DisclosureGroup("Uses Output From") {
                                ForEach(priorSteps) { priorStep in
                                    Toggle(
                                        "Step \(priorStep.stepNum)",
                                        isOn: outputUseBinding($step.outputStepNums, outputStepNum: priorStep.stepNum)
                                    )
                                }
                            }
                        }

                        ForEach($step.ingredients) { $ingredient in
                            HStack {
                                TextField("Ingredient", text: $ingredient.name)
                                TextField("Quantity", value: $ingredient.quantity, format: .number.precision(.fractionLength(0...3)))
                                    .frame(minWidth: 72)
                                TextField("Unit", text: optionalText($ingredient.unit))
                                Button(role: .destructive) {
                                    removeIngredient(id: ingredient.id, from: step.id)
                                } label: {
                                    Label("Delete Ingredient", systemImage: "minus.circle")
                                }
                                .labelStyle(.iconOnly)
                                .disabled(isSubmitting)
                            }
                        }

                        Button {
                            addIngredient(to: step.id)
                        } label: {
                            Label("Add Ingredient", systemImage: "plus.circle")
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(.vertical, 6)
                }
                .onMove { indices, newOffset in
                    draft.steps.move(fromOffsets: indices, toOffset: newOffset)
                    renumberSteps()
                }

                Button {
                    addStep()
                } label: {
                    Label("Add Step", systemImage: "plus.circle")
                }
                .disabled(isSubmitting)
            }

            Section {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Label("Save", systemImage: "checkmark.circle")
                    }
                }
                .disabled(!activeViewModel.updatingDraft(draft).canSubmit || isSubmitting)

                if draft.recipeID != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .confirmationDialog(activeViewModel.deleteConfirmationTitle, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Recipe", role: .destructive) {
                Task {
                    await deleteRecipe()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .safeAreaInset(edge: .bottom) {
            OfflineStatusView(display: offlineDisplayOverride ?? effectiveOfflineIndicator(activeViewModel.offlineIndicator.display), onDismiss: onDismissOfflineIndicator)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .background(KitchenTableTheme.bone.opacity(0.94))
        }
    }

    private func effectiveOfflineIndicator(_ localDisplay: OfflineIndicatorDisplay) -> OfflineIndicatorDisplay {
        guard let shellOfflineIndicatorState,
              localDisplay.informationalOnly,
              !shellOfflineIndicatorState.display.informationalOnly
        else {
            return localDisplay
        }
        return shellOfflineIndicatorState.display
    }

    private var activeViewModel: RecipeEditorViewModel {
        if let runtimeConflict {
            return viewModel.replacingConflict(runtimeConflict)
        }
        if conflictOverride {
            return viewModel.replacingConflict(nil)
        }
        return viewModel
    }

    private var descriptionText: Binding<String> {
        optionalText($draft.description)
    }

    private var servingsText: Binding<String> {
        optionalText($draft.servings)
    }

    private func optionalText(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { nextValue in
                value.wrappedValue = optionalString(nextValue)
            }
        )
    }

    private func durationBinding(_ value: Binding<Int?>) -> Binding<Int> {
        Binding(
            get: { value.wrappedValue ?? 0 },
            set: { nextValue in
                value.wrappedValue = nextValue == 0 ? nil : nextValue
            }
        )
    }

    @MainActor private func save() async {
        let actions = RecipeEditorDraftChangePlanner.actions(
            original: viewModel.draft,
            draft: draft,
            clientMutationID: clientMutationID
        )
        await plan(actions)
    }

    @MainActor private func deleteRecipe() async {
        await plan([.deleteRecipe(clientMutationID: clientMutationID("recipe-delete"), confirmation: .confirmed)])
    }

    @MainActor private func plan(_ actions: [RecipeEditorAction]) async {
        guard !isSubmitting else {
            return
        }

        isSubmitting = true
        defer {
            isSubmitting = false
        }

        do {
            let editor = activeViewModel.updatingDraft(draft)
            var plannedActions: [(action: RecipeEditorAction, plan: RecipeEditorMutationPlan)] = []

            for action in actions {
                let plan = try editor.plan(action)
                if let blockedReason = plan.blockedReason {
                    blockedMessage = blockedReason
                    return
                }
                plannedActions.append((action, plan))
            }

            if plannedActions.count > 1 {
                let mutations = try plannedActions.map { plannedAction in
                    guard let mutation = plannedAction.plan.queuedMutation ?? plannedAction.plan.offlineFallbackMutation else {
                        throw RecipeEditorPlanningError.missingQueuedMutation
                    }
                    return mutation
                }
                let batchResult = try await mutationsDidQueue(mutations, editor.connectivity == .online)
                if editor.connectivity == .online,
                   submittedBatchNeedsAttention(batchResult, mutations: mutations) {
                    return
                }
            } else if let plannedAction = plannedActions.first {
                do {
                    try await mutationDidPlan(plannedAction.plan)
                } catch {
                    throw RecipeEditorActionExecutionError(action: plannedAction.action, underlyingError: error)
                }
            }

            blockedMessage = nil
            offlineDisplayOverride = nil
            let successRoute = plannedActions.compactMap(\.plan.successRoute).last
            if let successRoute {
                close(successRoute)
            }
        } catch let error as RecipeEditorActionExecutionError {
            blockedMessage = message(for: error.underlyingError, action: error.action)
        } catch {
            blockedMessage = message(for: error, action: nil)
        }
    }

    private func addStep() {
        draft.steps.append(RecipeEditorStepDraft(
            id: localID("local_step"),
            stepNum: draft.steps.count + 1,
            title: nil,
            description: "",
            duration: nil,
            ingredients: [],
            outputStepNums: []
        ))
        renumberSteps()
    }

    private func removeStep(id: String) {
        draft.steps.removeAll { $0.id == id }
        renumberSteps()
    }

    private func priorSteps(for step: RecipeEditorStepDraft) -> [RecipeEditorStepDraft] {
        draft.steps
            .filter { $0.stepNum < step.stepNum }
            .sorted { $0.stepNum < $1.stepNum }
    }

    private func outputUseBinding(_ outputStepNums: Binding<[Int]>, outputStepNum: Int) -> Binding<Bool> {
        Binding(
            get: {
                outputStepNums.wrappedValue.contains(outputStepNum)
            },
            set: { isOn in
                var values = outputStepNums.wrappedValue.filter { $0 != outputStepNum }
                if isOn {
                    values.append(outputStepNum)
                }
                outputStepNums.wrappedValue = values.sorted()
            }
        )
    }

    private func submittedBatchNeedsAttention(
        _ result: NativeQueuedMutationBatchResult,
        mutations: [NativeQueuedMutation]
    ) -> Bool {
        if let conflict = result.submittedConflicts.first {
            let mutation = mutations.first { $0.clientMutationID == conflict.clientMutationID }
            let resourceID = mutation?.recipeID ?? draft.recipeID ?? conflict.clientMutationID
            runtimeConflict = RecipeEditorConflict(
                resourceID: resourceID,
                serverRevision: conflict.serverRevision,
                localClientMutationID: conflict.clientMutationID,
                message: conflict.message
            )
            offlineDisplayOverride = .conflict(recordID: resourceID, mutationID: conflict.clientMutationID)
            blockedMessage = conflict.message
            return true
        }

        guard !result.drainedClientMutationIDs.isEmpty,
              !result.remainingSubmittedClientMutationIDs.isEmpty else {
            return false
        }

        let remainingCount = result.remainingSubmittedClientMutationIDs.count
        blockedMessage = remainingCount == 1
            ? "One recipe edit is still queued. Review the offline status before leaving the editor."
            : "\(remainingCount) recipe edits are still queued. Review the offline status before leaving the editor."
        offlineDisplayOverride = .queuedWork(
            count: remainingCount,
            oldestClientMutationID: result.remainingSubmittedClientMutationIDs.first
        )
        return true
    }

    private func addIngredient(to stepID: String) {
        guard let stepIndex = draft.steps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        draft.steps[stepIndex].ingredients.append(RecipeEditorIngredientDraft(
            id: localID("local_ingredient"),
            name: "",
            quantity: 1,
            unit: nil
        ))
    }

    private func removeIngredient(id: String, from stepID: String) {
        guard let stepIndex = draft.steps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        draft.steps[stepIndex].ingredients.removeAll { $0.id == id }
    }

    private func renumberSteps() {
        draft.renumberStepsPreservingOutputIdentities()
    }

    @MainActor private func reviewConflict() {
        guard let conflict = activeViewModel.conflict else {
            return
        }
        close(routeAfterConflictExit(conflict))
    }

    @MainActor private func discardLocalChange() async {
        guard let conflict = activeViewModel.conflict else {
            return
        }

        do {
            try await conflictDidDiscardLocalChange(conflict)
            conflictOverride = true
            runtimeConflict = nil
            blockedMessage = nil
            offlineDisplayOverride = nil
            close(routeAfterConflictExit(conflict))
        } catch {
            blockedMessage = message(for: error, action: nil)
            offlineDisplayOverride = .syncFailure(errorID: "recipe-editor-conflict", retryAfter: nil)
        }
    }

    private func routeAfterConflictExit(_ conflict: RecipeEditorConflict) -> AppRoute {
        let resourceID = conflict.resourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resourceID.isEmpty else {
            return .recipes
        }
        return .recipeDetail(id: resourceID, presentation: .detail)
    }

    private func clientMutationID(_ prefix: String) -> String {
        "\(prefix)-\(Date().timeIntervalSince1970.formatted(.number.precision(.fractionLength(0))))"
    }

    private func localID(_ prefix: String) -> String {
        "\(prefix)_\(UUID().uuidString.lowercased())"
    }

    private func message(for error: Error, action: RecipeEditorAction?) -> String {
        if let transportError = error as? APITransportError {
            if transportError.statusCode == 409 {
                let mutationID = action?.clientMutationID ?? transportError.apiError?.requestID ?? "online-editor-conflict"
                runtimeConflict = RecipeEditorConflict(
                    resourceID: draft.recipeID ?? "",
                    serverRevision: conflictRevision(from: transportError),
                    localClientMutationID: mutationID,
                    message: transportError.apiError?.message ?? "This recipe changed elsewhere."
                )
                offlineDisplayOverride = .conflict(recordID: draft.recipeID ?? mutationID, mutationID: mutationID)
            } else if transportError.isOffline {
                offlineDisplayOverride = .offline
            } else {
                offlineDisplayOverride = .syncFailure(errorID: "recipe-editor", retryAfter: nil)
            }
            return transportError.apiError?.message ?? "Recipe editor action could not be saved."
        }

        offlineDisplayOverride = .syncFailure(errorID: "recipe-editor", retryAfter: nil)
        return "Recipe editor action could not be prepared."
    }

    private func conflictRevision(from error: APITransportError) -> NativeServerRevision? {
        if let etag = stringDetail("etag", in: error) ?? stringDetail("serverRevision", in: error) {
            return .etag(etag)
        }
        if let updatedAt = stringDetail("updatedAt", in: error) ?? stringDetail("serverUpdatedAt", in: error) {
            return .updatedAt(updatedAt)
        }
        return nil
    }

    private func stringDetail(_ key: String, in error: APITransportError) -> String? {
        guard case .string(let value)? = error.apiError?.details[key],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private func optionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private typealias EditorSafetyControls = KitchenSafeControls
private struct ConfirmationDialogAnchor {}

private struct RecipeEditorActionExecutionError: Error {
    let action: RecipeEditorAction
    let underlyingError: Error
}
