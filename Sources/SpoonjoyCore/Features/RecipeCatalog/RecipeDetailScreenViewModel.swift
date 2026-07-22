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
    case steps
    case recentSpoons
    case cookLogging
    case cookbookSave
    case shoppingList
    case ownerTools
    case share
    case startCooking
}

public struct RecipeDetailCoverViewModel: Equatable, Sendable {
    public let imageURL: URL?
    public let provenanceLabel: String?
    public let hasRealCover: Bool
    public let noPhotoLabel: String
    public let accessibilityLabel: String

    public init(imageURL: URL?, provenanceLabel: String?, title: String) {
        self.imageURL = imageURL
        self.provenanceLabel = provenanceLabel
        hasRealCover = imageURL != nil
        noPhotoLabel = "Photo not added"
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if imageURL != nil {
            accessibilityLabel = trimmedTitle.isEmpty ? "Recipe cover image" : "\(trimmedTitle) cover image"
        } else {
            accessibilityLabel = trimmedTitle.isEmpty ? noPhotoLabel : "\(trimmedTitle): \(noPhotoLabel)"
        }
    }
}

public struct RecipeDetailSourceAttribution: Equatable, Sendable {
    public let title: String
    public let host: String?
    public let canonicalURL: URL?
}

public struct RecipeDetailIngredientRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let quantity: Double
    public let unit: String?

    public init(ingredient: RecipeIngredient) {
        id = ingredient.id
        name = ingredient.name
        quantity = ingredient.quantity
        unit = ingredient.unit
    }

    public func quantityText(scaleFactor: Double = 1) -> String {
        let scaledQuantity = (quantity * scaleFactor).formatted(.number.precision(.fractionLength(0...2)))
        return [scaledQuantity, unit].compactMap { $0 }.joined(separator: " ")
    }
}

public struct RecipeDetailStepSection: Identifiable, Equatable, Sendable {
    public let id: String
    public let stepNumber: Int
    public let title: String?
    public let body: String
    public let durationMinutes: Int?
    public let dependencies: [RecipeDetailStepDependency]
    public let ingredients: [RecipeDetailIngredientRow]

    public var durationLabel: String? {
        guard let durationMinutes, durationMinutes > 0 else {
            return nil
        }
        return "\(durationMinutes) min"
    }

    public init(step: RecipeStep) {
        id = step.id
        stepNumber = step.stepNum
        title = step.stepTitle
        body = step.description
        durationMinutes = step.duration
        dependencies = step.usingSteps.map(RecipeDetailStepDependency.init(use:))
        ingredients = step.ingredients.map(RecipeDetailIngredientRow.init(ingredient:))
    }
}

public struct RecipeDetailStepDependency: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let outputStepNum: Int

    public init(use: RecipeStepOutputUse) {
        id = use.id
        outputStepNum = use.outputStepNum
        if let title = use.outputOfStep.stepTitle {
            label = "Step \(use.outputStepNum): \(title)"
        } else {
            label = "Step \(use.outputStepNum)"
        }
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
    case logCook
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
    public let stepSections: [RecipeDetailStepSection]
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
            imageURL: recipe.displayCoverImageURL,
            provenanceLabel: recipe.displayCoverProvenanceLabel,
            title: recipe.title
        )
        sourceAttribution = recipe.attribution.sourceRecipe.map { sourceRecipe in
            RecipeDetailSourceAttribution(
                title: sourceRecipe.title ?? "Original recipe",
                host: recipe.attribution.sourceHost,
                canonicalURL: sourceRecipe.safeCanonicalURL
            )
        }
        stepSections = recipe.steps.map(RecipeDetailStepSection.init(step:))
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
            .steps,
            .recentSpoons,
            .cookLogging,
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
            .logCook,
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

public struct NativeRecipeDetailTelemetryDescriptor: Equatable, Sendable {
    public let stage: String
    public let errorType: String
    public let requestID: String?
    public let status: Int?
    public let apiCode: String?
    public let retry: String?

    public static func cookHistoryEnrichmentFailed(error: Error) -> Self {
        let transportError = error as? APITransportError
        return Self(
            stage: "recipe_detail.cook_history_enrichment",
            errorType: bounded(String(describing: Swift.type(of: error)), limit: 80),
            requestID: bounded(transportError?.requestID ?? transportError?.apiError?.requestID, limit: 160),
            status: transportError?.statusCode ?? transportError?.apiError?.status,
            apiCode: bounded(transportError?.apiError?.code, limit: 80),
            retry: transportError.map { retryDescription($0.retryDecision) }
        )
    }

    public func telemetryEvent(
        environment: String,
        metadata: NativeTelemetryAppMetadata
    ) -> NativeTelemetryEvent {
        NativeTelemetryEvent(
            name: .syncFailed,
            stage: stage,
            environment: environment,
            metadata: metadata,
            route: "recipe_detail",
            errorType: errorType,
            requestID: requestID,
            status: status,
            apiCode: apiCode,
            retry: retry,
            hasRenderableCacheContent: true
        )
    }

    private static func bounded(_ value: String?, limit: Int) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return String(value.prefix(limit))
    }

    private static func bounded(_ value: String, limit: Int) -> String {
        String(value.prefix(limit))
    }

    private static func retryDescription(_ decision: APIRetryDecision) -> String {
        switch decision {
        case .retrySameRequest(let seconds):
            "retry_same_request:\(seconds.map(String.init) ?? "unspecified")"
        case .refreshAuthentication:
            "refresh_authentication"
        case .doNotRetry:
            "do_not_retry"
        }
    }
}

public typealias NativeRecipeDetailTelemetryReportOperation = @Sendable (
    NativeRecipeDetailTelemetryDescriptor
) async -> Void

public struct RecipeDetailProgressiveLoader: Sendable {
    private let recipeRepository: any RecipeCatalogRepository
    private let spoonRepository: any SpoonCookLogRepository
    private let reportTelemetry: NativeRecipeDetailTelemetryReportOperation

    public init(
        recipeRepository: any RecipeCatalogRepository,
        spoonRepository: any SpoonCookLogRepository,
        reportTelemetry: @escaping NativeRecipeDetailTelemetryReportOperation = { _ in }
    ) {
        self.recipeRepository = recipeRepository
        self.spoonRepository = spoonRepository
        self.reportTelemetry = reportTelemetry
    }

    public func load(
        recipeID: String,
        onRecipe: @escaping @MainActor @Sendable (RecipeCatalogDetailResult) -> Void
    ) async throws {
        let initialResult = try await recipeRepository.recipeDetail(id: recipeID)
        await onRecipe(initialResult)

        do {
            let cookLog = try await fullCookLog(recipeID: initialResult.recipe.id)
            try Task.checkCancellation()
            let enrichedResult = RecipeCatalogDetailResult(
                recipe: initialResult.recipe.replacingRecentSpoons(cookLog.spoons),
                source: initialResult.source
            )
            await onRecipe(enrichedResult)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as APITransportError where error.isCancelled {
            throw CancellationError()
        } catch {
            await reportTelemetry(.cookHistoryEnrichmentFailed(error: error))
        }
    }

    private func fullCookLog(recipeID: String) async throws -> SpoonCookLogData {
        var seenCursors = Set<String>()
        var spoons: [RecipeDetailRecentSpoon] = []
        try Task.checkCancellation()
        var page = try await spoonRepository.fetchCookLog(recipeID: recipeID, cursor: nil, limit: 50)
        spoons.append(contentsOf: page.spoons)

        while page.hasMore {
            guard let nextCursor = page.nextCursor else {
                throw RecipeDetailProgressiveLoadError.missingNextCursor
            }
            guard seenCursors.insert(nextCursor.rawValue).inserted else {
                throw RecipeDetailProgressiveLoadError.repeatedCursor
            }
            try Task.checkCancellation()
            page = try await spoonRepository.fetchCookLog(recipeID: recipeID, cursor: nextCursor, limit: 50)
            spoons.append(contentsOf: page.spoons)
        }
        return SpoonCookLogData(spoons: spoons, nextCursor: page.nextCursor, hasMore: false)
    }
}

private enum RecipeDetailProgressiveLoadError: Error {
    case missingNextCursor
    case repeatedCursor
}

private extension Recipe {
    func replacingRecentSpoons(_ recentSpoons: [RecipeDetailRecentSpoon]) -> Recipe {
        Recipe(
            id: id,
            title: title,
            description: description,
            servings: servings,
            chef: chef,
            coverImageURL: coverImageURL,
            coverProvenanceLabel: coverProvenanceLabel,
            coverSourceType: coverSourceType,
            coverVariant: coverVariant,
            href: href,
            canonicalURL: canonicalURL,
            attribution: attribution,
            createdAt: createdAt,
            updatedAt: updatedAt,
            steps: steps,
            cookbooks: cookbooks,
            recentSpoons: recentSpoons
        )
    }
}
