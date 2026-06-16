import Foundation

public struct RecipeMethodSection: Equatable {
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

    public var methodSections: [RecipeMethodSection] {
        recipe.steps.enumerated().map { index, step in
            RecipeMethodSection(stepNumber: index + 1, step: step)
        }
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

public struct SettingsViewModel: Equatable {
    public let settings: SettingsState

    public init(settings: SettingsState) {
        self.settings = settings
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
