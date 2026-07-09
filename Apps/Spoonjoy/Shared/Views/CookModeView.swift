import Combine
import Foundation
import SpoonjoyCore
import SwiftUI

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
                Label(errorMessage, systemImage: "fork.knife")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(KitchenTableTheme.pagePadding)
                    .background(KitchenTableTheme.bone)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KitchenTableTheme.bone)
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
                errorMessage = "Recipe unavailable for cook mode."
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
                compactCookControls
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

            if let currentStep {
                focusedStep(currentStep)
                dependencyChecklist
                ingredientChecklist
            }
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
        false
#endif
    }

    @ViewBuilder private var header: some View {
        if usesEmbeddedSpoonDock {
            compactHeader
        } else {
            regularHeader
        }
    }

    private var regularHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            KitchenTableHeader(
                eyebrow: viewModel.stepProgressLabel,
                title: recipe.title,
                subtitle: viewModel.recipeProgressLabel
            )

            Label(viewModel.currentPageProgressLabel, systemImage: "checkmark.circle")
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.brass)

            ProgressView(value: viewModel.recipeCheckoffFraction, total: 1)
                .tint(KitchenTableTheme.herb)
                .accessibilityLabel("Persisted progress")
                .accessibilityValue(viewModel.recipeProgressLabel)

            ScaleSelector(scaleFactor: progress.scaleFactor) { scaleFactor in
                updateProgress(progress.settingScaleFactor(scaleFactor, updatedAt: timestamp()))
            }

            Button {
                addRecipeIngredients(scaleFactor: progress.scaleFactor)
            } label: {
                Label("Add Ingredients", systemImage: "cart.badge.plus")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))

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
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(viewModel.stepProgressLabel.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(KitchenTableTheme.brass)

                Spacer(minLength: 8)

                Label(viewModel.currentPageProgressLabel, systemImage: "checkmark.circle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Text(recipe.title)
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: viewModel.recipeCheckoffFraction, total: 1)
                .tint(KitchenTableTheme.herb)
                .accessibilityLabel("Persisted progress")
                .accessibilityValue(viewModel.recipeProgressLabel)

            ScaleSelector(scaleFactor: progress.scaleFactor) { scaleFactor in
                updateProgress(progress.settingScaleFactor(scaleFactor, updatedAt: timestamp()))
            }

            Button {
                addRecipeIngredients(scaleFactor: progress.scaleFactor)
            } label: {
                Label("Add Ingredients", systemImage: "cart.badge.plus")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))

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
    }

    private func focusedStep(_ step: RecipeStep) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(step.stepNum). \(step.stepTitle ?? "Step")")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .accessibilityLabel("Current cooking step \(step.stepNum), \(step.stepTitle ?? "Step")")
            Text(step.description)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.primary)
            if let timer = viewModel.timer {
                CookModeTimer(timer: timer)
                    .id(timer.stepID)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    @ViewBuilder private var dependencyChecklist: some View {
        if !viewModel.stepOutputChecklistRows.isEmpty {
            KitchenTableSection(title: "Step Inputs") {
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
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder private var ingredientChecklist: some View {
        if !viewModel.ingredientChecklistRows.isEmpty {
            KitchenTableSection(title: "Step Ingredients") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.ingredientChecklistRows, id: \.id) { row in
                        Toggle(isOn: ingredientBinding(for: row)) {
                            HStack(spacing: 12) {
                                Text(row.title)
                                    .foregroundStyle(KitchenTableTheme.charcoal)
                                Spacer()
                                Text(row.quantityText)
                                    .font(KitchenTableTheme.uiLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.largeCheck)
                        .tint(KitchenTableTheme.herb)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Button(action: previous) {
                Label("Previous", systemImage: "arrow.backward.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canGoBack)

            KitchenSafeControls(
                canAdvance: canAdvance,
                markComplete: markCurrentStepComplete,
                advance: advance,
                close: close
            )
        }
        .padding(.horizontal, KitchenTableTheme.pagePadding)
        .padding(.vertical, 12)
        .background(.background.opacity(0.72))
    }

    private var compactCookControls: some View {
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

        updateProgress(nextProgress)
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
            steps.flatMap { $0.ingredients.map(\.id) } +
            steps.flatMap { $0.usingSteps.map(\.id) }
        ).joined(separator: "|")
    }
}

private struct CookModeTimer: View {
    let timer: CookModeTimerViewModel

    @State private var remainingSeconds: Int
    @State private var isRunning: Bool
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(timer: CookModeTimerViewModel) {
        self.timer = timer
        _remainingSeconds = State(initialValue: timer.remainingSeconds)
        _isRunning = State(initialValue: timer.isRunning)
    }

    var body: some View {
        HStack(spacing: 12) {
            Label(formattedRemainingTime, systemImage: "timer")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(KitchenTableTheme.charcoal)

            Spacer()

            HStack(spacing: 8) {
                Button(primaryButtonTitle) {
                    if isRunning {
                        isRunning = false
                    } else {
                        if remainingSeconds == 0 {
                            remainingSeconds = timer.durationSeconds
                        }
                        isRunning = true
                    }
                }
                .buttonStyle(CookModeTimerButtonStyle(prominence: .primary))

                Button(timer.resetButtonTitle) {
                    remainingSeconds = timer.durationSeconds
                    isRunning = false
                }
                .buttonStyle(CookModeTimerButtonStyle(prominence: .secondary))
            }
        }
        .onReceive(ticker) { _ in
            guard isRunning else {
                return
            }
            remainingSeconds = max(remainingSeconds - 1, 0)
            if remainingSeconds == 0 {
                isRunning = false
            }
        }
        .onChange(of: timer.stepID) { _, _ in
            remainingSeconds = timer.remainingSeconds
            isRunning = timer.isRunning
        }
    }

    private var formattedRemainingTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var primaryButtonTitle: String {
        if isRunning {
            return timer.pauseButtonTitle
        }
        return remainingSeconds == 0 ? timer.restartButtonTitle : timer.startButtonTitle
    }
}

private struct CookModeTimerButtonStyle: ButtonStyle {
    enum Prominence {
        case primary
        case secondary
    }

    let prominence: Prominence

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .foregroundStyle(foreground)
            .background(background(configuration: configuration), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(stroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }

    private var foreground: Color {
        switch prominence {
        case .primary:
            KitchenTableTheme.paper
        case .secondary:
            KitchenTableTheme.charcoal
        }
    }

    private func background(configuration _: Configuration) -> Color {
        switch prominence {
        case .primary:
            KitchenTableTheme.action
        case .secondary:
            KitchenTableTheme.vellum.opacity(0.72)
        }
    }

    private var stroke: Color {
        switch prominence {
        case .primary:
            KitchenTableTheme.action
        case .secondary:
            KitchenTableTheme.line.opacity(0.68)
        }
    }
}
