import Foundation
import SpoonjoyCore
import SwiftUI

@MainActor
final class RecipeEditorToolbarCoordinator: ObservableObject {
    @Published private(set) var session = RecipeEditorToolbarSession()
    private var saveAction: (() -> Void)?

    func configure(routeIdentifier: String, canSave: Bool, isSaving: Bool, saveAction: @escaping () -> Void) {
        session.configure(routeIdentifier: routeIdentifier, canSave: canSave, isSaving: isSaving)
        self.saveAction = saveAction
    }

    func canPerformSave(for routeIdentifier: String) -> Bool {
        session.canPerformSave(for: routeIdentifier)
    }

    func isSaving(for routeIdentifier: String) -> Bool {
        session.routeIdentifier == routeIdentifier && session.isSaving
    }

    func performSave(for routeIdentifier: String) {
        guard session.canPerformSave(for: routeIdentifier) else { return }
        saveAction?()
    }

    func reset(ifMatching routeIdentifier: String) {
        guard session.routeIdentifier == routeIdentifier else { return }
        session.reset(ifMatching: routeIdentifier)
        saveAction = nil
    }
}

private struct RecipeEditorToolbarFingerprint: Equatable {
    let routeIdentifier: String
    let originalDraft: RecipeEditorDraft
    let connectivity: RecipeEditorConnectivity
    let conflict: RecipeEditorConflict?
    let queuedMutations: [NativeQueuedMutation]
    let currentDraft: RecipeEditorDraft
    let conflictOverride: Bool
    let runtimeConflict: RecipeEditorConflict?
    let isSubmitting: Bool
}

private struct RecipeEditorPlatformScroller: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        ScrollView {
            content.fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, KitchenTableTheme.pageSpacing)
        }
#else
        content
#endif
    }
}

struct RecipeEditorView: View {
    let viewModel: RecipeEditorViewModel
    let mutationDidPlan: @MainActor @Sendable (RecipeEditorMutationPlan) async throws -> Void
    let mutationsDidQueue: @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult
    let conflictDidDiscardLocalChange: @MainActor @Sendable (RecipeEditorConflict) async throws -> Void
    let close: @MainActor @Sendable (AppRoute) -> Void
    let shellOfflineIndicatorState: OfflineIndicatorState?
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void
    let toolbarCoordinator: RecipeEditorToolbarCoordinator?

    @State private var draft: RecipeEditorDraft
    @State private var blockedMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var isSubmitting = false
    @State private var conflictOverride = false
    @State private var runtimeConflict: RecipeEditorConflict?
    @State private var offlineDisplayOverride: OfflineIndicatorDisplay?
    @State private var expandedOutputStepIDs: Set<String> = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.spoonjoyCompactNavigation) private var usesCompactNavigation

    init(
        viewModel: RecipeEditorViewModel,
        mutationDidPlan: @escaping @MainActor @Sendable (RecipeEditorMutationPlan) async throws -> Void,
        mutationsDidQueue: @escaping @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        conflictDidDiscardLocalChange: @escaping @MainActor @Sendable (RecipeEditorConflict) async throws -> Void,
        close: @escaping @MainActor @Sendable (AppRoute) -> Void,
        shellOfflineIndicatorState: OfflineIndicatorState? = nil,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {},
        toolbarCoordinator: RecipeEditorToolbarCoordinator? = nil
    ) {
        self.viewModel = viewModel
        self.mutationDidPlan = mutationDidPlan
        self.mutationsDidQueue = mutationsDidQueue
        self.conflictDidDiscardLocalChange = conflictDidDiscardLocalChange
        self.close = close
        self.shellOfflineIndicatorState = shellOfflineIndicatorState
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        self.toolbarCoordinator = toolbarCoordinator
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

            Section {
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            TextField("Title", text: $draft.title, axis: .vertical)
                                .lineLimit(1...4)
                        } else {
                            TextField("Title", text: $draft.title)
                        }
                    }
                        .accessibilityIdentifier("recipe-editor.title")
                        .accessibilityLabel("Title")
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())

                    Divider()

                    if dynamicTypeSize.isAccessibilitySize {
                        accessibilityServingsField
                        Divider()
                        recipeDescriptionField
                    } else {
                        recipeDescriptionField
                        Divider()
                        compactServingsField
                    }
                }
            } header: {
                editorSectionHeader("Recipe")
            }

            Section {
                ForEach(draft.steps) { stepValue in
                    let step = stepBinding(id: stepValue.id, fallback: stepValue)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Step \(step.wrappedValue.stepNum)")
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                removeStep(id: stepValue.id)
                            } label: {
                                Image(systemName: "trash")
                                    .accessibilityLabel("Delete Step")
                            }
                            .labelStyle(.iconOnly)
                            .frame(
                                width: KitchenTableTheme.minimumTouchTarget,
                                height: KitchenTableTheme.minimumTouchTarget
                            )
                            .contentShape(Rectangle())
                            .disabled(isSubmitting)
                        }

                        Group {
                            if dynamicTypeSize.isAccessibilitySize {
                                TextField("Step title", text: optionalText(step.title), axis: .vertical)
                                    .lineLimit(1...4)
                            } else {
                                TextField("Step title", text: optionalText(step.title))
                            }
                        }
                            .accessibilityLabel("Step title")
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        durationControl(step.duration)
                        TextField("What happens in this step?", text: step.description, axis: .vertical)
                            .lineLimit(3...5)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Step description")

                        let priorSteps = priorSteps(for: step.wrappedValue)
                        if !priorSteps.isEmpty {
                            Button {
                                toggleOutputSteps(for: stepValue.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("Uses Output From")
                                    Spacer()
                                    Image(systemName: expandedOutputStepIDs.contains(stepValue.id) ? "chevron.up" : "chevron.down")
                                        .accessibilityHidden(true)
                                }
                                .padding(.vertical, 11)
                                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Uses Output From")
                            .accessibilityValue(expandedOutputStepIDs.contains(stepValue.id) ? "Expanded" : "Collapsed")

                            if expandedOutputStepIDs.contains(stepValue.id) {
                                ForEach(priorSteps) { priorStep in
                                    Toggle(
                                        "Step \(priorStep.stepNum)",
                                        isOn: outputUseBinding(step.outputStepNums, outputStepNum: priorStep.stepNum)
                                    )
                                }
                            }
                        }

                        ForEach(step.wrappedValue.ingredients) { ingredientValue in
                            let ingredient = ingredientBinding(
                                stepID: stepValue.id,
                                ingredientID: ingredientValue.id,
                                fallback: ingredientValue
                            )
                            ingredientControls(
                                ingredient,
                                ingredientID: ingredientValue.id,
                                stepID: stepValue.id
                            )
                        }

                        Button {
                            addIngredient(to: stepValue.id)
                        } label: {
                            Label("Add Ingredient", systemImage: "plus.circle")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: KitchenTableTheme.minimumTouchTarget,
                            alignment: .leading
                        )
                        .contentShape(Rectangle())
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
            } header: {
                editorSectionHeader("Steps")
            }

            Section {
                if draft.recipeID != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Recipe", systemImage: "trash")
                            .foregroundStyle(KitchenTableTheme.tomato)
                    }
                    .accessibilityIdentifier("recipe-editor.delete")
                    .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                }
            }
        }
        .modifier(RecipeEditorPlatformScroller())
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectHidden(for: .bottom)
        .contentMargins(.top, KitchenTableTheme.pageSpacing, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .toolbar {
            if !usesCompactNavigation {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!activeViewModel.updatingDraft(draft).canSubmit || isSubmitting)
                    .accessibilityIdentifier("recipe-editor.save")
                }
            }
        }
        .onAppear {
            synchronizeToolbarCoordinator()
        }
        .onChange(of: toolbarFingerprint) { _, _ in
            synchronizeToolbarCoordinator()
        }
        .onDisappear {
            toolbarCoordinator?.reset(ifMatching: editorRouteIdentifier)
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
        .task(id: draft.recipeID) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "recipe-editor",
                source: "RecipeEditorView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
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

    private var editorRouteIdentifier: String {
        viewModel.route.stateIdentifier
    }

    private var toolbarFingerprint: RecipeEditorToolbarFingerprint {
        RecipeEditorToolbarFingerprint(
            routeIdentifier: editorRouteIdentifier,
            originalDraft: viewModel.draft,
            connectivity: viewModel.connectivity,
            conflict: viewModel.conflict,
            queuedMutations: viewModel.queuedRecipeMutations,
            currentDraft: draft,
            conflictOverride: conflictOverride,
            runtimeConflict: runtimeConflict,
            isSubmitting: isSubmitting
        )
    }

    private var descriptionText: Binding<String> {
        optionalText($draft.description)
    }

    private var recipeDescriptionField: some View {
        TextField("Description", text: descriptionText, axis: .vertical)
            .lineLimit(3...6)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .accessibilityLabel("Description")
    }

    private var accessibilityServingsField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Servings")
            TextField("", text: servingsText)
                .labelsHidden()
                .multilineTextAlignment(.leading)
                .accessibilityLabel("Servings")
                .padding(.vertical, 11)
                .contentShape(Rectangle())
        }
    }

    private var compactServingsField: some View {
        LabeledContent("Servings") {
            TextField("", text: servingsText)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("Servings")
                .frame(minWidth: 64)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
        }
        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
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

    private func durationControl(_ value: Binding<Int?>) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                    HStack(spacing: 12) {
                        Text(durationSummary(value.wrappedValue))
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                        Spacer(minLength: 8)
                        durationStepper(value)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                LabeledContent("Duration") {
                    HStack(spacing: 8) {
                        Text(durationSummary(value.wrappedValue))
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                        durationStepper(value)
                    }
                }
            }
        }
        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
        .disabled(isSubmitting)
    }

    private func durationStepper(_ value: Binding<Int?>) -> some View {
        Stepper(value: durationMinutes(value), in: 0...720) {
            EmptyView()
        }
        .labelsHidden()
        .controlSize(.extraLarge)
        .accessibilityLabel("Duration")
        .accessibilityValue(durationSummary(value.wrappedValue))
    }

    private func durationSummary(_ minutes: Int?) -> String {
        guard let minutes else { return "Not set" }
        return "\(minutes) min"
    }

    private func durationMinutes(_ value: Binding<Int?>) -> Binding<Int> {
        Binding(
            get: { value.wrappedValue ?? 0 },
            set: { minutes in
                value.wrappedValue = minutes == 0 ? nil : minutes
            }
        )
    }

    @ViewBuilder
    private func ingredientControls(
        _ ingredient: Binding<RecipeEditorIngredientDraft>,
        ingredientID: String,
        stepID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ingredient", text: ingredient.name)
                .accessibilityLabel("Ingredient")
                .padding(.vertical, 11)
                .contentShape(Rectangle())

            if dynamicTypeSize.isAccessibilitySize {
                accessibilityIngredientControls(
                    ingredient,
                    ingredientID: ingredientID,
                    stepID: stepID
                )
            } else {
                compactIngredientControls(
                    ingredient,
                    ingredientID: ingredientID,
                    stepID: stepID
                )
            }
        }
    }

    private func accessibilityIngredientControls(
        _ ingredient: Binding<RecipeEditorIngredientDraft>,
        ingredientID: String,
        stepID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Quantity") {
                TextField(
                    "",
                    value: ingredient.quantity,
                    format: .number.precision(.fractionLength(0...3))
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("Quantity")
            }

            LabeledContent("Unit") {
                TextField("", text: optionalText(ingredient.unit))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Unit")
            }

            Button(role: .destructive) {
                removeIngredient(id: ingredientID, from: stepID)
            } label: {
                Label("Delete Ingredient", systemImage: "minus.circle")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: KitchenTableTheme.minimumTouchTarget,
                alignment: .leading
            )
            .contentShape(Rectangle())
            .disabled(isSubmitting)
        }
    }

    private func compactIngredientControls(
        _ ingredient: Binding<RecipeEditorIngredientDraft>,
        ingredientID: String,
        stepID: String
    ) -> some View {
        HStack(spacing: 12) {
            TextField(
                "Quantity",
                value: ingredient.quantity,
                format: .number.precision(.fractionLength(0...3))
            )
            .accessibilityLabel("Quantity")
            .frame(minWidth: 88)
            .padding(.vertical, 11)
            .contentShape(Rectangle())

            TextField("Unit", text: optionalText(ingredient.unit))
                .accessibilityLabel("Unit")
                .frame(minWidth: 72)
                .padding(.vertical, 11)
                .contentShape(Rectangle())

            Button(role: .destructive) {
                removeIngredient(id: ingredientID, from: stepID)
            } label: {
                Image(systemName: "minus.circle")
                    .accessibilityLabel("Delete Ingredient")
            }
            .labelStyle(.iconOnly)
            .frame(
                width: KitchenTableTheme.minimumTouchTarget,
                height: KitchenTableTheme.minimumTouchTarget
            )
            .contentShape(Rectangle())
            .disabled(isSubmitting)
        }
    }

    private func toggleOutputSteps(for stepID: String) {
        withAnimation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.2)) {
            if expandedOutputStepIDs.contains(stepID) {
                expandedOutputStepIDs.remove(stepID)
            } else {
                expandedOutputStepIDs.insert(stepID)
            }
        }
    }

    private func synchronizeToolbarCoordinator() {
        toolbarCoordinator?.configure(
            routeIdentifier: editorRouteIdentifier,
            canSave: activeViewModel.updatingDraft(draft).canSubmit,
            isSaving: isSubmitting
        ) {
            Task {
                await save()
            }
        }
    }

    private func editorSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(KitchenTableTheme.charcoal)
            .textCase(nil)
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

    private func stepBinding(id: String, fallback: RecipeEditorStepDraft) -> Binding<RecipeEditorStepDraft> {
        Binding(
            get: {
                draft.steps.first { $0.id == id } ?? fallback
            },
            set: { updatedStep in
                guard let index = draft.steps.firstIndex(where: { $0.id == id }) else { return }
                draft.steps[index] = updatedStep
            }
        )
    }

    private func ingredientBinding(
        stepID: String,
        ingredientID: String,
        fallback: RecipeEditorIngredientDraft
    ) -> Binding<RecipeEditorIngredientDraft> {
        Binding(
            get: {
                draft.steps
                    .first { $0.id == stepID }?
                    .ingredients
                    .first { $0.id == ingredientID } ?? fallback
            },
            set: { updatedIngredient in
                guard let stepIndex = draft.steps.firstIndex(where: { $0.id == stepID }) else { return }
                guard let ingredientIndex = draft.steps[stepIndex].ingredients.firstIndex(where: { $0.id == ingredientID }) else { return }
                draft.steps[stepIndex].ingredients[ingredientIndex] = updatedIngredient
            }
        )
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
