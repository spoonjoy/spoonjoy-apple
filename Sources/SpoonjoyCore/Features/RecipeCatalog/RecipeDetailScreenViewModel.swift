import Foundation

public struct RecipeCookbookSaveOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct RecipeDetailContext: Equatable, Sendable {
    public let currentChefID: String?
    public let availableCookbooks: [RecipeCookbookSaveOption]
    public let savedInCookbookIDs: Set<String>
    public let hasIngredientsInShoppingList: Bool
    public let now: Date

    public init(
        currentChefID: String?,
        availableCookbooks: [RecipeCookbookSaveOption],
        savedInCookbookIDs: Set<String>,
        hasIngredientsInShoppingList: Bool,
        now: Date
    ) {
        self.currentChefID = currentChefID
        self.availableCookbooks = availableCookbooks
        self.savedInCookbookIDs = savedInCookbookIDs
        self.hasIngredientsInShoppingList = hasIngredientsInShoppingList
        self.now = now
    }
}

public enum RecipeDetailReadSurface: Equatable, Hashable, Sendable {
    case identity
    case cover
    case chefAttribution
    case sourceAttribution
    case ingredientReceipt
    case method
    case recentSpoons
    case cookbookSave
    case shoppingList
    case ownerTools
    case share
    case startCooking
}

public struct RecipeDetailCoverViewModel: Equatable, Sendable {
    public let imageURL: URL?
    public let provenanceLabel: String?
}

public struct RecipeDetailSourceAttribution: Equatable, Sendable {
    public let title: String
    public let host: String?
    public let canonicalURL: URL?
}

public struct RecipeDetailIngredientReceipt: Equatable, Sendable {
    public let rows: [RecipeDetailIngredientRow]
}

public struct RecipeDetailIngredientRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let quantityText: String

    public init(ingredient: RecipeIngredient) {
        id = ingredient.id
        name = ingredient.name
        quantityText = Self.quantityText(for: ingredient)
    }

    private static func quantityText(for ingredient: RecipeIngredient) -> String {
        let quantity = ingredient.quantity.formatted(.number.precision(.fractionLength(0...2)))
        return [quantity, ingredient.unit].compactMap { $0 }.joined(separator: " ")
    }
}

public struct RecipeDetailMethodSection: Identifiable, Equatable, Sendable {
    public let id: String
    public let stepNumber: Int
    public let title: String
    public let body: String
    public let dependencies: [RecipeDetailMethodDependency]
    public let ingredients: [RecipeDetailIngredientRow]

    public init(step: RecipeStep) {
        id = step.id
        stepNumber = step.stepNum
        title = step.stepTitle ?? "Step"
        body = step.description
        dependencies = step.usingSteps.map(RecipeDetailMethodDependency.init(use:))
        ingredients = step.ingredients.map(RecipeDetailIngredientRow.init(ingredient:))
    }
}

public struct RecipeDetailMethodDependency: Equatable, Sendable {
    public let label: String
    public let outputStepNum: Int

    public init(use: RecipeStepOutputUse) {
        outputStepNum = use.outputStepNum
        label = "Uses \(use.outputOfStep.stepTitle ?? "step \(use.outputStepNum)")"
    }
}

public struct RecipeDetailSpoonSummary: Equatable, Sendable {
    public let rows: [RecipeDetailSpoonRow]
}

public struct RecipeDetailSpoonRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let spoon: RecipeDetailRecentSpoon
    public let chefLine: String
    public let note: String?
    public let nextTime: String?
    public let photoURL: URL?

    public init(spoon: RecipeDetailRecentSpoon) {
        id = spoon.id
        self.spoon = spoon
        chefLine = "\(spoon.chef.username) cooked this"
        note = spoon.note
        nextTime = spoon.nextTime
        photoURL = spoon.photoURL
    }
}

public struct RecipeDetailCookbookSaveState: Equatable, Sendable {
    public let availableCookbooks: [RecipeCookbookSaveOption]
    public let savedCookbookIDs: Set<String>

    public init(availableCookbooks: [RecipeCookbookSaveOption], savedCookbookIDs: Set<String>) {
        self.availableCookbooks = availableCookbooks
        self.savedCookbookIDs = savedCookbookIDs
    }

    public func isSaved(in cookbookID: String) -> Bool {
        savedCookbookIDs.contains(cookbookID)
    }
}

public enum RecipeDetailActionID: String, Equatable, Sendable {
    case startCooking
    case saveToCookbook
    case addToShoppingList
    case share
    case fork
    case makeVariation
    case edit
    case manageCovers
    case deleteRecipe
}

public struct RecipeShoppingListActionMetadata: Equatable, Sendable {
    public let recipeID: String
    public let hasIngredientsInShoppingList: Bool

    public init(recipeID: String, hasIngredientsInShoppingList: Bool) {
        self.recipeID = recipeID
        self.hasIngredientsInShoppingList = hasIngredientsInShoppingList
    }
}

public struct RecipeForkActionMetadata: Equatable, Sendable {
    public let label: String
    public let titleOverride: String

    public init(label: String, titleOverride: String) {
        self.label = label
        self.titleOverride = titleOverride
    }
}

public struct RecipeDetailOwnerTools: Equatable, Sendable {
    public let isVisible: Bool
    public let editPath: String
    public let editRoute: AppRoute?
    public let coverControlsRoute: AppRoute?
    public let deleteConfirmation: RecipeActionConfirmationPrompt?
}

public struct RecipeDetailActions: Equatable, Sendable {
    public let availableActionIDs: [RecipeDetailActionID]
    public let startCookingRoute: AppRoute
    public let sharePayload: NativeSharePayload?
    public let chefProfilePath: String
    public let cookbookOptions: [RecipeCookbookSaveOption]
    public let savedCookbookIDs: Set<String>
    public let shoppingListMetadata: RecipeShoppingListActionMetadata
    public let fork: RecipeForkActionMetadata
}

public struct RecipeDetailScreenViewModel: Equatable, Sendable {
    public let recipe: Recipe
    public let id: String
    public let title: String
    public let description: String?
    public let chefAttribution: String
    public let servingsLabel: String?
    public let cover: RecipeDetailCoverViewModel
    public let sourceAttribution: RecipeDetailSourceAttribution?
    public let ingredientReceipt: RecipeDetailIngredientReceipt
    public let methodSections: [RecipeDetailMethodSection]
    public let spoonSummary: RecipeDetailSpoonSummary
    public let cookbookSave: RecipeDetailCookbookSaveState
    public let hasIngredientsInShoppingList: Bool
    public let actionContext: RecipeDetailContext
    public let ownerTools: RecipeDetailOwnerTools
    public let actions: RecipeDetailActions
    public let offlineIndicator: OfflineIndicatorState
    public let supportedReadSurfaces: [RecipeDetailReadSurface]

    public init(
        result: RecipeCatalogDetailResult,
        context: RecipeDetailContext,
        freshnessPolicy: NativeCacheFreshnessPolicy = .offlineProductContract
    ) {
        let recipe = result.recipe
        self.recipe = recipe
        id = recipe.id
        title = recipe.title
        description = recipe.description
        chefAttribution = "By \(recipe.chef.username)"
        servingsLabel = Self.servingsLabel(recipe.servings)
        cover = RecipeDetailCoverViewModel(
            imageURL: recipe.coverImageURL,
            provenanceLabel: recipe.coverProvenanceLabel
        )
        sourceAttribution = recipe.attribution.sourceRecipe.map { sourceRecipe in
            RecipeDetailSourceAttribution(
                title: sourceRecipe.title ?? "Original recipe",
                host: recipe.attribution.sourceHost,
                canonicalURL: sourceRecipe.safeCanonicalURL
            )
        }
        ingredientReceipt = RecipeDetailIngredientReceipt(
            rows: recipe.steps.flatMap(\.ingredients).map(RecipeDetailIngredientRow.init(ingredient:))
        )
        methodSections = recipe.steps.map(RecipeDetailMethodSection.init(step:))
        spoonSummary = RecipeDetailSpoonSummary(
            rows: recipe.recentSpoons
                .filter { $0.deletedAt == nil }
                .map(RecipeDetailSpoonRow.init(spoon:))
        )
        cookbookSave = RecipeDetailCookbookSaveState(
            availableCookbooks: context.availableCookbooks,
            savedCookbookIDs: context.savedInCookbookIDs
        )
        hasIngredientsInShoppingList = context.hasIngredientsInShoppingList
        actionContext = context
        let isOwner = context.currentChefID == recipe.chef.id
        let sharePayload = try? NativeSharePayload.publicRecipe(recipe)
        let deleteConfirmation = RecipeActionConfirmationPrompt(
            title: "Delete \(recipe.title)?",
            message: "This removes the recipe from your kitchen and syncs the deletion across your devices.",
            confirmButtonTitle: "Delete Recipe",
            isDestructive: true
        )
        ownerTools = RecipeDetailOwnerTools(
            isVisible: isOwner,
            editPath: "/recipes/\(recipe.id)/edit",
            editRoute: isOwner ? .recipeEditor(id: recipe.id) : nil,
            coverControlsRoute: isOwner ? .recipeCoverControls(id: recipe.id) : nil,
            deleteConfirmation: isOwner ? deleteConfirmation : nil
        )
        actions = RecipeDetailActions(
            availableActionIDs: Self.actionIDs(isOwner: isOwner, canShare: sharePayload != nil),
            startCookingRoute: .recipeDetail(id: recipe.id, presentation: .cook),
            sharePayload: sharePayload,
            chefProfilePath: "/users/\(recipe.chef.username)",
            cookbookOptions: context.availableCookbooks,
            savedCookbookIDs: context.savedInCookbookIDs,
            shoppingListMetadata: RecipeShoppingListActionMetadata(
                recipeID: recipe.id,
                hasIngredientsInShoppingList: context.hasIngredientsInShoppingList
            ),
            fork: RecipeForkActionMetadata(
                label: isOwner ? "Make a variation" : "Fork",
                titleOverride: isOwner ? "\(recipe.title), my version" : recipe.title
            )
        )
        offlineIndicator = result.offlineIndicator(now: context.now, freshnessPolicy: freshnessPolicy)
        supportedReadSurfaces = [
            .identity,
            .cover,
            .chefAttribution,
            .sourceAttribution,
            .ingredientReceipt,
            .method,
            .recentSpoons,
            .cookbookSave,
            .shoppingList,
            .ownerTools,
            .share,
            .startCooking
        ]
    }

    public init(recipe: Recipe) {
        self.init(
            result: RecipeCatalogDetailResult(
                recipe: recipe,
                source: .cache(serverRevision: .updatedAt(recipe.updatedAt), lastValidatedAt: .distantPast)
            ),
            context: RecipeDetailContext(
                currentChefID: nil,
                availableCookbooks: recipe.cookbooks.map { RecipeCookbookSaveOption(id: $0.id, title: $0.title) },
                savedInCookbookIDs: Set(recipe.cookbooks.map(\.id)),
                hasIngredientsInShoppingList: false,
                now: Date()
            )
        )
    }

    private static func servingsLabel(_ servings: String?) -> String? {
        guard let servings = servings?.trimmingCharacters(in: .whitespacesAndNewlines), !servings.isEmpty else {
            return nil
        }

        return "Serves \(servings)"
    }

    private static func actionIDs(isOwner: Bool, canShare: Bool) -> [RecipeDetailActionID] {
        var actions: [RecipeDetailActionID] = [
            .startCooking,
            .saveToCookbook,
            .addToShoppingList
        ]
        if canShare {
            actions.append(.share)
        }

        if isOwner {
            actions.append(contentsOf: [
                .makeVariation,
                .edit,
                .manageCovers,
                .deleteRecipe
            ])
            return actions
        }

        actions.append(.fork)
        return actions
    }
}
