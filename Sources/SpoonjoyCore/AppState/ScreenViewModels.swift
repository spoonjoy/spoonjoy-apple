import Foundation

public struct RecipeStepSection: Equatable {
    public let stepNumber: Int
    public let step: RecipeStep
}

public struct RecipeDetailViewModel: Equatable {
    public let recipe: Recipe

    public init(recipe: Recipe) {
        self.recipe = recipe
    }

    public var id: String {
        recipe.id
    }

    public var title: String {
        recipe.title
    }

    public var startCookingRoute: AppRoute {
        .recipeDetail(id: recipe.id, presentation: .cook)
    }

    public var stepSections: [RecipeStepSection] {
        recipe.steps.enumerated().map { index, step in
            RecipeStepSection(stepNumber: index + 1, step: step)
        }
    }
}

public struct CookModeChecklistRow: Equatable {
    public let id: String
    public let title: String
    public let quantityText: String
    public let isChecked: Bool
}

public struct CookModeSystemTimerViewModel: Equatable {
    public let stepID: String
    public let durationMinutes: Int
    public let durationSeconds: Int

    public var durationLabel: String {
        "\(durationMinutes) min"
    }

    public var startButtonTitle: String {
        "Set \(durationLabel) timer"
    }

    public var systemUnavailableMessage: String {
        "Timer unavailable."
    }
}

public struct CookModeViewModel: Equatable {
    public let recipe: Recipe
    public let progress: CookModeProgress

    public init(recipe: Recipe, progress: CookModeProgress) {
        self.recipe = recipe
        self.progress = progress
    }

    public var currentStepID: String? {
        progress.currentStepID
    }

    public var completionFraction: Double {
        progress.completionFraction
    }

    public var activeStep: RecipeStep? {
        guard let currentStepID else {
            return recipe.steps.first
        }
        return recipe.steps.first { $0.id == currentStepID } ?? recipe.steps.first
    }

    public var stepProgressLabel: String {
        guard let activeStep,
              let index = recipe.steps.firstIndex(where: { $0.id == activeStep.id }) else {
            return "No steps"
        }

        return "Step \(index + 1) of \(recipe.steps.count)"
    }

    public var recipeProgressLabel: String {
        checkedLabel(checked: recipeCheckedCount, total: recipeCheckableCount)
    }

    public var recipeCheckoffFraction: Double {
        guard recipeCheckableCount > 0 else {
            return 0
        }
        return Double(recipeCheckedCount) / Double(recipeCheckableCount)
    }

    public var currentPageProgressLabel: String {
        guard let activeStep else {
            return checkedLabel(checked: 0, total: 0)
        }

        let activeIngredientIDs = Set(activeStep.ingredients.map(\.id))
        let activeOutputUseIDs = Set(activeStep.usingSteps.map(\.id))
        let checkedCount = progress.checkedIngredientIDs.filter { activeIngredientIDs.contains($0) }.count +
            progress.checkedStepOutputUseIDs.filter { activeOutputUseIDs.contains($0) }.count
        return checkedLabel(checked: checkedCount, total: activeIngredientIDs.count + activeOutputUseIDs.count)
    }

    public var ingredientChecklistRows: [CookModeChecklistRow] {
        guard let activeStep else {
            return []
        }

        let checkedIDs = Set(progress.checkedIngredientIDs)
        let checkedOrder = Dictionary(uniqueKeysWithValues: progress.checkedIngredientIDs.enumerated().map { ($1, $0) })
        return activeStep.ingredients
            .enumerated()
            .map { index, ingredient in
                (
                    index,
                    CookModeChecklistRow(
                        id: ingredient.id,
                        title: ingredient.name,
                        quantityText: CookModeQuantityFormatter.quantityText(
                            quantity: ingredient.quantity * progress.scaleFactor,
                            unit: ingredient.unit
                        ),
                        isChecked: checkedIDs.contains(ingredient.id)
                    )
                )
            }
            .sorted { left, right in
                if left.1.isChecked != right.1.isChecked {
                    return !left.1.isChecked && right.1.isChecked
                }
                if left.1.isChecked, right.1.isChecked {
                    return checkedOrder[left.1.id]! < checkedOrder[right.1.id]!
                }
                return left.0 < right.0
            }
            .map(\.1)
    }

    public var stepOutputChecklistRows: [CookModeChecklistRow] {
        guard let activeStep else {
            return []
        }

        let checkedIDs = Set(progress.checkedStepOutputUseIDs)
        return activeStep.usingSteps.map { outputUse in
            let sourceTitle = outputUse.outputOfStep.stepTitle.map { ": \($0)" } ?? ""
            return CookModeChecklistRow(
                id: outputUse.id,
                title: "Step \(outputUse.outputOfStep.stepNum)\(sourceTitle)",
                quantityText: "",
                isChecked: checkedIDs.contains(outputUse.id)
            )
        }
    }

    public var systemTimer: CookModeSystemTimerViewModel? {
        guard let activeStep,
              let duration = activeStep.duration,
              duration > 0 else {
            return nil
        }

        return CookModeSystemTimerViewModel(
            stepID: activeStep.id,
            durationMinutes: duration,
            durationSeconds: duration * 60
        )
    }

    public func progressAfterSelectingNext(updatedAt: String) -> CookModeProgress {
        guard let activeStep,
              let index = recipe.steps.firstIndex(where: { $0.id == activeStep.id }),
              index < recipe.steps.index(before: recipe.steps.endIndex) else {
            return progress
        }

        return (try? progress.selectingStep(id: recipe.steps[index + 1].id, updatedAt: updatedAt)) ?? progress
    }

    public func progressAfterSelectingPrevious(updatedAt: String) -> CookModeProgress {
        guard let activeStep,
              let index = recipe.steps.firstIndex(where: { $0.id == activeStep.id }),
              index > recipe.steps.startIndex else {
            return progress
        }

        return (try? progress.selectingStep(id: recipe.steps[index - 1].id, updatedAt: updatedAt)) ?? progress
    }

    public func progressAfterTogglingIngredient(
        id ingredientID: String,
        checked: Bool,
        updatedAt: String
    ) throws -> CookModeProgress {
        try progress.togglingIngredient(id: ingredientID, checked: checked, updatedAt: updatedAt)
    }

    public func progressAfterTogglingStepOutputUse(
        id stepOutputUseID: String,
        checked: Bool,
        updatedAt: String
    ) throws -> CookModeProgress {
        try progress.togglingStepOutputUse(id: stepOutputUseID, checked: checked, updatedAt: updatedAt)
    }

    private var recipeCheckableCount: Int {
        recipe.steps.reduce(0) { total, step in
            total + step.ingredients.count + step.usingSteps.count
        }
    }

    private var recipeCheckedCount: Int {
        let recipeIngredientIDs = Set(recipe.steps.flatMap { $0.ingredients.map(\.id) })
        let recipeOutputUseIDs = Set(recipe.steps.flatMap { $0.usingSteps.map(\.id) })
        return progress.checkedIngredientIDs.filter { recipeIngredientIDs.contains($0) }.count +
            progress.checkedStepOutputUseIDs.filter { recipeOutputUseIDs.contains($0) }.count
    }

    private func checkedLabel(checked: Int, total: Int) -> String {
        "\(checked) of \(total) checked"
    }
}

private enum CookModeQuantityFormatter {
    private static let fractionGlyphs: [Int: [Int: String]] = [
        2: [1: "½"],
        3: [1: "⅓", 2: "⅔"],
        4: [1: "¼", 2: "½", 3: "¾"],
        6: [1: "⅙", 2: "⅓", 3: "½", 4: "⅔", 5: "⅚"],
        8: [1: "⅛", 2: "¼", 3: "⅜", 4: "½", 5: "⅝", 6: "¾", 7: "⅞"]
    ]

    static func quantityText(quantity: Double, unit: String?) -> String {
        let quantityText = formattedQuantity(quantity)
        guard let unit, !unit.isEmpty else {
            return quantityText
        }

        return "\(quantityText) \(unit)"
    }

    private static func formattedQuantity(_ value: Double) -> String {
        guard value.isFinite else {
            return "1"
        }

        let sign = value < 0 ? "-" : ""
        let absoluteValue = abs(value)
        let whole = Int(absoluteValue.rounded(.down))
        let fraction = absoluteValue - Double(whole)

        if fraction < 0.005 {
            return "\(sign)\(whole)"
        }

        if let fractionText = formattedFraction(fraction) {
            if whole == 0 {
                return "\(sign)\(fractionText)"
            }
            return "\(sign)\(whole) \(fractionText)"
        }

        return trimmedDecimal(value)
    }

    private static func formattedFraction(_ value: Double) -> String? {
        let candidates = fractionGlyphs.flatMap { denominator, numerators in
            numerators.map { numerator, glyph in
                (distance: abs(value - (Double(numerator) / Double(denominator))), glyph: glyph)
            }
        }
        guard let best = candidates.min(by: { $0.distance < $1.distance }),
              best.distance <= 0.02 else {
            return nil
        }

        return best.glyph
    }

    private static func trimmedDecimal(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.last == "0" {
            text.removeLast()
        }
        return text
    }
}

public struct ShoppingListViewModel: Equatable {
    public let shoppingList: ShoppingListState

    public init(shoppingList: ShoppingListState) {
        self.shoppingList = shoppingList
    }

    public var sections: [ShoppingListReceiptSection] {
        shoppingList.receiptSections
    }

    public var checkControlItemIDs: [String] {
        shoppingList.activeItems.map(\.id)
    }

    public func togglingItem(id: String, checked: Bool, at checkedAt: String) throws -> ShoppingListViewModel {
        let nextSortIndex = (shoppingList.activeItems.map(\.sortIndex).max() ?? -1) + 1
        return ShoppingListViewModel(
            shoppingList: try shoppingList.settingChecked(
                checked,
                itemID: id,
                checkedAt: checkedAt,
                updatedAt: checkedAt,
                nextSortIndex: nextSortIndex
            )
        )
    }
}

public struct CaptureDraftViewModel: Equatable {
    public let draft: CaptureDraft

    public init(draft: CaptureDraft) {
        self.draft = draft
    }

    public var previewLines: [String] {
        draft.previewLines
    }

    public var status: CaptureDraftStatus {
        draft.status
    }

    public var canCreateServerRecipe: Bool {
        draft.canCreateServerRecipe
    }
}

public struct OfflineIndicatorDismissCommand: Equatable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct SettingsViewModel: Equatable {
    public let settings: SettingsState
    public let offlineIndicatorDisplay: OfflineIndicatorDisplay
    public let authSessionState: NativeAuthSessionState
    public let environmentSwitcher: NativeCacheEnvironment
    public let dismissOfflineIndicator: OfflineIndicatorDismissCommand

    public init(
        settings: SettingsState,
        offlineIndicatorDisplay: OfflineIndicatorDisplay = .synced,
        authSessionState: NativeAuthSessionState = .signedOut,
        environmentSwitcher: NativeCacheEnvironment = .production,
        dismissOfflineIndicator: OfflineIndicatorDismissCommand = OfflineIndicatorDismissCommand(
            id: "dismiss-offline-indicator",
            title: "Hide offline status"
        )
    ) {
        self.settings = settings
        self.offlineIndicatorDisplay = offlineIndicatorDisplay
        self.authSessionState = authSessionState
        self.environmentSwitcher = environmentSwitcher
        self.dismissOfflineIndicator = dismissOfflineIndicator
    }

    public var rows: [SettingsStatusRow] {
        settings.statusRows
    }

    public var canReadShoppingList: Bool {
        settings.canReadShoppingList
    }

    public var canWriteShoppingList: Bool {
        settings.canWriteShoppingList
    }
}
