import Foundation
import PhotosUI
import SpoonjoyCore
import SwiftUI
import UniformTypeIdentifiers

struct RecipeEditorView: View {
    let viewModel: RecipeEditorViewModel
    let mutationDidPlan: @MainActor @Sendable (RecipeEditorMutationPlan) async throws -> Void
    let mutationsDidQueue: @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult
    let conflictDidDiscardLocalChange: @MainActor @Sendable (RecipeEditorConflict) async throws -> Void
    /// Creates the recipe and uploads the chosen photo as its cover; returns the route to open next.
    let createRecipeWithPhoto: @MainActor @Sendable (RecipeEditorMutationPlan, NativeStagedMediaUpload) async throws -> AppRoute
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
    @State private var pasteStepID: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var stagedPhoto: NativeStagedMediaUpload?
    @State private var photoMessage: String?
#if os(iOS)
    @Environment(\.editMode) private var editMode: Binding<EditMode>?
#endif

    init(
        viewModel: RecipeEditorViewModel,
        mutationDidPlan: @escaping @MainActor @Sendable (RecipeEditorMutationPlan) async throws -> Void,
        mutationsDidQueue: @escaping @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        conflictDidDiscardLocalChange: @escaping @MainActor @Sendable (RecipeEditorConflict) async throws -> Void,
        createRecipeWithPhoto: @escaping @MainActor @Sendable (RecipeEditorMutationPlan, NativeStagedMediaUpload) async throws -> AppRoute,
        close: @escaping @MainActor @Sendable (AppRoute) -> Void,
        shellOfflineIndicatorState: OfflineIndicatorState? = nil,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.mutationDidPlan = mutationDidPlan
        self.mutationsDidQueue = mutationsDidQueue
        self.conflictDidDiscardLocalChange = conflictDidDiscardLocalChange
        self.createRecipeWithPhoto = createRecipeWithPhoto
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
                    .accessibilityIdentifier("editor.status")
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
                    .accessibilityIdentifier("editor.title")
                TextEditor(text: descriptionText)
                    .frame(minHeight: 88)
                TextField("Servings", text: servingsText)
                    .accessibilityIdentifier("editor.servings")
            }

            if draft.recipeID == nil {
                photoSection
            }

            Section("Steps") {
                ForEach($draft.steps) { $step in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Step \(step.stepNum)")
                                .font(.headline)
                            Spacer()
                            Button {
                                moveStep(id: step.id, by: -1)
                            } label: {
                                Label("Move Step Up", systemImage: "chevron.up")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .disabled(isSubmitting || step.stepNum == 1)
                            .accessibilityIdentifier("editor.step.\(step.stepNum).moveUp")
                            Button {
                                moveStep(id: step.id, by: 1)
                            } label: {
                                Label("Move Step Down", systemImage: "chevron.down")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .disabled(isSubmitting || step.stepNum == draft.steps.count)
                            .accessibilityIdentifier("editor.step.\(step.stepNum).moveDown")
                            Button(role: .destructive) {
                                removeStep(id: step.id)
                            } label: {
                                Label("Delete Step", systemImage: "trash")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .disabled(isSubmitting)
                        }

                        TextField("Step title", text: optionalText($step.title))
                            .accessibilityIdentifier("editor.step.\(step.stepNum).title")
                        TextEditor(text: $step.description)
                            .frame(minHeight: 72)
                            .accessibilityIdentifier("editor.step.\(step.stepNum).description")
                        Stepper(value: durationBinding($step.duration), in: 0...720, step: 1) {
                            Text("Duration \(step.duration ?? 0) minutes")
                        }

                        let priorSteps = priorSteps(for: step)
                        // Creating a recipe cannot store which steps use another step's output (the web API
                        // rejects that field on create), so output uses are offered once the recipe exists.
                        if draft.recipeID != nil, !priorSteps.isEmpty {
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
                            let ingredientID = "editor.step.\(step.stepNum).ingredient.\(ingredientNumber(ingredient.id, in: step))"
                            HStack {
                                TextField("Ingredient", text: $ingredient.name)
                                    .accessibilityIdentifier("\(ingredientID).name")
                                    // Typing a whole line such as "2 cups rice" and pressing return fills the quantity and unit.
                                    .onSubmit { $ingredient.wrappedValue.applyTypedLine() }
                                TextField("Quantity", value: $ingredient.quantity, format: .number.precision(.fractionLength(0...3)))
                                    .frame(minWidth: 72)
                                    .accessibilityIdentifier("\(ingredientID).quantity")
                                TextField("Unit", text: optionalText($ingredient.unit))
                                    .accessibilityIdentifier("\(ingredientID).unit")
                                Menu {
                                    Button {
                                        moveIngredient(id: ingredient.id, in: step.id, by: -1)
                                    } label: {
                                        Label("Move Up", systemImage: "arrow.up")
                                    }
                                    .disabled(ingredientNumber(ingredient.id, in: step) == 1)
                                    .accessibilityIdentifier("\(ingredientID).moveUp")
                                    Button {
                                        moveIngredient(id: ingredient.id, in: step.id, by: 1)
                                    } label: {
                                        Label("Move Down", systemImage: "arrow.down")
                                    }
                                    .disabled(ingredientNumber(ingredient.id, in: step) == step.ingredients.count)
                                    .accessibilityIdentifier("\(ingredientID).moveDown")
                                } label: {
                                    Label("Reorder Ingredient", systemImage: "arrow.up.arrow.down")
                                }
                                .labelStyle(.iconOnly)
                                .menuStyle(.borderlessButton)
                                .disabled(isSubmitting)
                                .accessibilityIdentifier("\(ingredientID).reorder")
                                Button(role: .destructive) {
                                    removeIngredient(id: ingredient.id, from: step.id)
                                } label: {
                                    Label("Delete Ingredient", systemImage: "minus.circle")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .disabled(isSubmitting)
                            }
                        }

                        Button {
                            addIngredient(to: step.id)
                        } label: {
                            Label("Add Ingredient", systemImage: "plus.circle")
                        }
                        // A step is one form row. With default-styled buttons, a tap anywhere in the row ran
                        // every button in it, Delete Step first, so Add Ingredient crashed on the removed step.
                        // Borderless buttons each handle only their own taps.
                        .buttonStyle(.borderless)
                        .disabled(isSubmitting)
                        .accessibilityIdentifier("editor.step.\(step.stepNum).addIngredient")

                        Button {
                            pasteStepID = step.id
                        } label: {
                            Label("Paste Ingredients", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .disabled(isSubmitting)
                        .accessibilityIdentifier("editor.step.\(step.stepNum).pasteIngredients")
                    }
                    .padding(.vertical, 6)
                }
                // Steps reorder in Edit mode only: a reorderable row holds a touch as a possible drag, and
                // taps on a step's text fields did not focus them.
                .onMove(perform: stepMoveAction)

                Button {
                    addStep()
                } label: {
                    Label("Add Step", systemImage: "plus.circle")
                }
                .disabled(isSubmitting)
                .accessibilityIdentifier("editor.addStep")
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
                .accessibilityIdentifier("editor.save")

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
#if os(iOS)
        .toolbar {
            EditButton()
        }
#endif
        .sheet(isPresented: Binding(get: { pasteStepID != nil }, set: { if !$0 { pasteStepID = nil } })) {
            if let stepID = pasteStepID, let step = draft.steps.first(where: { $0.id == stepID }) {
                IngredientPasteSheet(
                    stepNumber: step.stepNum,
                    makeLocalID: { localID("local_ingredient") },
                    onAdd: { addIngredients($0, to: stepID) },
                    onCancel: { pasteStepID = nil }
                )
            }
        }
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

    @ViewBuilder private var photoSection: some View {
        Section("Photo") {
            if activeViewModel.connectivity == .online {
                let hasPhoto = stagedPhoto != nil
                HStack(alignment: .center, spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(hasPhoto ? "Replace Photo" : "Add Photo", systemImage: hasPhoto ? "photo.fill" : "photo.badge.plus")
                            .font(KitchenTableTheme.uiLabel)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("editor.photo.pick")
                    .onChange(of: selectedPhotoItem) { _, item in
                        Task { @MainActor in
                            await stagePhoto(item)
                        }
                    }

                    if hasPhoto {
                        Label("Photo ready", systemImage: "checkmark.circle.fill")
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.herb)
                            .accessibilityIdentifier("editor.photo.ready")
                        Spacer()
                        Button {
                            selectedPhotoItem = nil
                            stagedPhoto = nil
                            photoMessage = nil
                        } label: {
                            Label("Remove Photo", systemImage: "xmark.circle")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("editor.photo.remove")
                    }
                }
                Text(hasPhoto
                    ? "Uploads as the cover when you save."
                    : "Optional. Without a photo, Spoonjoy makes a placeholder cover.")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            } else {
                Text("Photos upload once you're online. You can add one from the recipe's Photo Studio after it syncs.")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            if let photoMessage {
                Label(photoMessage, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
                    .accessibilityIdentifier("editor.photo.status")
            }
        }
    }

    @MainActor private func stagePhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            return
        }
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        guard let contentType = item.supportedContentTypes.compactMap({ $0.preferredMIMEType?.lowercased() }).first(where: { policy.fileExtension(for: $0) != nil }),
              let fileExtension = policy.fileExtension(for: contentType) else {
            selectedPhotoItem = nil
            photoMessage = "Unsupported photo format. Choose a JPEG, PNG, WebP, or HEIC image."
            return
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                selectedPhotoItem = nil
                photoMessage = "Photo could not be loaded."
                return
            }
            let candidate = NativeStagedMediaUpload(
                localStageID: "recipe-create-photo-\(UUID().uuidString)",
                fileName: "cover.\(fileExtension)",
                contentType: contentType,
                data: data
            )
            let result = await RecipeCoverPhotoStagingWorker().stageSelection(
                existing: stagedPhoto,
                candidate: candidate,
                existingUsage: RecipeCoverPhotoStagedMediaUsage(byteCount: 0, fileCount: 0)
            )
            if result.rejection != nil {
                selectedPhotoItem = nil
                photoMessage = "Photo is too large or could not be read. Choose another image."
                return
            }
            stagedPhoto = result.stagedPhoto
            photoMessage = nil
        } catch {
            selectedPhotoItem = nil
            photoMessage = "Photo could not be loaded."
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
            } else if let plannedAction = plannedActions.first,
                      let stagedPhoto,
                      draft.recipeID == nil,
                      plannedAction.plan.remoteRequestBuilder != nil,
                      plannedAction.plan.queuedMutation == nil {
                do {
                    let route = try await createRecipeWithPhoto(plannedAction.plan, stagedPhoto)
                    blockedMessage = nil
                    offlineDisplayOverride = nil
                    close(route)
                    return
                } catch {
                    throw RecipeEditorActionExecutionError(action: plannedAction.action, underlyingError: error)
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

    private var stepMoveAction: ((IndexSet, Int) -> Void)? {
#if os(iOS)
        guard editMode?.wrappedValue.isEditing == true else {
            return nil
        }
#endif
        return moveSteps
    }

    private func moveSteps(_ indices: IndexSet, _ newOffset: Int) {
        showMoveOutcome(draft.moveSteps(fromOffsets: indices, toOffset: newOffset))
    }

    private func moveStep(id: String, by offset: Int) {
        showMoveOutcome(draft.moveStep(id: id, by: offset))
    }

    private func moveIngredient(id: String, in stepID: String, by offset: Int) {
        showMoveOutcome(draft.moveIngredient(id: id, inStep: stepID, by: offset))
    }

    private func showMoveOutcome(_ outcome: RecipeEditorMoveOutcome) {
        if case .blocked(let message) = outcome {
            blockedMessage = message
        } else {
            blockedMessage = nil
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

    private func addIngredients(_ ingredients: [RecipeEditorIngredientDraft], to stepID: String) {
        pasteStepID = nil
        guard let stepIndex = draft.steps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        draft.steps[stepIndex].ingredients.append(contentsOf: ingredients)
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

    /// The ingredient's 1-based position in its step, for accessibility identifiers.
    private func ingredientNumber(_ ingredientID: String, in step: RecipeEditorStepDraft) -> Int {
        (step.ingredients.firstIndex { $0.id == ingredientID } ?? step.ingredients.count) + 1
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
