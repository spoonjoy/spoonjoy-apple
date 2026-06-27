import Foundation

public enum RecipeActionConnectivity: Equatable, Sendable {
    case online
    case offline
}

public enum RecipeActionConfirmation: Equatable, Sendable {
    case required
    case confirmed
}

public struct RecipeActionConfirmationPrompt: Equatable, Sendable {
    public let title: String
    public let message: String
    public let confirmButtonTitle: String
    public let isDestructive: Bool

    public init(title: String, message: String, confirmButtonTitle: String, isDestructive: Bool) {
        self.title = title
        self.message = message
        self.confirmButtonTitle = confirmButtonTitle
        self.isDestructive = isDestructive
    }
}

public enum RecipeAction: Equatable, Sendable {
    case fork(clientMutationID: String, titleOverride: String)
    case saveToCookbook(cookbookID: String, clientMutationID: String)
    case removeFromCookbook(cookbookID: String, clientMutationID: String)
    case deleteRecipe(clientMutationID: String, confirmation: RecipeActionConfirmation)
}

public struct RecipeActionPlan: Equatable {
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let offlineFallbackMutation: NativeQueuedMutation?
    public let successRoute: AppRoute?
    public let blockedReason: String?
    public let confirmationPrompt: RecipeActionConfirmationPrompt?

    public init(
        remoteRequestBuilder: APIRequestBuilder? = nil,
        queuedMutation: NativeQueuedMutation? = nil,
        offlineFallbackMutation: NativeQueuedMutation? = nil,
        successRoute: AppRoute? = nil,
        blockedReason: String? = nil,
        confirmationPrompt: RecipeActionConfirmationPrompt? = nil
    ) {
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.offlineFallbackMutation = offlineFallbackMutation
        self.successRoute = successRoute
        self.blockedReason = blockedReason
        self.confirmationPrompt = confirmationPrompt
    }
}

public struct RecipeActionsViewModel {
    public let recipe: Recipe
    public let context: RecipeDetailContext
    public let connectivity: RecipeActionConnectivity

    private let now: @Sendable () -> String

    public init(
        recipe: Recipe,
        context: RecipeDetailContext,
        connectivity: RecipeActionConnectivity,
        now: @escaping @Sendable () -> String
    ) {
        self.recipe = recipe
        self.context = context
        self.connectivity = connectivity
        self.now = now
    }

    public func plan(_ action: RecipeAction) throws -> RecipeActionPlan {
        switch action {
        case .fork(let clientMutationID, let titleOverride):
            return try mutationPlan(
                online: RecipeWriteRequests.forkRecipe(
                    id: recipe.id,
                    clientMutationID: clientMutationID,
                    titleOverride: titleOverride
                ),
                offline: NativeQueuedMutation.recipeFork(
                    recipeID: recipe.id,
                    clientMutationID: clientMutationID,
                    titleOverride: titleOverride,
                    createdAt: now()
                ),
                successRoute: .recipes
            )
        case .saveToCookbook(let cookbookID, let clientMutationID):
            guard cookbookOption(cookbookID) != nil else {
                return blocked("Choose one of your cookbooks before saving this recipe.")
            }
            guard !context.savedInCookbookIDs.contains(cookbookID) else {
                return blocked("This recipe is already saved in that cookbook.")
            }
            return try mutationPlan(
                online: CookbookWriteRequests.addRecipe(
                    cookbookID: cookbookID,
                    recipeID: recipe.id,
                    clientMutationID: clientMutationID
                ),
                offline: NativeQueuedMutation.cookbookAddRecipe(
                    cookbookID: cookbookID,
                    recipeID: recipe.id,
                    clientMutationID: clientMutationID,
                    createdAt: now()
                ),
                successRoute: recipeRoute
            )
        case .removeFromCookbook(let cookbookID, let clientMutationID):
            guard cookbookOption(cookbookID) != nil else {
                return blocked("Choose one of your cookbooks before removing this recipe.")
            }
            guard context.savedInCookbookIDs.contains(cookbookID) else {
                return blocked("This recipe is not saved in that cookbook.")
            }
            return try mutationPlan(
                online: CookbookWriteRequests.removeRecipe(
                    cookbookID: cookbookID,
                    recipeID: recipe.id,
                    clientMutationID: clientMutationID,
                    idempotency: .body
                ),
                offline: NativeQueuedMutation.cookbookRemoveRecipe(
                    cookbookID: cookbookID,
                    recipeID: recipe.id,
                    clientMutationID: clientMutationID,
                    createdAt: now()
                ),
                successRoute: recipeRoute
            )
        case .deleteRecipe(let clientMutationID, let confirmation):
            guard isOwner else {
                return blocked("Only \(recipe.chef.username) can delete this recipe.")
            }
            guard confirmation == .confirmed else {
                return RecipeActionPlan(confirmationPrompt: deleteConfirmationPrompt)
            }
            return try mutationPlan(
                online: RecipeWriteRequests.deleteRecipe(id: recipe.id, clientMutationID: clientMutationID, idempotency: .query),
                offline: NativeQueuedMutation.recipeDelete(recipeID: recipe.id, clientMutationID: clientMutationID, createdAt: now()),
                successRoute: .recipes
            )
        }
    }

    public var deleteConfirmationPrompt: RecipeActionConfirmationPrompt {
        RecipeActionConfirmationPrompt(
            title: "Delete \(recipe.title)?",
            message: "This removes the recipe from your kitchen and syncs the deletion across your devices.",
            confirmButtonTitle: "Delete Recipe",
            isDestructive: true
        )
    }

    private var isOwner: Bool {
        context.currentChefID == recipe.chef.id
    }

    private var recipeRoute: AppRoute {
        .recipeDetail(id: recipe.id, presentation: .detail)
    }

    private func cookbookOption(_ cookbookID: String) -> RecipeCookbookSaveOption? {
        context.availableCookbooks.first { $0.id == cookbookID }
    }

    private func mutationPlan(
        online: APIRequestBuilder,
        offline: NativeQueuedMutation,
        successRoute: AppRoute?
    ) -> RecipeActionPlan {
        switch connectivity {
        case .online:
            RecipeActionPlan(
                remoteRequestBuilder: online,
                offlineFallbackMutation: offline,
                successRoute: successRoute
            )
        case .offline:
            RecipeActionPlan(
                queuedMutation: offline,
                successRoute: successRoute
            )
        }
    }

    private func blocked(_ reason: String) -> RecipeActionPlan {
        RecipeActionPlan(blockedReason: reason)
    }
}
