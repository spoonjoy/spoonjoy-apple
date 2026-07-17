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
        shoppingViewModel: ShoppingSurfaceViewModel,
        performShoppingAction: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome = { _ in .synced },
        close: @escaping () -> Void = {}
    ) {
        self.recipeID = recipeID
        self.repository = repository
        self.initialRecipe = initialRecipe
        self.progress = progress
        self.progressDidChange = progressDidChange
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
    private let progressDidChange: (CookModeProgress) -> Void
    private let shoppingViewModel: ShoppingSurfaceViewModel
    private let performShoppingAction: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    private let close: () -> Void

    init(
        viewModel: CookModeViewModel,
        progressDidChange: @escaping (CookModeProgress) -> Void = { _ in },
        shoppingViewModel: ShoppingSurfaceViewModel,
        performShoppingAction: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome = { _ in .synced },
        close: @escaping () -> Void = {}
    ) {
        recipe = viewModel.recipe
        _progress = State(initialValue: viewModel.progress)
        self.progressDidChange = progressDidChange
        self.shoppingViewModel = shoppingViewModel
        self.performShoppingAction = performShoppingAction
        self.close = close
    }

    var body: some View {
        cookModeBody
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.bone)
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
        .onAppear(perform: normalizeProgressForCurrentRecipe)
        .onChange(of: recipe.cookModeIdentityKey) { _, _ in
            normalizeProgressForCurrentRecipe()
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
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    cookModeScrollContent
                }

                bottomControls
            }
        }
    }

    private var cookModeScrollContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            currentStepCard
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
        VStack(alignment: .leading, spacing: 14) {
            KitchenTableHeader(
                eyebrow: viewModel.stepProgressLabel,
                title: recipe.title
            ) {
                regularHeaderTools
            }

            stepProgressRail
        }
    }

    private var regularHeaderTools: some View {
        VStack(alignment: .trailing, spacing: 8) {
            utilityButton
            shoppingStatus
        }
        .frame(maxWidth: 220, alignment: .trailing)
    }

    private var compactTaskHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            stepProgressRail
            utilityButton
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
        .frame(maxWidth: 156, alignment: .leading)
        .accessibilityHint("Opens recipe scale and shopping-list tools.")
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
            KitchenTableSection(title: "Scale") {
                ScaleSelector(
                    scaleFactor: progress.scaleFactor
                ) { scaleFactor in
                    updateProgress(progress.settingScaleFactor(scaleFactor, updatedAt: timestamp()))
                }
            }

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
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
            if let timer = viewModel.systemTimer {
                CookModeSystemTimer(timer: timer) {
                    try await scheduleSystemTimer(timer, step: step)
                }
                    .id(timer.stepID)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private func currentStepTitle(_ step: RecipeStep) -> some View {
        Text("\(step.stepNum). \(step.stepTitle ?? "Step")")
            .font(.title2)
            .foregroundStyle(KitchenTableTheme.charcoal)
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
        try await CookModeAlarmKitTimerScheduler.schedule(timer: timer, recipe: recipe, step: step)
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
    @MainActor static func schedule(timer: CookModeSystemTimerViewModel, recipe: Recipe, step: RecipeStep) async throws -> String {
#if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            let client = CookModeSystemTimerSchedulingClient(
                authorizationState: {
                    authorizationState(from: AlarmManager.shared.authorizationState)
                },
                requestAuthorization: {
                    authorizationState(from: try await AlarmManager.shared.requestAuthorization())
                },
                schedule: {
                    try await scheduleAlarm(timer: timer, recipe: recipe, step: step)
                }
            )
            try await CookModeSystemTimerScheduler.schedule(using: client)
            return "\(timer.durationLabel) system timer set."
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
    ) async throws {
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
            stepTitle: step.stepTitle ?? "Step \(step.stepNum)",
            durationMinutes: timer.durationMinutes
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: KitchenTableTheme.herb
        )
        let configuration = AlarmManager.AlarmConfiguration.timer(duration: TimeInterval(timer.durationSeconds),
            attributes: attributes
        )
        _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
    }
#endif
}

#if os(iOS) && canImport(AlarmKit)
@available(iOS 26.0, *)
private struct SpoonjoyCookTimerMetadata: AlarmMetadata {
    let recipeID: String
    let recipeTitle: String
    let stepID: String
    let stepTitle: String
    let durationMinutes: Int
}
#endif
