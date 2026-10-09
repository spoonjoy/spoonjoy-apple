import Foundation
import SpoonjoyCore
import SwiftUI
#if os(iOS) && canImport(AlarmKit)
import ActivityKit
import AlarmKit
import AppIntents
#endif

struct CookModeRouteView: View {
    let recipeID: String
    let repository: any RecipeCatalogRepository
    let initialRecipe: Recipe?
    let progress: (Recipe) -> CookModeProgress
    let progressDidChange: (CookModeProgress) -> Void
    let cookModeOpened: (String) -> Void
    let shoppingViewModel: ShoppingSurfaceViewModel
    let performShoppingAction: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    let close: () -> Void

    @State private var recipe: Recipe?
    @State private var errorMessage: String?

    init(
        recipeID: String,
        repository: any RecipeCatalogRepository,
        initialRecipe: Recipe?,
        progress: @escaping (Recipe) -> CookModeProgress,
        progressDidChange: @escaping (CookModeProgress) -> Void = { _ in },
        cookModeOpened: @escaping (String) -> Void = { _ in },
        shoppingViewModel: ShoppingSurfaceViewModel,
        performShoppingAction: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome = { _ in .synced },
        close: @escaping () -> Void = {}
    ) {
        self.recipeID = recipeID
        self.repository = repository
        self.initialRecipe = initialRecipe
        self.progress = progress
        self.progressDidChange = progressDidChange
        self.cookModeOpened = cookModeOpened
        self.shoppingViewModel = shoppingViewModel
        self.performShoppingAction = performShoppingAction
        self.close = close
        _recipe = State(initialValue: initialRecipe)
    }

    var body: some View {
        Group {
            if let recipe {
                CookModeView(
                    viewModel: CookModeViewModel(recipe: recipe, progress: restoredProgress(for: recipe)),
                    incomingProgress: restoredProgress(for: recipe),
                    progressDidChange: progressDidChange,
                    shoppingViewModel: shoppingViewModel,
                    performShoppingAction: performShoppingAction,
                    close: close
                )
            } else if let errorMessage {
                KitchenTableRouteErrorView(message: errorMessage, systemImage: "fork.knife")
            } else {
                KitchenTableLoadingStateView(title: "Loading cook mode", subtitle: "Setting up the current step.", systemImage: "fork.knife")
            }
        }
        .task(id: recipeID) {
            // Asks the store to read this recipe's progress from the server at its next sync; it does not wait.
            cookModeOpened(recipeID)
            await loadRecipe()
        }
    }

    @MainActor private func loadRecipe() async {
        do {
            let result = try await repository.recipeDetail(id: recipeID)
            recipe = result.recipe
            errorMessage = nil
        } catch {
            if recipe == nil {
                errorMessage = "We couldn't load this recipe for cook mode."
            }
        }
    }

    private func restoredProgress(for recipe: Recipe) -> CookModeProgress {
        let rawProgress = progress(recipe)
        guard !recipe.steps.isEmpty else {
            return rawProgress
        }
        return (try? CookModeProgress.restore(from: rawProgress.snapshot(), recipe: recipe)) ?? rawProgress
    }
}

struct CookModeView: View {
    private let recipe: Recipe
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var progress: CookModeProgress
    @State private var shoppingStatusMessage: String?
    @State private var shoppingErrorMessage: String?
    @State private var isCookModeUtilityPresented = false
    private let incomingProgress: CookModeProgress?
    private let progressDidChange: (CookModeProgress) -> Void
    private let shoppingViewModel: ShoppingSurfaceViewModel
    private let performShoppingAction: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    private let close: () -> Void

    init(
        viewModel: CookModeViewModel,
        incomingProgress: CookModeProgress? = nil,
        progressDidChange: @escaping (CookModeProgress) -> Void = { _ in },
        shoppingViewModel: ShoppingSurfaceViewModel,
        performShoppingAction: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome = { _ in .synced },
        close: @escaping () -> Void = {}
    ) {
        recipe = viewModel.recipe
        _progress = State(initialValue: viewModel.progress)
        self.incomingProgress = incomingProgress
        self.progressDidChange = progressDidChange
        self.shoppingViewModel = shoppingViewModel
        self.performShoppingAction = performShoppingAction
        self.close = close
    }

    var body: some View {
        cookModeBody
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.bone)
        .onChange(of: incomingProgress) { _, incoming in
            // Progress from another device arrives through the store. The step, scale and checked
            // ingredients follow it; completed steps stay as they are on this device. A change made
            // here has already reached the store, so it matches and is ignored.
            guard let incoming, !incoming.syncProgress.isSame(as: progress.syncProgress) else {
                return
            }
            progress = progress.applyingSyncProgress(incoming.syncProgress, updatedAt: incoming.updatedAt)
        }
        .sheet(isPresented: $isCookModeUtilityPresented) {
            NavigationStack {
                KitchenTablePage {
                    cookModeUtilitySheet
                }
                .navigationTitle("Cook tools")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            isCookModeUtilityPresented = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close cook tools")
                    }
                }
            }
        }
        .keepsScreenAwake()
        .sensoryFeedback(.selection, trigger: progress.currentStepID)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.recipeProgressLabel)
        .onAppear(perform: normalizeProgressForCurrentRecipe)
        .onAppear(perform: registerCookModeSession)
        .onDisappear {
            CookModeSessionCenter.shared.unregister()
        }
        .cookModeStepAnnotation(viewModel.onScreenStep)
        .onChange(of: recipe.cookModeIdentityKey) { _, _ in
            normalizeProgressForCurrentRecipe()
            registerCookModeSession()
        }
        .task(id: recipe.cookModeIdentityKey) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "cook-mode",
                source: "CookModeView",
                runtimeContext: screenshotAccessibilityRuntimeContext
            )
        }
    }

    @ViewBuilder private var cookModeBody: some View {
        if usesEmbeddedSpoonDock {
            ScrollView {
                cookModeScrollContent
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                cookModeBottomActionRail
            }
        } else {
            SpreadLayoutReader(isRegularWidth: true) { layout in
                if layout.isSpread {
                    cookModeSpread(layout)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            cookModeScrollContent
                        }

                        bottomControls
                    }
                }
            }
        }
    }

    private var cookModeScrollContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            currentStepCard
            cookControls
            dependencyChecklist
            ingredientChecklist
        }
        .padding(.horizontal, KitchenTableTheme.pagePadding + 4)
        .padding(.top, 20)
        .padding(.bottom, compactScrollBottomPadding)
    }

    private var compactScrollBottomPadding: CGFloat {
        usesEmbeddedSpoonDock ? 28 : 32
    }

    private var viewModel: CookModeViewModel {
        CookModeViewModel(recipe: recipe, progress: progress)
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    private var ingredientChecklistAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeInOut(duration: 0.24)
    }

    private var ingredientChecklistTransaction: Transaction {
        var transaction = Transaction(animation: ingredientChecklistAnimation)
        if accessibilityReduceMotion {
            transaction.disablesAnimations = true
        }
        return transaction
    }

    private var currentStep: RecipeStep? {
        guard let currentStepID = viewModel.currentStepID else {
            return recipe.steps.first
        }

        return recipe.steps.first { $0.id == currentStepID } ?? recipe.steps.first
    }

    private var canAdvance: Bool {
        progress.currentStepID != recipe.steps.last?.id
    }

    private var usesEmbeddedSpoonDock: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        true
#endif
    }

    @ViewBuilder private var header: some View {
        if usesEmbeddedSpoonDock {
            compactTaskHeader
        } else {
            regularHeader
        }
    }

    private var regularHeader: some View {
        cookContextHeader
    }

    private var compactTaskHeader: some View {
        cookContextHeader
    }

    /// Where you are in the recipe: the step count, the recipe's name as a quiet running head and overall progress.
    /// The current step below is the hero, as on the web.
    private var cookContextHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(viewModel.stepProgressLabel.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(KitchenTableTheme.brass)

#if os(macOS)
                Spacer(minLength: 12)
                macOSCookModeCloseButton
#endif
            }

            Text(recipe.title)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            stepProgressRail
            shoppingStatus
        }
    }

#if os(macOS)
    private var macOSCookModeCloseButton: some View {
        Button(action: close) {
            Label("Close", systemImage: "xmark")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Close cook mode")
        .accessibilityHint("Returns to the recipe.")
    }
#endif

    private var stepProgressRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: viewModel.recipeCheckoffFraction, total: 1)
                .tint(KitchenTableTheme.herb)
                .accessibilityLabel("Persisted progress")
                .accessibilityValue(viewModel.recipeProgressLabel)

            Label(viewModel.recipeProgressLabel, systemImage: "checkmark.circle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private var utilityButton: some View {
        Button {
            isCookModeUtilityPresented = true
        } label: {
            Label("Tools", systemImage: "slider.horizontal.3")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
        .fixedSize()
        .accessibilityHint("Opens shopping-list tools.")
    }

    /// Scale sits right under the step so it can change while cooking; Tools keeps the shopping action.
    private var cookControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                inlineScale
                utilityButton
            }

            VStack(alignment: .leading, spacing: 10) {
                inlineScale
                utilityButton
            }
        }
    }

    private var inlineScale: some View {
        ScaleSelector(scaleFactor: progress.scaleFactor) { scaleFactor in
            updateProgress(progress.settingScaleFactor(scaleFactor, updatedAt: timestamp()))
        }
        .accessibilityIdentifier("cookMode.scale")
    }

    @ViewBuilder private var shoppingStatus: some View {
        if let shoppingStatusMessage {
            Label(shoppingStatusMessage, systemImage: "checkmark.circle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
        } else if let shoppingErrorMessage {
            Label(shoppingErrorMessage, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.tomato)
        }
    }

    private var cookModeUtilitySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                addRecipeIngredients(scaleFactor: progress.scaleFactor)
            } label: {
                Label("Add to list", systemImage: "cart.badge.plus")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var currentStepCard: some View {
        if let currentStep {
            focusedStep(currentStep)
        }
    }

    private func focusedStep(_ step: RecipeStep) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    currentStepTitle(step)
                    if let timer = viewModel.systemTimer {
                        RecipeStepDurationCue(durationLabel: timer.durationLabel)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    currentStepTitle(step)
                    if let timer = viewModel.systemTimer {
                        RecipeStepDurationCue(durationLabel: timer.durationLabel)
                    }
                }
            }
            Text(step.description)
                .font(KitchenTableTheme.spreadInstruction)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            if let timer = viewModel.systemTimer {
                CookModeSystemTimer(timer: timer) {
                    try await scheduleSystemTimer(timer, step: step)
                }
                    .id(timer.stepID)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func currentStepTitle(_ step: RecipeStep) -> some View {
        Text(step.stepTitle ?? "Step \(step.stepNum)")
            .font(KitchenTableTheme.displayTitle)
            .foregroundStyle(KitchenTableTheme.charcoal)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Current cooking step \(step.stepNum), \(step.stepTitle ?? "Step")")
    }

    @ViewBuilder private var dependencyChecklist: some View {
        if !viewModel.stepOutputChecklistRows.isEmpty {
            KitchenTableSection(title: "Use from earlier") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.stepOutputChecklistRows, id: \.id) { row in
                        Toggle(isOn: stepOutputBinding(for: row)) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundStyle(KitchenTableTheme.brass)
                                    .accessibilityHidden(true)
                                Text(row.title)
                                    .foregroundStyle(KitchenTableTheme.charcoal)
                            }
                        }
                        .toggleStyle(.largeCheck)
                        .tint(KitchenTableTheme.herb)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(ingredientChecklistAnimation, value: viewModel.ingredientChecklistRows)
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder private var ingredientChecklist: some View {
        if !viewModel.ingredientChecklistRows.isEmpty {
            KitchenTableSection(title: "Ingredients") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.ingredientChecklistRows, id: \.id) { row in
                        Toggle(isOn: ingredientBinding(for: row)) {
                            CookModeIngredientChecklistLabel(row: row)
                        }
                        .toggleStyle(.largeCheck)
                        .accessibilityIdentifier("cookMode.ingredient")
                        .tint(KitchenTableTheme.herb)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(ingredientChecklistAnimation, value: viewModel.ingredientChecklistRows)
                .padding(.horizontal, 2)
            }
        }
    }

    private var bottomControls: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: previous) {
                Label("Back step", systemImage: "chevron.backward.circle")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
            .disabled(!canGoBack)
            .frame(maxWidth: 180)

            KitchenSafeControls(
                canAdvance: canAdvance,
                markComplete: markCurrentStepComplete,
                advance: advance,
                close: close
            )
            .frame(maxWidth: 460)
        }
        .frame(maxWidth: 820, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, KitchenTableTheme.pagePadding)
        .padding(.vertical, 12)
        .background(KitchenTableTheme.paper.opacity(0.72))
    }

    private var cookModeBottomActionRail: some View {
        SpoonDock(context: SpoonDockContext.cookMode(
            previous: previous,
            markComplete: markCurrentStepComplete,
            next: advance,
            canGoBack: canGoBack,
            canAdvance: canAdvance,
            stepTitle: viewModel.stepProgressLabel
        ))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(KitchenTableTheme.bone)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var canGoBack: Bool {
        guard let currentStep,
              let index = recipe.steps.firstIndex(where: { $0.id == currentStep.id }) else {
            return false
        }

        return index > recipe.steps.startIndex
    }

    private func markCurrentStepComplete() {
        guard let currentStep else {
            return
        }

        updateProgress(
            (try? progress.markingStepCompleted(currentStep.id, updatedAt: timestamp())) ?? progress
        )
    }

    private func advance() {
        updateProgress(viewModel.progressAfterSelectingNext(updatedAt: timestamp()))
    }

    private func previous() {
        updateProgress(viewModel.progressAfterSelectingPrevious(updatedAt: timestamp()))
    }

    private func ingredientBinding(for row: CookModeChecklistRow) -> Binding<Bool> {
        Binding(
            get: { currentIngredientCheckedState(for: row) },
            set: { checked in progressAfterTogglingIngredient(id: row.id, checked: checked) }
        )
    }

    private func stepOutputBinding(for row: CookModeChecklistRow) -> Binding<Bool> {
        Binding(
            get: { currentStepOutputCheckedState(for: row) },
            set: { checked in progressAfterTogglingStepOutputUse(id: row.id, checked: checked) }
        )
    }

    private func currentIngredientCheckedState(for row: CookModeChecklistRow) -> Bool {
        viewModel.ingredientChecklistRows.first { $0.id == row.id }?.isChecked ?? row.isChecked
    }

    private func currentStepOutputCheckedState(for row: CookModeChecklistRow) -> Bool {
        viewModel.stepOutputChecklistRows.first { $0.id == row.id }?.isChecked ?? row.isChecked
    }

    private func progressAfterTogglingIngredient(id: String, checked: Bool) {
        guard let nextProgress = try? viewModel.progressAfterTogglingIngredient(
            id: id,
            checked: checked,
            updatedAt: timestamp()
        ) else {
            return
        }

        withTransaction(ingredientChecklistTransaction) {
            updateProgress(nextProgress)
        }
    }

    private func progressAfterTogglingStepOutputUse(id: String, checked: Bool) {
        guard let nextProgress = try? viewModel.progressAfterTogglingStepOutputUse(
            id: id,
            checked: checked,
            updatedAt: timestamp()
        ) else {
            return
        }

        updateProgress(nextProgress)
    }

    private func updateProgress(_ nextProgress: CookModeProgress) {
        progress = nextProgress
        progressDidChange(nextProgress)
    }

    private func addRecipeIngredients(scaleFactor: Double) {
        let createdAt = timestamp()
        let action = ShoppingSurfaceAction.addRecipeIngredients(
            recipeID: recipe.id,
            scaleFactor: scaleFactor,
            recipeIngredients: recipe.steps.flatMap(\.ingredients),
            clientMutationID: clientMutationID(prefix: "cook-shopping")
        )
        Task {
            do {
                let plan = try ShoppingSurfaceViewModel(
                    shoppingList: shoppingViewModel.shoppingList,
                    queuedMutations: shoppingViewModel.queuedMutations,
                    conflicts: shoppingViewModel.conflicts,
                    connectivity: shoppingViewModel.connectivity,
                    now: { createdAt }
                ).plan(action)
                let outcome = try await performShoppingAction(plan)
                shoppingStatusMessage = outcome == .queuedForSync ? "Ingredients saved for sync" : "Ingredients added to shopping"
                shoppingErrorMessage = nil
            } catch {
                shoppingStatusMessage = nil
                shoppingErrorMessage = "Could not update shopping list."
            }
        }
    }

    private func normalizeProgressForCurrentRecipe() {
        guard !recipe.steps.isEmpty,
              let normalizedProgress = try? CookModeProgress.restore(from: progress.snapshot(), recipe: recipe),
              normalizedProgress != progress else {
            return
        }

        updateProgress(normalizedProgress)
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func clientMutationID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }

    @MainActor private func scheduleSystemTimer(_ timer: CookModeSystemTimerViewModel, step: RecipeStep) async throws -> String {
        let scheduled = try await CookModeAlarmKitTimerScheduler.schedule(timer: timer, recipe: recipe, step: step)
        return scheduled.message
    }

    /// Lets Siri, Shortcuts and the Live Activity drive this screen while it is open.
    private func registerCookModeSession() {
        CookModeSessionCenter.shared.register(
            CookModeSessionCenter.Registration(
                viewModel: { viewModel },
                apply: { updateProgress($0) },
                startTimer: { timer in
                    guard let step = viewModel.activeStep else {
                        return
                    }
                    _ = try await scheduleSystemTimer(timer, step: step)
                }
            )
        )
    }
}

// MARK: - Cookbook spread

extension CookModeView {
    /// Cook mode laid open across a wide landscape screen. The left page gathers what this step needs, as a
    /// checklist; the right page is the step itself in large type with its timer. Back sits at the outer corner
    /// of the left page and Next at the outer corner of the right page, like turning a page, so every control
    /// stays well away from the fold in the middle.
    fileprivate func cookModeSpread(_ layout: BookSpreadLayout) -> some View {
        KitchenTableSpread(layout: layout) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    cookSpreadGatherPage
                        .spreadPagePadding(.leading, bottom: 24)
                }
                cookSpreadLeadingControls
                    .spreadPagePadding(.leading, top: 12, bottom: 16)
            }
            .accessibilityIdentifier("cookSpread.gatherPage")
        } trailing: {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    cookSpreadStepPage
                        .spreadPagePadding(.trailing, bottom: 24)
                }
                cookSpreadTrailingControls
                    .spreadPagePadding(.trailing, top: 12, bottom: 16)
            }
            .accessibilityIdentifier("cookSpread.stepPage")
        }
    }

    private var cookSpreadGatherPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .spreadRunningHead()
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Gather")
                        .font(KitchenTableTheme.displayTitle)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .accessibilityAddTraits(.isHeader)
                }
                stepProgressRail
                shoppingStatus
                cookControls
            }

            if viewModel.stepOutputChecklistRows.isEmpty && viewModel.ingredientChecklistRows.isEmpty {
                Text("Nothing new to gather for this step.")
                    .font(KitchenTableTheme.instructionBody)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            dependencyChecklist
            ingredientChecklist
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var cookSpreadStepPage: some View {
        if let currentStep {
            VStack(alignment: .leading, spacing: 18) {
                Text(viewModel.stepProgressLabel)
                    .spreadRunningHead()
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(currentStep.stepNum)")
                        .font(KitchenTableTheme.displayTitle)
                        .foregroundStyle(KitchenTableTheme.brass)
                        .accessibilityHidden(true)
                    Text(currentStep.stepTitle ?? "Step \(currentStep.stepNum)")
                        .font(KitchenTableTheme.sectionTitle)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Current cooking step \(currentStep.stepNum), \(currentStep.stepTitle ?? "Step")")
                }
                Text(currentStep.description)
                    .font(KitchenTableTheme.cookInstruction)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                if let timer = viewModel.systemTimer {
                    RecipeStepDurationCue(durationLabel: timer.durationLabel)
                    CookModeSystemTimer(timer: timer) {
                        try await scheduleSystemTimer(timer, step: currentStep)
                    }
                    .id(timer.stepID)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cookSpreadLeadingControls: some View {
        HStack(spacing: 10) {
            Button(action: previous) {
                Label("Back step", systemImage: "chevron.backward.circle")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
            .disabled(!canGoBack)
            .fixedSize()

            Button(action: close) {
                Label("Close", systemImage: "text.book.closed")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
            .accessibilityLabel("Return to recipe detail")
            .fixedSize()

            Spacer(minLength: 0)
        }
        .controlSize(.large)
    }

    private var cookSpreadTrailingControls: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Button(action: markCurrentStepComplete) {
                Label("Mark done", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            .accessibilityLabel("Mark the current step done")
            .fixedSize()

            Button(action: advance) {
                Label("Next step", systemImage: "arrow.forward.circle.fill")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
            .disabled(!canAdvance)
            .accessibilityLabel("Move to the next step")
            .fixedSize()
        }
        .controlSize(.large)
    }
}

private struct CookModeIngredientChecklistLabel: View {
    let row: CookModeChecklistRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(row.title)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            Spacer(minLength: 8)

            if !row.quantityText.isEmpty {
                Text(row.quantityText)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScaleSelector: View {
    let scaleFactor: Double
    let setScaleFactor: (Double) -> Void

    var body: some View {
        Stepper(value: scaleBinding, in: 0.25...50, step: 0.25) {
            Label("Scale \(scaleFactor.formatted(.number.precision(.fractionLength(0...2))))×", systemImage: "person.2")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.charcoal)
        }
        .tint(KitchenTableTheme.herb)
    }

    private var scaleBinding: Binding<Double> {
        Binding(
            get: { scaleFactor },
            set: { scaleFactor in
                setScaleFactor(scaleFactor)
            }
        )
    }
}

private extension Recipe {
    var cookModeIdentityKey: String {
        (
            [id] +
            steps.map(\.id) +
            steps.map { step in "duration:\(step.id):\(step.duration.map(String.init) ?? "none")" } +
            steps.flatMap { $0.ingredients.map(\.id) } +
            steps.flatMap { $0.usingSteps.map(\.id) }
        ).joined(separator: "|")
    }
}

private struct CookModeSystemTimer: View {
    let timer: CookModeSystemTimerViewModel
    let schedule: () async throws -> String

    @State private var isScheduling = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            timerAction
                .frame(maxWidth: .infinity, alignment: .leading)

            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
            }
        }
        .padding(12)
        .background(KitchenTableTheme.vellum.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private func scheduleTimer() {
        isScheduling = true
        statusMessage = nil
        errorMessage = nil
        Task {
            do {
                let message = try await schedule()
                await MainActor.run {
                    statusMessage = message
                    isScheduling = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = CookModeSystemTimerScheduler.message(for: error, fallback: timer.systemUnavailableMessage)
                    isScheduling = false
                }
            }
        }
    }

    @ViewBuilder private var timerAction: some View {
#if os(iOS)
        if #available(iOS 26.1, *) {
            Button {
                scheduleTimer()
            } label: {
                if isScheduling {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Setting system timer")
                } else {
                    Label(timer.startButtonTitle, systemImage: "alarm")
                }
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            .disabled(isScheduling)
            .accessibilityLabel(timer.startButtonTitle)
        } else {
            unavailableCue
        }
#else
        unavailableCue
#endif
    }

    private var unavailableCue: some View {
        Label(timer.systemUnavailableMessage, systemImage: "iphone")
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.inkMuted)
            .lineLimit(2)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private enum CookModeAlarmKitTimerScheduler {
    @MainActor static func schedule(timer: CookModeSystemTimerViewModel, recipe: Recipe, step: RecipeStep) async throws -> (message: String, alarmID: UUID?) {
#if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            var alarmID: UUID?
            let client = CookModeSystemTimerSchedulingClient(
                authorizationState: {
                    authorizationState(from: AlarmManager.shared.authorizationState)
                },
                requestAuthorization: {
                    authorizationState(from: try await AlarmManager.shared.requestAuthorization())
                },
                schedule: {
                    alarmID = try await scheduleAlarm(timer: timer, recipe: recipe, step: step)
                }
            )
            try await CookModeSystemTimerScheduler.schedule(using: client)
            return ("\(timer.durationLabel) system timer set.", alarmID)
        }
#endif
        throw CookModeSystemTimerSchedulingError.unsupportedPlatform
    }

#if os(iOS) && canImport(AlarmKit)
    @available(iOS 26.1, *)
    @MainActor private static func authorizationState(
        from state: AlarmManager.AuthorizationState
    ) -> CookModeSystemTimerAuthorizationState {
        switch state {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    @available(iOS 26.1, *)
    @MainActor private static func scheduleAlarm(
        timer: CookModeSystemTimerViewModel,
        recipe: Recipe,
        step: RecipeStep
    ) async throws -> UUID {
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: LocalizedStringResource("\(step.stepTitle ?? recipe.title) is ready")
            ),
            countdown: AlarmPresentation.Countdown(
                title: LocalizedStringResource("\(step.stepTitle ?? "Step \(step.stepNum)") timer"),
                pauseButton: AlarmButton(
                    text: "Pause",
                    textColor: .white,
                    systemImageName: "pause.fill"
                )
            ),
            paused: AlarmPresentation.Paused(
                title: LocalizedStringResource("\(step.stepTitle ?? "Step \(step.stepNum)") timer paused"),
                resumeButton: AlarmButton(
                    text: "Resume",
                    textColor: .white,
                    systemImageName: "play.fill"
                )
            )
        )
        let metadata = SpoonjoyCookTimerMetadata(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            stepID: step.id,
            stepNumber: step.stepNum,
            stepTitle: step.stepTitle ?? "Step \(step.stepNum)",
            durationMinutes: timer.durationMinutes,
            deepLink: DeepLinkURLBuilder.url(for: .recipeDetail(id: recipe.id, presentation: .cook)).absoluteString
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: KitchenTableTheme.herb
        )
        let configuration = AlarmManager.AlarmConfiguration.timer(duration: TimeInterval(timer.durationSeconds),
            attributes: attributes
        )
        let alarmID = UUID()
        _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
        return alarmID
    }
#endif
}
