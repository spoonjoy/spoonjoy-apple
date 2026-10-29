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
                    recipePageScale: RecipePageProgressStore().scaleFactor(recipeID: recipe.id),
                    progressDidChange: progressDidChange,
                    scaleDidChange: { scale in
                        RecipePageProgressStore().setScaleFactor(
                            scale,
                            recipeID: recipe.id,
                            updatedAt: ISO8601DateFormatter().string(from: Date())
                        )
                    },
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
    /// The cover glance's step title: display type twice the size of the page's, read from across the kitchen.
    @ScaledMetric(relativeTo: .largeTitle) private var coverGlanceTitleSize: CGFloat = 56
    @ObservedObject private var stepTimers: CookStepTimerRegistry
    @State private var progress: CookModeProgress
    @State private var shoppingStatusMessage: String?
    @State private var shoppingErrorMessage: String?
    /// The fold and hinge of a foldable, read from the system (iOS 27.1 SDK); empty everywhere else.
    @State private var foldReading = FoldReading()
    /// The step pager's drag. It springs back to rest by itself when the drag ends or is cancelled.
    @GestureState(resetTransaction: Transaction(animation: KitchenSpring.pageTurn.animation))
    private var pageDrag = CookPageDrag()
    @State private var pageTurnTapGuard = CookPageTurnTapGuard()
    /// True while a finger is on the pager. It resets when the finger lifts and when a scroll view takes the touch,
    /// which is when the guard's grace starts.
    @GestureState private var isTouchingPager = false
    /// Counts checks made by a tap here, so the check haptic plays for a check, not an uncheck or another device.
    @State private var localCheckCount = 0
    /// An auto-started timer that failed to set, by step, shown on that step's ring.
    @State private var autoStartErrors: [String: String] = [:]
    /// True after a foldable is folded shut mid-cook: the cover shows the step as a kitchen timer until it opens
    /// again or the cook asks for the whole step.
    @State private var showsCoverGlance = false
    /// How far the open-flat spread's page turn has run, 0 to 1. At rest it is 1.
    @State private var spreadTurnPhase: Double = 1
    @State private var spreadTurnIsForward = true
    private let incomingProgress: CookModeProgress?
    /// The scale the recipe page shows. Cook mode opens at it, and a scale picked here goes back to the page.
    private let recipePageScale: Double?
    private let progressDidChange: (CookModeProgress) -> Void
    private let scaleDidChange: (Double) -> Void
    private let shoppingViewModel: ShoppingSurfaceViewModel
    private let performShoppingAction: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    private let close: () -> Void

    /// How much of the next step's page shows at the right edge, so the cook can see there is more.
    private static let pagePeek: CGFloat = 12
    private static let pageGap: CGFloat = 8
    private static let pageInset: CGFloat = 12

    init(
        viewModel: CookModeViewModel,
        incomingProgress: CookModeProgress? = nil,
        recipePageScale: Double? = nil,
        progressDidChange: @escaping (CookModeProgress) -> Void = { _ in },
        scaleDidChange: @escaping (Double) -> Void = { _ in },
        shoppingViewModel: ShoppingSurfaceViewModel,
        performShoppingAction: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome = { _ in .synced },
        close: @escaping () -> Void = {}
    ) {
        recipe = viewModel.recipe
        _progress = State(initialValue: viewModel.progress)
        _stepTimers = ObservedObject(wrappedValue: CookModeSessionCenter.shared.stepTimers)
        self.incomingProgress = incomingProgress
        self.recipePageScale = recipePageScale
        self.progressDidChange = progressDidChange
        self.scaleDidChange = scaleDidChange
        self.shoppingViewModel = shoppingViewModel
        self.performShoppingAction = performShoppingAction
        self.close = close
    }

    var body: some View {
        cookModeBody
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.page)
        .toolbar {
            ToolbarItem(placement: .principal) {
                stepProgressRail
            }
            // Task 8 puts the voice "next" mic beside More.
            ToolbarItem(placement: .primaryAction) {
                cookMoreMenu
            }
        }
        .onChange(of: incomingProgress) { _, incoming in
            // Progress from another device arrives through the store. The step, scale and checked
            // ingredients follow it; completed steps stay as they are on this device. A change made
            // here has already reached the store, so it matches and is ignored.
            guard let incoming, !incoming.syncProgress.isSame(as: progress.syncProgress) else {
                return
            }
            progress = progress.applyingSyncProgress(incoming.syncProgress, updatedAt: incoming.updatedAt)
        }
        .keepsScreenAwake()
        .kitchenHaptic(.stepTurned, trigger: progress.currentStepID)
        .kitchenHaptic(.ingredientChecked, trigger: localCheckCount)
        .kitchenHaptic(.timerStarted, trigger: runningTimerCount) { before, after in after > before }
        .kitchenHaptic(.cookFinished, trigger: isFinished) { _, finished in finished }
        .onAppear(perform: normalizeProgressForCurrentRecipe)
        .onAppear(perform: openAtRecipePageScale)
        .onChange(of: isTouchingPager) { _, touching in
            if !touching {
                pageTurnTapGuard.touchEnded()
            }
        }
        .onChange(of: progress.scaleFactor) { _, scale in
            scaleDidChange(scale)
        }
        .onAppear(perform: registerCookModeSession)
        .onDisappear {
            CookModeSessionCenter.shared.unregister()
        }
        .onChange(of: progress) { _, _ in
            CookModeSessionCenter.shared.publishSession()
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

    /// Cook mode follows the hinge (see "Duo postures" in docs/native-design-language.md). Folded shut mid-cook, the
    /// cover becomes a kitchen timer. Stood half-open on the counter (or laid open tall), the step goes above the
    /// fold and the controls below it. Laid open wide, it is a spread whose page turns. Everywhere else, and on a
    /// phone with no hinge, cook mode is the single page. The step, the checks and running timers live in this view
    /// and the system, so they carry across every change of posture.
    private var cookModeBody: some View {
        GeometryReader { proxy in
            let reading = foldReading.applyingForcedHinge
            let tabletop = TabletopLayout.resolve(
                width: Double(proxy.size.width),
                height: Double(proxy.size.height),
                hinge: reading.tabletopHinge,
                band: reading.band
            )
            Group {
                if showsCoverGlance, currentStep != nil {
                    cookModeCoverGlance
                } else if tabletop.isSplit {
                    cookModeTabletop(tabletop)
                } else {
                    standardCookModeBody
                }
            }
            .kitchenTransition(.opacity)
        }
        .readingFold($foldReading)
        .onChange(of: foldReading.applyingForcedHinge.posture, initial: true) { old, new in
            updateCoverGlance(from: old, to: new)
#if DEBUG
            CookTimerProbe.record(posture: new, timers: timerBoard.ordered)
#endif
        }
        .onChange(of: currentIndex) { old, new in
            playSpreadTurn(forward: new > old)
        }
    }

    /// The cover glance starts when the hinge closes while cook mode is open, not when cook mode opens on a closed
    /// phone, where the full page is what the cook came for. A DEBUG launch forced closed shows it from the start.
    private func updateCoverGlance(from old: CookPosture, to new: CookPosture) {
        let foldedShut = new == .closedGlance && old != .closedGlance
        let launchedClosed = new == .closedGlance && old == new && FoldReading.forcedHinge == .closed
        let glance = new == .closedGlance && (foldedShut || launchedClosed || showsCoverGlance)
        guard glance != showsCoverGlance else {
            return
        }
        withAnimation(KitchenMotion.animation(.glide, reduceMotion: accessibilityReduceMotion)) {
            showsCoverGlance = glance
        }
    }

    /// Compact iPhone turns steps by swipe and has no dock. Regular width and Mac keep the dock (Back, Done, Next)
    /// under the same pages, and a wide regular screen opens as a cookbook spread.
    @ViewBuilder private var standardCookModeBody: some View {
        if usesEmbeddedSpoonDock {
#if os(macOS)
            cookPager
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    cookModeBottomActionRail
                }
#else
            SpreadLayoutReader(isRegularWidth: true) { layout in
                if layout.isSpread {
                    cookModeSpread(layout)
                } else {
                    cookPager
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            cookModeBottomActionRail
                        }
                }
            }
#endif
        } else {
            cookPager
        }
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

    /// The same spring the recipe page and the web use when a checked ingredient moves to the bottom.
    private var ingredientChecklistAnimation: Animation? {
        KitchenTableTheme.Checklist.reorder(reduceMotion: accessibilityReduceMotion)
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

    private var currentIndex: Int {
        guard let currentStep, let index = recipe.steps.firstIndex(where: { $0.id == currentStep.id }) else {
            return 0
        }
        return index
    }

    private var canAdvance: Bool {
        progress.currentStepID != recipe.steps.last?.id
    }

    private var isLastStep: Bool {
        currentIndex == recipe.steps.count - 1
    }

    private var isFinished: Bool {
        CookSessionSnapshot.isFinished(recipe: recipe, progress: progress)
    }

    /// False on compact iPhone, where a swipe turns the step; the dock stays on regular width and Mac.
    private var usesEmbeddedSpoonDock: Bool {
#if os(iOS)
        horizontalSizeClass != .compact
#else
        true
#endif
    }

    private var completedStepIndexes: Set<Int> {
        let completed = Set(progress.completedStepIDs)
        return Set(recipe.steps.indices.filter { completed.contains(recipe.steps[$0].id) })
    }

    /// The running timers for this recipe, read from the end dates recorded when each alarm was set.
    private var timerBoard: CookTimerBoard {
        CookModeSessionCenter.shared.timerClock.board(recipe: recipe, alarmIDsByStep: stepTimers.alarmIDsByStep)
    }

    private var runningTimerCount: Int {
        stepTimers.runningStepIDs(forRecipe: recipe.id).count
    }

    /// The other steps' running timers, for the stack above the step card.
    private var otherRunningTimers: [CookTimerEntry] {
        let currentKey = currentStep.map(stepTimerKey)
        return timerBoard.ordered.filter { $0.id != currentKey }
    }

    private func pageViewModel(for step: RecipeStep) -> CookModeViewModel {
        guard step.id != currentStep?.id else {
            return viewModel
        }
        let shown = (try? progress.selectingStep(id: step.id, updatedAt: progress.updatedAt)) ?? progress
        return CookModeViewModel(recipe: recipe, progress: shown)
    }

    // MARK: Header

    private var compactTaskHeader: some View {
        taskHeader(viewModel)
    }

    /// The recipe's name and "Step N of M" as one quiet line above the step. On Mac it also carries Close, which the
    /// window has no toolbar button for.
    private func taskHeader(_ model: CookModeViewModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(recipe.title) · \(model.stepProgressLabel)")
                .font(KitchenTableTheme.meta)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("cook.step.meta")

#if os(macOS)
            Spacer(minLength: 12)
            macOSCookModeCloseButton
#endif
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

    /// One segment per step, brass for the steps done, in the slim top bar.
    private var stepProgressRail: some View {
        CookStepSegments(count: recipe.steps.count, currentIndex: currentIndex, completedIndexes: completedStepIndexes)
            .accessibilityValue(viewModel.recipeProgressLabel)
    }

    /// Where you are in the recipe, for the tabletop step half and the spread: the step count, the recipe's name and
    /// the step segments.
    private var cookContextHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            compactTaskHeader
            stepProgressRail
            shoppingStatus
        }
    }

    /// Scale and the shopping action live here, off the cooking surface.
    private var cookMoreMenu: some View {
        Menu {
            Picker(selection: scaleBinding) {
                ForEach(scaleChoices, id: \.self) { factor in
                    Text("\(factor.formatted(.number.precision(.fractionLength(0...2))))×").tag(factor)
                }
            } label: {
                Label("Scale", systemImage: "person.2")
            }
            .pickerStyle(.menu)

            Button {
                addRecipeIngredients(scaleFactor: progress.scaleFactor)
            } label: {
                Label("Add to list", systemImage: "cart.badge.plus")
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .accessibilityLabel("More cook options")
        .accessibilityIdentifier("cook.more")
    }

    private var scaleChoices: [Double] {
        Array(Set([0.5, 1, 1.5, 2, 3, 4, progress.scaleFactor])).sorted()
    }

    private var scaleBinding: Binding<Double> {
        Binding(
            get: { progress.scaleFactor },
            set: { updateProgress(progress.settingScaleFactor($0, updatedAt: timestamp())) }
        )
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

    // MARK: Pager

    /// The steps as pages side by side. A drag tracks the finger 1:1, and on release `CookPageTurn` picks the page from
    /// how far and how fast it went, one step at most. Past the first or last step the page resists like a rubber
    /// band. Under Reduce Motion the step crossfades in place and swipes still turn it.
    private var cookPager: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let pageWidth = max(width - Self.pageInset - Self.pageGap - Self.pagePeek, 1)
            Group {
                if accessibilityReduceMotion || recipe.steps.count < 2 {
                    if let currentStep {
                        cookPage(currentStep, isCurrent: true, height: height)
                            .frame(width: max(width - Self.pageInset * 2, 1), height: height)
                            .id(currentStep.id)
                            .kitchenTransition(.opacity)
                            .frame(width: width, height: height)
                    }
                } else {
                    HStack(alignment: .top, spacing: Self.pageGap) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                            Group {
                                if abs(index - currentIndex) <= 1 {
                                    cookPage(step, isCurrent: index == currentIndex, height: height)
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: pageWidth, height: height)
                        }
                    }
                    .fixedSize()
                    .offset(x: Self.pageInset - CGFloat(currentIndex) * (pageWidth + Self.pageGap) + pageDrag.offset)
                    .frame(width: width, height: height, alignment: .topLeading)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(pageTurnGesture(pageWidth: pageWidth))
            .simultaneousGesture(touchTrackingGesture)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next step") {
            turnPage(to: currentIndex + 1)
        }
        .accessibilityAction(named: "Previous step") {
            turnPage(to: currentIndex - 1)
        }
    }

    private func pageTurnGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .updating($pageDrag) { value, drag, _ in
                if drag.isHorizontal == nil {
                    drag.isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                }
                guard drag.isHorizontal == true, !accessibilityReduceMotion else {
                    return
                }
                drag.offset = trackedPageOffset(value.translation.width, pageWidth: pageWidth)
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                let target = CookPageTurn.target(
                    from: currentIndex,
                    count: recipe.steps.count,
                    dragFraction: Double(value.translation.width / pageWidth),
                    velocity: Double(value.velocity.width)
                )
                turnPage(to: target)
            }
    }

    /// Follows every touch on the pager from finger down, so a control on a page can tell a tap from the end of a
    /// drag. The global space keeps a touch's start fixed while the page moves under it.
    private var touchTrackingGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($isTouchingPager) { _, touching, _ in touching = true }
            .onChanged { pageTurnTapGuard.touchMoved($0) }
    }

    /// 1:1 between the pages; a rubber band before the first and after the last.
    private func trackedPageOffset(_ translation: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let pastFirst = currentIndex == 0 && translation > 0
        let pastLast = currentIndex == recipe.steps.count - 1 && translation < 0
        guard pastFirst || pastLast else {
            return translation
        }
        return CGFloat(CookPageTurn.rubberBand(offset: Double(translation), limit: Double(pageWidth)))
    }

    private func turnPage(to index: Int) {
        guard recipe.steps.indices.contains(index), index != currentIndex else {
            return
        }
        let next = (try? progress.selectingStep(id: recipe.steps[index].id, updatedAt: timestamp())) ?? progress
        withAnimation(pageTurnAnimation) {
            updateProgress(next)
        }
    }

    /// The page turn's spring, or its crossfade under Reduce Motion. A DEBUG demo turn plays it slowly enough to
    /// photograph halfway.
    private var pageTurnAnimation: Animation {
        if let duration = Self.demoPageTurnDuration {
            return .easeInOut(duration: duration)
        }
        return KitchenMotion.animation(.pageTurn, reduceMotion: accessibilityReduceMotion)
    }

    /// `-SpoonjoyDemoPageTurn <seconds>` (DEBUG): ten seconds after the spread opens it turns one page by itself, over
    /// that many seconds, so the Duo tour can photograph the turn, or its crossfade under Reduce Motion, halfway.
    private static let demoPageTurnDuration: Double? = {
#if DEBUG
        let seconds = UserDefaults.standard.double(forKey: "SpoonjoyDemoPageTurn")
        return seconds > 0 ? seconds : nil
#else
        nil
#endif
    }()

    private func playDemoPageTurn() async {
        guard Self.demoPageTurnDuration != nil else {
            return
        }
        try? await Task.sleep(for: .seconds(10))
        turnPage(to: currentIndex + 1 < recipe.steps.count ? currentIndex + 1 : currentIndex - 1)
    }

    /// One step's page, top to bottom: where you are, the step title in brass, the step in large serif, its timer
    /// ring, then the step's checks in the thumb zone. A neighbouring page is a dimmed, inert preview.
    private func cookPage(_ step: RecipeStep, isCurrent: Bool, height: CGFloat) -> some View {
        let model = pageViewModel(for: step)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    taskHeader(model)
                    if isCurrent {
                        shoppingStatus
                    }
                    stepHeading(step)
                    Text(step.description)
                        .font(KitchenTableTheme.cookStep)
                        .foregroundStyle(KitchenTableTheme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(isCurrent ? "cook.step.text" : "")
                }

                if let timer = model.systemTimer {
                    stepTimer(timer, step: step, model: model, isCurrent: isCurrent)
                }

                Spacer(minLength: 8)

                if isCurrent {
                    CookTimerStack(timers: otherRunningTimers)
                }
                stepCard(model, isCurrent: isCurrent)
                if isCurrent && isLastStep {
                    finishControl
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .background(KitchenTableTheme.raised, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel * 2))
        .overlay(
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel * 2)
                .stroke(KitchenTableTheme.hairline, lineWidth: KitchenTableTheme.hairlineWidth)
        )
        .scaleEffect(isCurrent ? 1 : 0.965)
        .opacity(isCurrent ? 1 : 0.55)
        .allowsHitTesting(isCurrent)
        .accessibilityHidden(!isCurrent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isCurrent ? "cook.page" : "cook.page.preview")
    }

    private func stepHeading(_ step: RecipeStep) -> some View {
        Text(step.stepTitle ?? "Step \(step.stepNum)")
            .font(KitchenTableTheme.control)
            .foregroundStyle(KitchenTableTheme.brass)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Current cooking step \(step.stepNum), \(step.stepTitle ?? "Step")")
    }

    private func stepTimer(_ timer: CookModeSystemTimerViewModel, step: RecipeStep, model: CookModeViewModel, isCurrent: Bool) -> some View {
        CookModeSystemTimer(
            timer: timer,
            stepTimers: stepTimers,
            stepKey: stepTimerKey(step),
            entry: { timerBoard.ordered.first { $0.id == stepTimerKey(step) } },
            hint: Self.startHint(ingredientCount: step.ingredients.count),
            isInteractive: isCurrent,
            tapGuard: pageTurnTapGuard,
            autoStartError: autoStartErrors[step.id]
        ) {
            autoStartErrors[step.id] = nil
            return try await scheduleSystemTimer(timer, step: step).message(startedMessage: "\(timer.durationLabel) timer started.")
        } cancel: {
            try cancelSystemTimer(step: step)
        }
        .id(timer.stepID)
    }

    static func startHint(ingredientCount: Int) -> String {
        switch ingredientCount {
        case 0: "Tap to start"
        case 1: "Tap to start or check it off"
        case 2: "Tap to start or check both"
        default: "Tap to start or check all \(ingredientCount)"
        }
    }

    @ViewBuilder private var currentStepCard: some View {
        if let currentStep {
            VStack(alignment: .leading, spacing: 14) {
                stepHeading(currentStep)
                Text(currentStep.description)
                    .font(KitchenTableTheme.cookInstruction)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                if let timer = viewModel.systemTimer {
                    stepTimer(timer, step: currentStep, model: viewModel, isCurrent: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: Step card

    /// "For this step": the step's checks, where the thumb reaches. Checking every ingredient starts the step's timer.
    @ViewBuilder private func stepCard(_ model: CookModeViewModel, isCurrent: Bool) -> some View {
        let rows = model.stepOutputChecklistRows + model.ingredientChecklistRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("For this step · \(rows.filter(\.isChecked).count) of \(rows.count)")
                    .font(KitchenTableTheme.meta.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .contentTransition(.numericText())
                    .kitchenAnimation(.snappy, value: rows.filter(\.isChecked).count)
                    .padding(.bottom, 4)
                    .accessibilityIdentifier(isCurrent ? "cook.step.card.count" : "")
                if isCurrent {
                    dependencyChecklist
                    ingredientChecklist
                } else {
                    ForEach(rows, id: \.id) { row in
                        Toggle(isOn: .constant(row.isChecked)) {
                            CookModeIngredientChecklistLabel(row: row)
                        }
                        .toggleStyle(.cookIngredient)
                    }
                }
            }
            .padding(16)
            .background(KitchenTableTheme.page, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel * 2))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(isCurrent ? "cook.step.card" : "")
        }
    }

    @ViewBuilder private var dependencyChecklist: some View {
        if !viewModel.stepOutputChecklistRows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.stepOutputChecklistRows, id: \.id) { row in
                    Toggle(isOn: stepOutputBinding(for: row)) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(KitchenTableTheme.brass)
                                .accessibilityHidden(true)
                            Text(row.title)
                                .font(KitchenTableTheme.bodyNote)
                                .foregroundStyle(KitchenTableTheme.ink)
                        }
                    }
                    .toggleStyle(.cookIngredient)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(ingredientChecklistAnimation, value: viewModel.stepOutputChecklistRows)
        }
    }

    @ViewBuilder private var ingredientChecklist: some View {
        if !viewModel.ingredientChecklistRows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.ingredientChecklistRows, id: \.id) { row in
                    Toggle(isOn: ingredientBinding(for: row)) {
                        CookModeIngredientChecklistLabel(row: row)
                    }
                    .toggleStyle(.cookIngredient)
                    .accessibilityIdentifier("cookMode.ingredient")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(ingredientChecklistAnimation, value: viewModel.ingredientChecklistRows)
        }
    }

    /// The last page ends the cook: Finish marks the last step done, and Done goes back to the recipe.
    @ViewBuilder private var finishControl: some View {
        if isFinished {
            Button(action: close) {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
            .accessibilityHint("Returns to the recipe.")
            .accessibilityIdentifier("cook.finish.done")
        } else {
            Button(action: markCurrentStepComplete) {
                Label("Finish cooking", systemImage: "checkmark.circle")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
            .accessibilityHint("Marks the last step done.")
            .accessibilityIdentifier("cook.finish")
        }
    }

    // MARK: Dock and actions

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
        .background(KitchenTableTheme.page)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var canGoBack: Bool {
        currentIndex > 0
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
        withAnimation(KitchenMotion.animation(.pageTurn, reduceMotion: accessibilityReduceMotion)) {
            updateProgress(viewModel.progressAfterSelectingNext(updatedAt: timestamp()))
        }
    }

    private func previous() {
        withAnimation(KitchenMotion.animation(.pageTurn, reduceMotion: accessibilityReduceMotion)) {
            updateProgress(viewModel.progressAfterSelectingPrevious(updatedAt: timestamp()))
        }
    }

    private func ingredientBinding(for row: CookModeChecklistRow) -> Binding<Bool> {
        Binding(
            get: { currentIngredientCheckedState(for: row) },
            set: { checked in
                guard pageTurnTapGuard.allowsTap() else { return }
                if checked { localCheckCount += 1 }
                progressAfterTogglingIngredient(id: row.id, checked: checked)
            }
        )
    }

    private func stepOutputBinding(for row: CookModeChecklistRow) -> Binding<Bool> {
        Binding(
            get: { currentStepOutputCheckedState(for: row) },
            set: { checked in
                guard pageTurnTapGuard.allowsTap() else { return }
                if checked { localCheckCount += 1 }
                progressAfterTogglingStepOutputUse(id: row.id, checked: checked)
            }
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

    /// Every change made on this device (a tap, a swipe, Siri, the Live Activity) comes through here, so the checks
    /// that complete a step start its timer whichever way they were made.
    private func updateProgress(_ nextProgress: CookModeProgress) {
        let previousProgress = progress
        progress = nextProgress
        progressDidChange(nextProgress)
        CookModeSessionCenter.shared.checksChanged(from: previousProgress, to: nextProgress)
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

    private func openAtRecipePageScale() {
        let opened = progress.openingAtRecipePageScale(recipePageScale, updatedAt: timestamp())
        if opened != progress {
            updateProgress(opened)
        }
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func clientMutationID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }

    private func stepTimerKey(_ step: RecipeStep) -> String {
        CookStepTimerRegistry.stepKey(recipeID: recipe.id, stepID: step.id)
    }

    /// Sets the step's system alarm unless one already runs for it, so a second tap or a Siri request never sets a second alarm.
    @MainActor private func scheduleSystemTimer(_ timer: CookModeSystemTimerViewModel, step: RecipeStep) async throws -> CookStepTimerStartOutcome {
        try await CookModeSessionCenter.shared.stepTimers.start(step: stepTimerKey(step)) {
            let alarmID = CookModeSessionCenter.usesJourneyAlarmFixture
                ? UUID()
                : try await CookModeAlarmKitTimerScheduler.schedule(timer: timer, recipe: recipe, step: step)
            CookModeSessionCenter.shared.updateTimerClock {
                $0.start(alarmID: alarmID, duration: TimeInterval(timer.durationSeconds), now: Date())
            }
            return alarmID
        }
    }

    @MainActor private func cancelSystemTimer(step: RecipeStep) throws {
        try CookModeSessionCenter.shared.stepTimers.cancel(step: stepTimerKey(step)) { alarmID in
            if CookModeSessionCenter.usesJourneyAlarmFixture {
                return
            }
            try CookModeAlarmKitTimerScheduler.cancel(alarmID: alarmID)
        }
    }

    /// Lets Siri, Shortcuts and the Live Activity drive this screen while it is open.
    private func registerCookModeSession() {
        CookModeSessionCenter.shared.register(
            CookModeSessionCenter.Registration(
                viewModel: { viewModel },
                apply: { updateProgress($0) },
                startTimer: { timer in
                    // An auto-start can be for a step other than the one on screen, so the timer names its step.
                    guard let step = recipe.steps.first(where: { $0.id == timer.stepID }) ?? viewModel.activeStep else {
                        throw CookModeSessionError.notCooking
                    }
                    return try await scheduleSystemTimer(timer, step: step)
                },
                timerStartFailed: { stepID, message in
                    autoStartErrors[stepID] = message
                }
            )
        )
    }
}

/// The pager's drag in progress: whether it is a horizontal turn (decided on its first move) and how far it is.
private struct CookPageDrag {
    var isHorizontal: Bool?
    var offset: CGFloat = 0
}

/// Holds the pager's current touch (`CookPageTouch`) for the controls on its pages. It is a reference so a control's
/// action reads the touch as it is now, not as it was when the control's view was built, and so following the finger
/// does not redraw the screen.
@MainActor
final class CookPageTurnTapGuard {
    private var touch = CookPageTouch()

    func touchMoved(_ value: DragGesture.Value) {
        touch.moved(
            startX: Double(value.startLocation.x),
            startY: Double(value.startLocation.y),
            dx: Double(value.translation.width),
            dy: Double(value.translation.height)
        )
    }

    func touchEnded() {
        touch.ended(at: Date())
    }

    func allowsTap() -> Bool {
        touch.allowsTap(at: Date())
    }
}

// MARK: - Cookbook spread

extension CookModeView {
    /// Folded shut on the counter, the cover is a kitchen timer: the step's title in type you can read from the stove,
    /// its timer ring when the step has one, and Next. "Show step" brings back the whole page.
    @ViewBuilder private var cookModeCoverGlance: some View {
        if let currentStep {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(recipe.title) · \(currentIndex + 1) of \(recipe.steps.count)")
                        .spreadRunningHead()
                        .lineLimit(2)
                    Text(currentStep.stepTitle ?? "Step \(currentStep.stepNum)")
                        .font(.system(size: min(coverGlanceTitleSize, 88), weight: .bold, design: .serif))
                        .foregroundStyle(KitchenTableTheme.ink)
                        .lineLimit(4)
                        // A long word shrinks rather than breaking across lines on the narrow cover.
                        .minimumScaleFactor(0.5)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Current cooking step \(currentStep.stepNum), \(currentStep.stepTitle ?? "Step")")
                        .accessibilityIdentifier("cookMode.coverGlance.title")
                    if let timer = viewModel.systemTimer {
                        stepTimer(timer, step: currentStep, model: viewModel, isCurrent: true)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, KitchenTableTheme.pagePadding + 4)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                coverGlanceControls
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cookMode.coverGlance")
        }
    }

    /// Next fills the cover's width under the thumb; Show step sits under it.
    private var coverGlanceControls: some View {
        VStack(spacing: 10) {
            coverGlanceNext
            coverGlanceShowStep
        }
        .controlSize(.extraLarge)
        // The cover is narrow: past AX3 the extra-large buttons would cut their labels short. They stay thumb-sized,
        // and the step above still grows to the largest size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .padding(.horizontal, KitchenTableTheme.pagePadding + 4)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(KitchenTableTheme.page)
    }

    private var coverGlanceShowStep: some View {
        Button {
            withAnimation(KitchenMotion.animation(.glide, reduceMotion: accessibilityReduceMotion)) {
                showsCoverGlance = false
            }
        } label: {
            Label("Show step", systemImage: "text.alignleft")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
        .accessibilityHint("Shows the whole step and its checklist.")
        .accessibilityIdentifier("cookMode.coverGlance.showStep")
    }

    @ViewBuilder private var coverGlanceNext: some View {
        if isLastStep {
            finishControl
        } else {
            nextStepButton(identifier: "cookMode.coverGlance.next")
        }
    }

    // MARK: Step controls

    private func nextStepButton(identifier: String) -> some View {
        Button(action: advance) {
            Label("Next step", systemImage: "arrow.forward.circle.fill")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
        .disabled(!canAdvance)
        .accessibilityLabel("Move to the next step")
        .accessibilityIdentifier(identifier)
    }

    private func markDoneButton(identifier: String) -> some View {
        Button(action: markCurrentStepComplete) {
            Label("Mark done", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        .accessibilityLabel("Mark the current step done")
        .accessibilityIdentifier(identifier)
    }

    private func backStepButton(identifier: String) -> some View {
        Button(action: previous) {
            Label("Back step", systemImage: "chevron.backward.circle")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
        .disabled(!canGoBack)
        .accessibilityIdentifier(identifier)
    }

    /// Tabletop cook mode: the step on the half above the fold, angled toward the cook, and the checklist and step
    /// controls on the half below it, flat on the counter. Nothing sits on the fold. A swipe on the step turns it.
    private func cookModeTabletop(_ layout: TabletopLayout) -> some View {
        let topHeight = CGFloat(layout.top?.height ?? 0)
        let foldHeight = CGFloat(layout.fold?.height ?? 0)
        let bottomHeight = CGFloat(layout.bottom?.height ?? 0)
        return VStack(spacing: 0) {
            ViewThatFits(in: .vertical) {
                tabletopStepPage
                    .frame(maxHeight: .infinity, alignment: .center)
                ScrollView {
                    tabletopStepPage
                }
            }
            .frame(height: topHeight)
            .contentShape(Rectangle())
            .simultaneousGesture(pageTurnGesture(pageWidth: 320))
            .simultaneousGesture(touchTrackingGesture)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cookMode.tabletopStep")

            tabletopFoldRule
                .frame(height: foldHeight)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if dynamicTypeSize.isAccessibilitySize {
                            tabletopStackedControls
                        }
                        CookTimerStack(timers: otherRunningTimers)
                        stepCard(viewModel, isCurrent: true)
                        if isLastStep && !dynamicTypeSize.isAccessibilitySize {
                            finishControl
                        }
                    }
                    .padding(.horizontal, KitchenTableTheme.pagePadding + 4)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                // The dock: the half on the counter wants the few large controls the dock carries. At accessibility
                // sizes its three buttons would cut their labels short, so the controls stack above the checklist.
                if !dynamicTypeSize.isAccessibilitySize {
                    cookModeBottomActionRail
                }
            }
            .frame(height: bottomHeight)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cookMode.tabletopControls")
        }
    }

    /// The tabletop controls at accessibility sizes, one to a row with whole labels: Next (or Finish cooking on the
    /// last step), Mark done, then Back.
    private var tabletopStackedControls: some View {
        VStack(spacing: 10) {
            if isLastStep {
                finishControl
            } else {
                nextStepButton(identifier: "cookMode.tabletop.next")
            }
            markDoneButton(identifier: "cookMode.tabletop.markDone")
            backStepButton(identifier: "cookMode.tabletop.back")
        }
        .controlSize(.large)
    }

    private var tabletopStepPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            cookContextHeader
            currentStepCard
                .id(currentStep?.id)
                .kitchenTransition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .padding(.horizontal, KitchenTableTheme.pagePadding + 4)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cook.page")
    }

    /// The hairline that marks the fold, like the gutter of an open spread.
    private var tabletopFoldRule: some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(KitchenTableTheme.spreadGutterRule)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

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
            .accessibilityElement(children: .contain)
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
            .background(KitchenTableTheme.page)
            .modifier(PageCurlSweep(
                phase: spreadCurlPhase(pageWidth: CGFloat(layout.trailingPage?.width ?? 1)),
                isForward: spreadCurlIsForward
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(pageTurnGesture(pageWidth: CGFloat(layout.trailingPage?.width ?? 1)))
            .simultaneousGesture(touchTrackingGesture)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cookSpread.stepPage")
            .accessibilityAction(named: "Next step") {
                turnPage(to: currentIndex + 1)
            }
            .accessibilityAction(named: "Previous step") {
                turnPage(to: currentIndex - 1)
            }
            .task {
                await playDemoPageTurn()
            }
        }
    }

    /// While a finger drags the right page it lifts up to halfway; a turned step then plays the rest of the turn.
    private func spreadCurlPhase(pageWidth: CGFloat) -> Double {
        guard !accessibilityReduceMotion else {
            return 1
        }
        if spreadTurnPhase < 1 {
            return spreadTurnPhase
        }
        let dragged = min(1, abs(pageDrag.offset) / max(pageWidth, 1))
        return dragged > 0 ? Double(dragged) / 2 : 1
    }

    private var spreadCurlIsForward: Bool {
        spreadTurnPhase < 1 ? spreadTurnIsForward : pageDrag.offset <= 0
    }

    /// Sweeps the curl's shadow across the right page as the step changes, like a page lifting off the spine. Under
    /// Reduce Motion nothing sweeps: the step page itself crossfades (`cookSpreadStepPage`'s transition, driven by the
    /// turn's crossfade animation).
    private func playSpreadTurn(forward: Bool) {
        guard !accessibilityReduceMotion else {
            return
        }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            spreadTurnIsForward = forward
            spreadTurnPhase = 0
        }
        Task { @MainActor in
            withAnimation(.easeInOut(duration: Self.demoPageTurnDuration ?? KitchenSpring.pageTurn.response)) {
                spreadTurnPhase = 1
            }
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
                        .foregroundStyle(KitchenTableTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                stepProgressRail
                shoppingStatus
            }

            if viewModel.stepOutputChecklistRows.isEmpty && viewModel.ingredientChecklistRows.isEmpty {
                Text("Nothing new to gather for this step.")
                    .font(KitchenTableTheme.instructionBody)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
            CookTimerStack(timers: otherRunningTimers)
            stepCard(viewModel, isCurrent: true)
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
                        .foregroundStyle(KitchenTableTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Current cooking step \(currentStep.stepNum), \(currentStep.stepTitle ?? "Step")")
                }
                Text(currentStep.description)
                    .font(KitchenTableTheme.cookInstruction)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                if let timer = viewModel.systemTimer {
                    CookModeSystemTimer(
                        timer: timer,
                        stepTimers: stepTimers,
                        stepKey: stepTimerKey(currentStep),
                        entry: { timerBoard.ordered.first { $0.id == stepTimerKey(currentStep) } },
                        hint: Self.startHint(ingredientCount: currentStep.ingredients.count),
                        isInteractive: true,
                        tapGuard: pageTurnTapGuard,
                        autoStartError: autoStartErrors[currentStep.id]
                    ) {
                        autoStartErrors[currentStep.id] = nil
                        return try await scheduleSystemTimer(timer, step: currentStep).message(startedMessage: "\(timer.durationLabel) timer started.")
                    } cancel: {
                        try cancelSystemTimer(step: currentStep)
                    }
                    .id(timer.stepID)
                }
                if isLastStep {
                    finishControl
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(currentStep.id)
            .kitchenTransition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    /// Back and Close at the outer corner of the left page, side by side when they fit and stacked when the text is
    /// too large, so they never push the page past its edge or into the gutter.
    private var cookSpreadLeadingControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                backStepButton(identifier: "cookSpread.back")
                    .fixedSize()
                cookSpreadCloseButton
                    .fixedSize()
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 10) {
                backStepButton(identifier: "cookSpread.back")
                cookSpreadCloseButton
            }
        }
        .controlSize(.large)
    }

    private var cookSpreadCloseButton: some View {
        Button(action: close) {
            Label("Close", systemImage: "text.book.closed")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
        .accessibilityLabel("Return to recipe detail")
        .accessibilityIdentifier("cookSpread.close")
    }

    /// Mark done and Next at the outer corner of the right page, stacked when the text is too large. On the last step
    /// the page's Finish cooking is the one filled button, so Next steps aside.
    private var cookSpreadTrailingControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                markDoneButton(identifier: "cookSpread.markDone")
                    .fixedSize()
                if !isLastStep {
                    nextStepButton(identifier: "cookSpread.next")
                        .fixedSize()
                }
            }
            VStack(alignment: .trailing, spacing: 10) {
                if !isLastStep {
                    nextStepButton(identifier: "cookSpread.next")
                }
                markDoneButton(identifier: "cookSpread.markDone")
            }
        }
        .controlSize(.large)
    }
}

#if DEBUG
/// Appends each posture cook mode takes, with every running timer's end date, to `tmp/spoonjoy-cook-timer.log` in the
/// app's data container. The Duo tour folds the phone with a timer running and fails if an end date moves.
enum CookTimerProbe {
    static func record(posture: CookPosture, timers: [CookTimerEntry]) {
        let ends = timers
            .map { "\($0.id)=\(String(format: "%.3f", $0.endsAt.timeIntervalSince1970))" }
            .joined(separator: ",")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-cook-timer.log")
        let line = Data("posture=\(posture) timers=\(ends)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }
}
#endif

private struct CookModeIngredientChecklistLabel: View {
    let row: CookModeChecklistRow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At accessibility sizes the amount goes under the name, so the name never breaks mid-word beside it.
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    title
                    quantity
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    title
                        .lineLimit(3)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    quantity
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: some View {
        Text(row.title)
            .font(KitchenTableTheme.bodyNote)
            .foregroundStyle(KitchenTableTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var quantity: some View {
        if !row.quantityText.isEmpty {
            Text(row.quantityText)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.ink2)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
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

/// The step's one timer, as a ring. Tapping the ring sets the step's system alarm; checking every ingredient sets it
/// too. While it runs the digits count down and roll, the arc shrinks, and Cancel ends the alarm.
private struct CookModeSystemTimer: View {
    let timer: CookModeSystemTimerViewModel
    @ObservedObject var stepTimers: CookStepTimerRegistry
    let stepKey: String
    /// The running timer's end date and length, read when the ring redraws.
    let entry: () -> CookTimerEntry?
    let hint: String
    let isInteractive: Bool
    var tapGuard = CookPageTurnTapGuard()
    /// Why this step's timer did not start by itself, until the ring is tapped.
    var autoStartError: String?
    let schedule: () async throws -> String
    let cancel: () throws -> Void

    @State private var isScheduling = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 10) {
            timerAction
                .frame(maxWidth: .infinity)

            // While the step's alarm runs, the ring is the status, so the message from setting it is not repeated.
            if let statusMessage, !stepTimerIsSet {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
                    .accessibilityIdentifier("cookMode.timer.status")
            } else if let errorMessage = errorMessage ?? (stepTimerIsSet ? nil : autoStartError) {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
                    .accessibilityIdentifier("cookMode.timer.error")
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(!isInteractive)
    }

    private var stepTimerIsSet: Bool {
        stepTimers.alarmID(forStep: stepKey) != nil
    }

    private var durationClock: String {
        CookTimerDigits.clock(TimeInterval(timer.durationSeconds))
    }

    private func scheduleTimer() {
        guard tapGuard.allowsTap() else { return }
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

    /// Cancelling ends the system alarm, which also removes its Lock Screen and Dynamic Island countdown.
    private func cancelTimer() {
        guard tapGuard.allowsTap() else { return }
        statusMessage = nil
        errorMessage = nil
        do {
            try cancel()
            statusMessage = "\(timer.durationLabel) timer cancelled."
        } catch {
            errorMessage = "Could not cancel the system timer."
        }
    }

    @ViewBuilder private var timerAction: some View {
#if os(iOS)
        if #available(iOS 26.1, *) {
            if stepTimers.alarmID(forStep: stepKey) != nil {
                runningRing
            } else {
                startButton
            }
        } else {
            unavailableCue
        }
#else
        unavailableCue
#endif
    }

#if os(iOS)
    /// The step already has a system alarm, so the ring counts it down and offers Cancel; a second alarm cannot be set.
    private var runningRing: some View {
        VStack(spacing: 10) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let running = entry()
                CookTimerRingFace(fraction: running.map { Self.remainingFraction($0, now: context.date) } ?? 1) {
                    VStack(spacing: 4) {
                        Group {
                            if let running {
                                CookTimerDigits(timer: running, font: KitchenTableTheme.timer)
                            } else {
                                Text(durationClock)
                                    .font(KitchenTableTheme.timer)
                            }
                        }
                        .foregroundStyle(KitchenTableTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityIdentifier("cook.timer.running")

                        Text(running?.isPaused == true ? "Paused" : "\(timer.durationLabel) timer")
                            .font(KitchenTableTheme.meta)
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cook.timer.ring")

            cancelButton
        }
    }

    private static func remainingFraction(_ entry: CookTimerEntry, now: Date) -> Double {
        guard entry.duration > 0 else {
            return 1
        }
        let remaining = entry.pausedRemaining ?? max(0, entry.endsAt.timeIntervalSince(now))
        return remaining / entry.duration
    }

    /// "Cancel timer", or "Cancel" where that does not fit (the largest text on a narrow screen). A button wider than
    /// the page would widen the whole page and clip it.
    private var cancelButton: some View {
        ViewThatFits(in: .horizontal) {
            cancelButton(title: "Cancel timer")
            cancelButton(title: "Cancel")
        }
    }

    private func cancelButton(title: String) -> some View {
        Button(role: .cancel) {
            cancelTimer()
        } label: {
            Label(title, systemImage: "xmark.circle")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
        .fixedSize()
        .accessibilityLabel("Cancel the \(timer.durationLabel) timer")
        .accessibilityIdentifier("cookMode.timer.cancel")
    }

    /// The ring before the timer runs: the step's length in a faint track. The whole ring is the button.
    private var startButton: some View {
        VStack(spacing: 10) {
            Button {
                scheduleTimer()
            } label: {
                CookTimerRingFace(fraction: nil) {
                    VStack(spacing: 4) {
                        if isScheduling {
                            ProgressView()
                                .accessibilityLabel("Setting system timer")
                        } else {
                            Text(durationClock)
                                .font(KitchenTableTheme.timer)
                                .foregroundStyle(KitchenTableTheme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Label("Start", systemImage: "play.fill")
                                .font(KitchenTableTheme.meta.weight(.semibold))
                                .foregroundStyle(KitchenTableTheme.brass)
                        }
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isScheduling)
            .accessibilityLabel(timer.startButtonTitle)
            .accessibilityIdentifier("cook.timer.ring")

            if isInteractive {
                Text(hint)
                    .font(KitchenTableTheme.meta)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cook.timer.hint")
            }
        }
    }
#endif

    /// Without system alarms (Mac, older iOS) the ring still shows the step's length, and says why it cannot start.
    private var unavailableCue: some View {
        VStack(spacing: 10) {
            CookTimerRingFace(fraction: nil) {
                Text(durationClock)
                    .font(KitchenTableTheme.timer)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .accessibilityHidden(true)
            Label(timer.systemUnavailableMessage, systemImage: "iphone")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.ink2)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum CookModeAlarmKitTimerScheduler {
    @MainActor static func schedule(timer: CookModeSystemTimerViewModel, recipe: Recipe, step: RecipeStep) async throws -> UUID {
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
            guard let alarmID else {
                throw CookModeSystemTimerSchedulingError.schedulingFailed
            }
            return alarmID
        }
#endif
        throw CookModeSystemTimerSchedulingError.unsupportedPlatform
    }

    @MainActor static func cancel(alarmID: UUID) throws {
#if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            try AlarmManager.shared.cancel(id: alarmID)
            return
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

/// The page curl on the open-flat spread: the right page lifts off the spine toward the cook and a soft shadow
/// sweeps across it, from the outer edge to the fold on a forward turn and back again on a turn back. At 0 and 1
/// the page lies flat with no shadow.
private struct PageCurlSweep: ViewModifier, Animatable {
    nonisolated var phase: Double
    nonisolated let isForward: Bool

    nonisolated var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    /// How far the lifted page tilts at the middle of a turn.
    private static let liftDegrees = 14.0

    func body(content: Content) -> some View {
        let lift = sin(.pi * min(max(phase, 0), 1))
        return content
            .rotation3DEffect(
                .degrees((isForward ? -1 : 1) * Self.liftDegrees * lift),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.6
            )
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let band = min(120, width * 0.35)
                    let travel = isForward ? 1 - phase : phase
                    LinearGradient(
                        stops: [
                            .init(color: KitchenTableTheme.foldShadow.opacity(0), location: 0),
                            .init(color: KitchenTableTheme.foldShadow, location: 0.6),
                            .init(color: KitchenTableTheme.foldShadow.opacity(0), location: 1)
                        ],
                        startPoint: isForward ? .trailing : .leading,
                        endPoint: isForward ? .leading : .trailing
                    )
                    .frame(width: band)
                    .offset(x: width * travel - band / 2)
                    .opacity(lift)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}
