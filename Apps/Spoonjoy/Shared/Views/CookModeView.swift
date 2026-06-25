import Foundation
import SpoonjoyCore
import SwiftUI

struct CookModeRouteView: View {
    let recipeID: String
    let repository: any RecipeCatalogRepository
    let initialRecipe: Recipe?
    let progress: (Recipe) -> CookModeProgress
    let progressDidChange: (CookModeProgress) -> Void
    let close: () -> Void

    @State private var recipe: Recipe?
    @State private var errorMessage: String?

    init(
        recipeID: String,
        repository: any RecipeCatalogRepository,
        initialRecipe: Recipe?,
        progress: @escaping (Recipe) -> CookModeProgress,
        progressDidChange: @escaping (CookModeProgress) -> Void = { _ in },
        close: @escaping () -> Void = {}
    ) {
        self.recipeID = recipeID
        self.repository = repository
        self.initialRecipe = initialRecipe
        self.progress = progress
        self.progressDidChange = progressDidChange
        self.close = close
        _recipe = State(initialValue: initialRecipe)
    }

    var body: some View {
        Group {
            if let recipe {
                CookModeView(
                    viewModel: CookModeViewModel(recipe: recipe, progress: progress(recipe)),
                    progressDidChange: progressDidChange,
                    close: close
                )
            } else if let errorMessage {
                Label(errorMessage, systemImage: "fork.knife")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
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
}

struct CookModeView: View {
    private let recipe: Recipe
    @State private var progress: CookModeProgress
    private let progressDidChange: (CookModeProgress) -> Void
    private let close: () -> Void

    init(
        viewModel: CookModeViewModel,
        progressDidChange: @escaping (CookModeProgress) -> Void = { _ in },
        close: @escaping () -> Void = {}
    ) {
        recipe = viewModel.recipe
        _progress = State(initialValue: viewModel.progress)
        self.progressDidChange = progressDidChange
        self.close = close
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if let currentStep {
                focusedStep(currentStep)
                ingredients(for: currentStep)
            }

            Spacer(minLength: 0)

            KitchenSafeControls(
                canAdvance: canAdvance,
                markComplete: markCurrentStepComplete,
                advance: advance,
                close: close
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.bone)
    }

    private var viewModel: CookModeViewModel {
        CookModeViewModel(recipe: recipe, progress: progress)
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

    private var progressText: String {
        viewModel.completionFraction.formatted(.percent.precision(.fractionLength(0)))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ProgressView(value: viewModel.completionFraction, total: 1)
                .tint(KitchenTableTheme.herb)
                .accessibilityLabel("persisted progress \(progressText)")

            Text(progressText)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
        }
    }

    private func focusedStep(_ step: RecipeStep) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(step.stepNum). \(step.stepTitle ?? "Step")")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(step.description)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current cooking step \(step.stepNum)")
    }

    private func ingredients(for step: RecipeStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(step.ingredients, id: \.id) { ingredient in
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    Text(quantityText(for: ingredient))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 4)
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
        updateProgress(progress.advancing())
    }

    private func updateProgress(_ nextProgress: CookModeProgress) {
        progress = nextProgress
        progressDidChange(nextProgress)
    }

    private func quantityText(for ingredient: RecipeIngredient) -> String {
        let quantity = ingredient.quantity.formatted(.number.precision(.fractionLength(0...2)))
        return [quantity, ingredient.unit].compactMap { $0 }.joined(separator: " ")
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
