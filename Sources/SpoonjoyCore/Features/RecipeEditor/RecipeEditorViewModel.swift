import Foundation

public enum RecipeEditorConnectivity: Equatable, Sendable {
    case online
    case offline
}

public enum RecipeEditorMode: Equatable, Sendable {
    case create(currentChefID: String, draft: RecipeEditorDraft)
    case edit(recipe: Recipe, currentChefID: String)
}

public enum RecipeEditorConfirmation: Equatable, Sendable {
    case confirmed
    case notConfirmed
}

public enum RecipeEditorAction: Equatable, Sendable {
    case save(clientMutationID: String)
    case createStep(clientMutationID: String, step: RecipeEditorStepDraft)
    case updateStep(stepID: String, clientMutationID: String, title: String?, description: String, duration: Int?, outputStepNums: [Int])
    case deleteStep(stepID: String, clientMutationID: String, confirmation: RecipeEditorConfirmation)
    case reorderStep(stepID: String, toStepNum: Int, clientMutationID: String)
    case addIngredient(stepID: String, clientMutationID: String, ingredient: RecipeEditorIngredientDraft)
    case deleteIngredient(stepID: String, ingredientID: String, clientMutationID: String, confirmation: RecipeEditorConfirmation)
    case replaceOutputUses(inputStepID: String, outputStepNums: [Int], clientMutationID: String)
    case deleteRecipe(clientMutationID: String, confirmation: RecipeEditorConfirmation)
}

public struct RecipeEditorTool: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
}

public enum RecipeEditorConflictAction: Equatable, Sendable {
    case reviewServerVersion
    case keepLocalDraft
}

public struct RecipeEditorConflict: Equatable, Sendable {
    public let resourceID: String
    public let serverRevision: NativeServerRevision
    public let localClientMutationID: String
    public let message: String

    public init(resourceID: String, serverRevision: NativeServerRevision, localClientMutationID: String, message: String) {
        self.resourceID = resourceID
        self.serverRevision = serverRevision
        self.localClientMutationID = localClientMutationID
        self.message = message
    }
}

public struct RecipeEditorConflictBanner: Equatable, Sendable {
    public let title: String
    public let message: String
    public let primaryAction: RecipeEditorConflictAction
    public let secondaryAction: RecipeEditorConflictAction
}

public struct RecipeEditorMutationPlan: Equatable {
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let successRoute: AppRoute?
    public let blockedReason: String?

    public init(
        remoteRequestBuilder: APIRequestBuilder? = nil,
        queuedMutation: NativeQueuedMutation? = nil,
        successRoute: AppRoute? = nil,
        blockedReason: String? = nil
    ) {
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.successRoute = successRoute
        self.blockedReason = blockedReason
    }
}

public struct RecipeEditorViewModel {
    public private(set) var draft: RecipeEditorDraft
    public let mode: RecipeEditorMode
    public let connectivity: RecipeEditorConnectivity
    public let conflict: RecipeEditorConflict?
    public let queuedRecipeMutations: [NativeQueuedMutation]
    private let now: () -> String
    private let ownerChefID: String?
    private let ownerUsername: String?

    public init(
        mode: RecipeEditorMode,
        connectivity: RecipeEditorConnectivity,
        conflict: RecipeEditorConflict? = nil,
        queuedRecipeMutations: [NativeQueuedMutation] = [],
        now: @escaping () -> String
    ) {
        self.mode = mode
        self.connectivity = connectivity
        self.conflict = conflict
        self.queuedRecipeMutations = queuedRecipeMutations
        self.now = now

        switch mode {
        case .create(let currentChefID, let draft):
            self.draft = draft
            ownerChefID = currentChefID
            ownerUsername = nil
        case .edit(let recipe, let currentChefID):
            self.draft = RecipeEditorDraft(recipe: recipe, currentChefID: currentChefID)
            ownerChefID = recipe.chef.id
            ownerUsername = recipe.chef.username
        }
    }

    public var route: AppRoute {
        .recipeEditor(id: draft.recipeID)
    }

    public var isOwner: Bool {
        ownerChefID == draft.currentChefID
    }

    public var canSubmit: Bool {
        isOwner && conflict == nil && RecipeEditorValidator.validate(draft).isEmpty
    }

    public var ownerTools: [RecipeEditorTool] {
        guard isOwner else {
            return []
        }

        switch draft.recipeID {
        case nil:
            return [RecipeEditorTool(id: "save", title: "Save")]
        case .some:
            return [
                RecipeEditorTool(id: "save", title: "Save"),
                RecipeEditorTool(id: "delete", title: "Delete")
            ]
        }
    }

    public var deleteConfirmationTitle: String {
        "Delete \(draft.titleForRequest)?"
    }

    public var blockingMessage: String? {
        guard !isOwner else {
            return nil
        }

        return "Only \(ownerUsername ?? "the recipe owner") can edit this recipe."
    }

    public var conflictBanner: RecipeEditorConflictBanner? {
        guard let conflict else {
            return nil
        }

        return RecipeEditorConflictBanner(
            title: "Recipe changed elsewhere",
            message: conflict.message,
            primaryAction: .reviewServerVersion,
            secondaryAction: .keepLocalDraft
        )
    }

    public var offlineIndicator: OfflineIndicatorState {
        let queued = queuedRecipeMutations.filter { mutation in
            switch mutation.queueableKind {
            case .recipeCreate, .recipeUpdate, .recipeDelete, .recipeStepCreate, .recipeStepUpdate, .recipeStepDelete, .recipeStepReorder, .recipeIngredientAdd, .recipeIngredientDelete, .recipeOutputUsesReplace:
                true
            default:
                false
            }
        }

        if !queued.isEmpty {
            return OfflineIndicatorState(
                display: .queuedWork(count: queued.count, oldestClientMutationID: queued.first?.clientMutationID),
                dismissal: nil
            )
        }

        return OfflineIndicatorState(display: .synced, dismissal: nil)
    }

    public func updatingDraft(_ draft: RecipeEditorDraft) -> RecipeEditorViewModel {
        var copy = self
        copy.draft = draft
        return copy
    }

    public func plan(_ action: RecipeEditorAction) throws -> RecipeEditorMutationPlan {
        if let blockingMessage {
            return blocked(blockingMessage)
        }

        if conflict != nil {
            return blocked("Resolve the recipe conflict before saving.")
        }

        switch action {
        case .save(let clientMutationID):
            return try savePlan(clientMutationID: clientMutationID)
        case .createStep(let clientMutationID, let step):
            return try createStepPlan(clientMutationID: clientMutationID, step: step)
        case .updateStep(let stepID, let clientMutationID, let title, let description, let duration, let outputStepNums):
            return try updateStepPlan(stepID: stepID, clientMutationID: clientMutationID, title: title, description: description, duration: duration, outputStepNums: outputStepNums)
        case .deleteStep(let stepID, let clientMutationID, let confirmation):
            guard confirmation == .confirmed else {
                return blocked("Confirm before deleting this step.")
            }
            return try deleteStepPlan(stepID: stepID, clientMutationID: clientMutationID)
        case .reorderStep(let stepID, let toStepNum, let clientMutationID):
            return try reorderStepPlan(stepID: stepID, toStepNum: toStepNum, clientMutationID: clientMutationID)
        case .addIngredient(let stepID, let clientMutationID, let ingredient):
            return try addIngredientPlan(stepID: stepID, clientMutationID: clientMutationID, ingredient: ingredient)
        case .deleteIngredient(let stepID, let ingredientID, let clientMutationID, let confirmation):
            guard confirmation == .confirmed else {
                return blocked("Confirm before deleting this ingredient.")
            }
            return try deleteIngredientPlan(stepID: stepID, ingredientID: ingredientID, clientMutationID: clientMutationID)
        case .replaceOutputUses(let inputStepID, let outputStepNums, let clientMutationID):
            return try replaceOutputUsesPlan(inputStepID: inputStepID, outputStepNums: outputStepNums, clientMutationID: clientMutationID)
        case .deleteRecipe(let clientMutationID, let confirmation):
            guard confirmation == .confirmed else {
                return blocked("Confirm before deleting this recipe.")
            }
            return try deleteRecipePlan(clientMutationID: clientMutationID)
        }
    }

    private func savePlan(clientMutationID: String) throws -> RecipeEditorMutationPlan {
        if let issue = RecipeEditorValidator.validate(draft).first {
            return blocked(issue.message)
        }

        if let recipeID = draft.recipeID {
            return plan(
                online: try RecipeWriteRequests.updateRecipe(
                    id: recipeID,
                    clientMutationID: clientMutationID,
                    title: draft.titleForRequest,
                    description: draft.descriptionForRequest,
                    servings: draft.servingsForRequest
                ),
                offline: NativeQueuedMutation.recipeUpdate(
                    recipeID: recipeID,
                    clientMutationID: clientMutationID,
                    title: draft.titleForRequest,
                    description: draft.descriptionForRequest,
                    servings: draft.servingsForRequest,
                    createdAt: now()
                ),
                successRoute: recipeRoute(recipeID)
            )
        }

        return plan(
            online: try RecipeWriteRequests.createRecipe(
                clientMutationID: clientMutationID,
                title: draft.titleForRequest,
                description: draft.descriptionForRequest,
                servings: draft.servingsForRequest,
                steps: draft.apiStepDrafts
            ),
            offline: try NativeQueuedMutation.recipeCreate(
                clientMutationID: clientMutationID,
                title: draft.titleForRequest,
                description: draft.descriptionForRequest,
                servings: draft.servingsForRequest,
                steps: draft.apiStepDrafts,
                createdAt: now()
            ),
            successRoute: .recipes
        )
    }

    private func deleteRecipePlan(clientMutationID: String) throws -> RecipeEditorMutationPlan {
        let recipeID = try existingRecipeID()
        return plan(
            online: try RecipeWriteRequests.deleteRecipe(id: recipeID, clientMutationID: clientMutationID, idempotency: .query),
            offline: NativeQueuedMutation.recipeDelete(recipeID: recipeID, clientMutationID: clientMutationID, createdAt: now()),
            successRoute: .recipes
        )
    }

    private func createStepPlan(clientMutationID: String, step: RecipeEditorStepDraft) throws -> RecipeEditorMutationPlan {
        let recipeID = try existingRecipeID()
        return plan(
            online: try RecipeStepRequests.createStep(
                recipeID: recipeID,
                clientMutationID: clientMutationID,
                stepNum: step.stepNum,
                stepTitle: trimmedOptional(step.title),
                description: step.description.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: step.duration,
                ingredients: step.ingredients.map(\.apiDraft),
                outputStepNums: step.outputStepNums
            ),
            offline: try NativeQueuedMutation.recipeStepCreate(
                recipeID: recipeID,
                clientMutationID: clientMutationID,
                stepNum: step.stepNum,
                stepTitle: trimmedOptional(step.title),
                description: step.description.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: step.duration,
                ingredients: step.ingredients.map(\.apiDraft),
                outputStepNums: step.outputStepNums,
                createdAt: now()
            ),
            successRoute: recipeRoute(recipeID)
        )
    }

    private func updateStepPlan(stepID: String, clientMutationID: String, title: String?, description: String, duration: Int?, outputStepNums: [Int]) throws -> RecipeEditorMutationPlan {
        let recipeID = try existingRecipeID()
        return plan(
            online: try RecipeStepRequests.updateStep(
                recipeID: recipeID,
                stepID: stepID,
                clientMutationID: clientMutationID,
                stepTitle: trimmedOptional(title),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: duration,
                outputStepNums: outputStepNums
            ),
            offline: NativeQueuedMutation.recipeStepUpdate(
                recipeID: recipeID,
                stepID: stepID,
                clientMutationID: clientMutationID,
                stepTitle: trimmedOptional(title),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: duration,
                outputStepNums: outputStepNums,
                createdAt: now()
            ),
            successRoute: recipeRoute(recipeID)
        )
    }

    private func deleteStepPlan(stepID: String, clientMutationID: String) throws -> RecipeEditorMutationPlan {
        let recipeID = try existingRecipeID()
        return plan(
            online: try RecipeStepRequests.deleteStep(recipeID: recipeID, stepID: stepID, clientMutationID: clientMutationID, idempotency: .body),
            offline: NativeQueuedMutation.recipeStepDelete(recipeID: recipeID, stepID: stepID, clientMutationID: clientMutationID, createdAt: now()),
            successRoute: recipeRoute(recipeID)
        )
    }

    private func reorderStepPlan(stepID: String, toStepNum: Int, clientMutationID: String) throws -> RecipeEditorMutationPlan {
        let recipeID = try existingRecipeID()
        return plan(
            online: try RecipeStepRequests.reorderStep(recipeID: recipeID, clientMutationID: clientMutationID, stepID: stepID, toStepNum: toStepNum),
            offline: NativeQueuedMutation.recipeStepReorder(recipeID: recipeID, stepID: stepID, toStepNum: toStepNum, clientMutationID: clientMutationID, createdAt: now()),
            successRoute: recipeRoute(recipeID)
        )
    }

    private func addIngredientPlan(stepID: String, clientMutationID: String, ingredient: RecipeEditorIngredientDraft) throws -> RecipeEditorMutationPlan {
        let recipeID = try existingRecipeID()
        return plan(
            online: try RecipeStepRequests.createIngredient(
                recipeID: recipeID,
                stepID: stepID,
                clientMutationID: clientMutationID,
                quantity: ingredient.quantity,
                unit: trimmedOptional(ingredient.unit),
                name: ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            offline: try NativeQueuedMutation.recipeIngredientAdd(
                recipeID: recipeID,
                stepID: stepID,
                clientMutationID: clientMutationID,
                quantity: ingredient.quantity,
                unit: trimmedOptional(ingredient.unit),
                name: ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: now()
            ),
            successRoute: recipeRoute(recipeID)
        )
    }

    private func deleteIngredientPlan(stepID: String, ingredientID: String, clientMutationID: String) throws -> RecipeEditorMutationPlan {
        let recipeID = try existingRecipeID()
        return plan(
            online: try RecipeStepRequests.deleteIngredient(recipeID: recipeID, stepID: stepID, ingredientID: ingredientID, clientMutationID: clientMutationID, idempotency: .header),
            offline: NativeQueuedMutation.recipeIngredientDelete(recipeID: recipeID, stepID: stepID, ingredientID: ingredientID, clientMutationID: clientMutationID, createdAt: now()),
            successRoute: recipeRoute(recipeID)
        )
    }

    private func replaceOutputUsesPlan(inputStepID: String, outputStepNums: [Int], clientMutationID: String) throws -> RecipeEditorMutationPlan {
        let recipeID = try existingRecipeID()
        return plan(
            online: try RecipeStepRequests.replaceOutputUses(recipeID: recipeID, clientMutationID: clientMutationID, inputStepID: inputStepID, outputStepNums: outputStepNums),
            offline: NativeQueuedMutation.recipeOutputUsesReplace(recipeID: recipeID, inputStepID: inputStepID, outputStepNums: outputStepNums, clientMutationID: clientMutationID, createdAt: now()),
            successRoute: recipeRoute(recipeID)
        )
    }

    private func plan(online: APIRequestBuilder, offline: NativeQueuedMutation, successRoute: AppRoute?) -> RecipeEditorMutationPlan {
        switch connectivity {
        case .online:
            RecipeEditorMutationPlan(remoteRequestBuilder: online, successRoute: successRoute)
        case .offline:
            RecipeEditorMutationPlan(queuedMutation: offline, successRoute: successRoute)
        }
    }

    private func existingRecipeID() throws -> String {
        guard let recipeID = draft.recipeID else {
            throw RecipeEditorPlanningError.missingRecipeID
        }

        return recipeID
    }

    private func recipeRoute(_ recipeID: String) -> AppRoute {
        .recipeDetail(id: recipeID, presentation: .detail)
    }

    private func blocked(_ reason: String) -> RecipeEditorMutationPlan {
        RecipeEditorMutationPlan(blockedReason: reason)
    }
}

public enum RecipeEditorPlanningError: Error, Equatable, Sendable {
    case missingRecipeID
}
