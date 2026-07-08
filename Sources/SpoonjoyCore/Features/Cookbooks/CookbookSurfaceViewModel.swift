import Foundation

public enum CookbookSurfaceConnectivity: Equatable, Sendable {
    case online
    case offline
}

public enum CookbookActionConfirmation: Equatable, Sendable {
    case required
    case confirmed
}

public struct CookbookActionConfirmationPrompt: Equatable, Sendable {
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

public struct CookbookSurfaceContext: Equatable, Sendable {
    public let currentChefID: String?
    public let currentChef: ChefSummary?

    public init(currentChefID: String?, currentChef: ChefSummary? = nil) {
        self.currentChefID = currentChefID
        self.currentChef = currentChef
    }
}

public enum CookbookSurfaceAction: Equatable, Sendable {
    case create(title: String, clientMutationID: String)
    case rename(title: String, clientMutationID: String)
    case deleteCookbook(clientMutationID: String, confirmation: CookbookActionConfirmation)
    case addRecipe(recipeID: String, clientMutationID: String)
    case removeRecipe(recipeID: String, clientMutationID: String, confirmation: CookbookActionConfirmation)
}

public enum CookbookSurfaceActionID: Equatable, Sendable {
    case share
    case editTitle
    case addRecipe
    case removeRecipe
    case deleteCookbook
}

public struct CookbookSurfaceActionPlan: Equatable {
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let offlineFallbackMutation: NativeQueuedMutation?
    public let updatedCookbook: Cookbook?
    public let successRoute: AppRoute?
    public let blockedReason: String?
    public let confirmationPrompt: CookbookActionConfirmationPrompt?

    public init(
        remoteRequestBuilder: APIRequestBuilder? = nil,
        queuedMutation: NativeQueuedMutation? = nil,
        offlineFallbackMutation: NativeQueuedMutation? = nil,
        updatedCookbook: Cookbook? = nil,
        successRoute: AppRoute? = nil,
        blockedReason: String? = nil,
        confirmationPrompt: CookbookActionConfirmationPrompt? = nil
    ) {
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.offlineFallbackMutation = offlineFallbackMutation
        self.updatedCookbook = updatedCookbook
        self.successRoute = successRoute
        self.blockedReason = blockedReason
        self.confirmationPrompt = confirmationPrompt
    }
}

public struct CookbookCreatePlanner: Sendable {
    private let currentChefID: String?
    private let currentChef: ChefSummary?
    private let queuedMutations: [NativeQueuedMutation]
    private let connectivity: CookbookSurfaceConnectivity
    private let timestamp: @Sendable () -> String

    public init(
        currentChefID: String?,
        currentChef: ChefSummary? = nil,
        queuedMutations: [NativeQueuedMutation],
        connectivity: CookbookSurfaceConnectivity,
        timestamp: @escaping @Sendable () -> String
    ) {
        self.currentChefID = currentChefID
        self.currentChef = currentChef
        self.queuedMutations = queuedMutations
        self.connectivity = connectivity
        self.timestamp = timestamp
    }

    public func planCreate(title: String, clientMutationID: String) throws -> CookbookSurfaceActionPlan {
        guard let currentChefID else {
            return CookbookSurfaceActionPlan(blockedReason: "Sign in to create a cookbook.")
        }

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            return CookbookSurfaceActionPlan(blockedReason: "Enter a cookbook title.")
        }

        let offline = NativeQueuedMutation.cookbookCreate(
            clientMutationID: clientMutationID,
            title: normalizedTitle,
            createdAt: timestamp()
        )
        let optimisticCookbook = Self.optimisticCreatedCookbook(
            id: "cookbook_local_\(clientMutationID)",
            title: normalizedTitle,
            chef: currentChef ?? ChefSummary(id: currentChefID, username: "Spoonjoy"),
            createdAt: offline.createdAt
        )

        if queuedMutations.contains(where: { $0.dependencyKey == offline.dependencyKey }) {
            return CookbookSurfaceActionPlan(
                queuedMutation: offline,
                updatedCookbook: optimisticCookbook,
                successRoute: .cookbooks
            )
        }

        let online = try CookbookWriteRequests.createCookbook(
            clientMutationID: clientMutationID,
            title: normalizedTitle
        )
        switch connectivity {
        case .online:
            return CookbookSurfaceActionPlan(
                remoteRequestBuilder: online,
                offlineFallbackMutation: offline,
                updatedCookbook: optimisticCookbook,
                successRoute: .cookbooks
            )
        case .offline:
            return CookbookSurfaceActionPlan(
                queuedMutation: offline,
                updatedCookbook: optimisticCookbook,
                successRoute: .cookbooks
            )
        }
    }

    private static func optimisticCreatedCookbook(
        id: String,
        title: String,
        chef: ChefSummary,
        createdAt: String
    ) -> Cookbook {
        let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/\(id)")!
        return Cookbook(
            id: id,
            title: title,
            chef: chef,
            recipeCount: 0,
            cover: CookbookCover(imageURLs: []),
            href: "/cookbooks/\(id)",
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(
                creditText: "\(title) by \(chef.username) on Spoonjoy",
                canonicalURL: canonicalURL
            ),
            createdAt: createdAt,
            updatedAt: createdAt,
            recipes: []
        )
    }
}

public struct CookbookSurfaceEmptyState: Equatable, Sendable {
    public let title: String
    public let message: String
    public let systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
}

public struct CookbookSurfaceConflictBanner: Equatable, Sendable {
    public let localClientMutationID: String
    public let message: String
    public let actionTitle: String

    public init(localClientMutationID: String, message: String, actionTitle: String) {
        self.localClientMutationID = localClientMutationID
        self.message = message
        self.actionTitle = actionTitle
    }
}

public struct CookbookSurfaceRowViewModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let chefLine: String
    public let recipeCountLabel: String
    public let cover: CookbookCover
    public let openRoute: AppRoute
    public let sharePayload: NativeSharePayload?

    public init(summary: CookbookSummary) {
        id = summary.id
        title = summary.title
        chefLine = "By \(summary.chef.username)"
        recipeCountLabel = Self.recipeCountLabel(summary.recipeCount)
        cover = summary.cover
        openRoute = .cookbookDetail(id: summary.id)
        sharePayload = NativeSharePayload.publicRoute(.cookbookDetail(id: summary.id))
    }

    static func recipeCountLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "recipe" : "recipes")"
    }
}

public struct CookbookSurfaceListState: Equatable, Sendable {
    public let query: String?
    public let limit: Int
    public let cursor: PaginationCursor?
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool
    public let rows: [CookbookSurfaceRowViewModel]
    public let source: CookbookSurfaceDataSource?
    public let offlineIndicator: OfflineIndicatorState
    public let emptyState: CookbookSurfaceEmptyState?

    public var resultCountLabel: String {
        "\(rows.count) \(rows.count == 1 ? "cookbook" : "cookbooks")"
    }

    public static func empty(query: String? = nil, limit: Int = 20) -> CookbookSurfaceListState {
        CookbookSurfaceListState(
            query: query,
            limit: limit,
            cursor: nil,
            nextCursor: nil,
            hasMore: false,
            rows: [],
            source: nil,
            offlineIndicator: OfflineIndicatorState(display: .synced, dismissal: nil),
            emptyState: emptyState(for: query)
        )
    }

    public init(
        query: String?,
        limit: Int,
        cursor: PaginationCursor?,
        nextCursor: PaginationCursor?,
        hasMore: Bool,
        rows: [CookbookSurfaceRowViewModel],
        source: CookbookSurfaceDataSource?,
        offlineIndicator: OfflineIndicatorState,
        emptyState: CookbookSurfaceEmptyState?
    ) {
        self.query = query
        self.limit = limit
        self.cursor = cursor
        self.nextCursor = nextCursor
        self.hasMore = hasMore
        self.rows = rows
        self.source = source
        self.offlineIndicator = offlineIndicator
        self.emptyState = emptyState
    }

    static func from(page: CookbookSurfacePage, now: Date) -> CookbookSurfaceListState {
        let rows = page.rows.map(CookbookSurfaceRowViewModel.init(summary:))
        return CookbookSurfaceListState(
            query: page.query,
            limit: page.limit,
            cursor: page.cursor,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore,
            rows: rows,
            source: page.source,
            offlineIndicator: page.offlineIndicator(now: now),
            emptyState: rows.isEmpty ? emptyState(for: page.query) : nil
        )
    }

    public func applyingCreatedCookbook(_ cookbook: Cookbook, queuedMutation: NativeQueuedMutation?) -> CookbookSurfaceListState {
        let nextRows = (rows.filter { $0.id != cookbook.id } + [CookbookSurfaceRowViewModel(summary: CookbookSummary(cookbook: cookbook))])
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return CookbookSurfaceListState(
            query: query,
            limit: max(limit, nextRows.count),
            cursor: cursor,
            nextCursor: nextCursor,
            hasMore: hasMore,
            rows: nextRows,
            source: source,
            offlineIndicator: queuedMutation.map {
                OfflineIndicatorState(
                    display: .queuedWork(count: 1, oldestClientMutationID: $0.clientMutationID),
                    dismissal: nil
                )
            } ?? offlineIndicator,
            emptyState: nil
        )
    }

    private static func emptyState(for query: String?) -> CookbookSurfaceEmptyState {
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CookbookSurfaceEmptyState(
                title: "No matching cookbooks",
                message: "Try another title, chef, or recipe in the collection.",
                systemImage: "magnifyingglass"
            )
        }

        return CookbookSurfaceEmptyState(
            title: "No cookbooks yet",
            message: "Create a cookbook to collect recipes into a kitchen-ready set.",
            systemImage: "books.vertical"
        )
    }
}

public struct CookbookRecipeRowViewModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let servingsLabel: String?
    public let coverImageURL: URL?
    public let coverProvenanceLabel: String?
    public let openRoute: AppRoute

    public init(summary: RecipeSummary) {
        id = summary.id
        title = summary.title
        servingsLabel = Self.servingsLabel(summary.servings)
        coverImageURL = summary.displayCoverImageURL
        coverProvenanceLabel = summary.displayCoverProvenanceLabel
        openRoute = .recipeDetail(id: summary.id, presentation: .detail)
    }

    private static func servingsLabel(_ servings: String?) -> String? {
        guard let servings = servings?.trimmingCharacters(in: .whitespacesAndNewlines), !servings.isEmpty else {
            return nil
        }

        return "Serves \(servings)"
    }
}

public struct CookbookSurfaceOwnerTools: Equatable, Sendable {
    public let isVisible: Bool
    public let availableRecipes: [RecipeSummary]
    public let editTitleActionTitle: String
    public let addRecipeActionTitle: String
    public let deleteConfirmation: CookbookActionConfirmationPrompt?

    public init(
        isVisible: Bool,
        availableRecipes: [RecipeSummary],
        editTitleActionTitle: String,
        addRecipeActionTitle: String,
        deleteConfirmation: CookbookActionConfirmationPrompt?
    ) {
        self.isVisible = isVisible
        self.availableRecipes = availableRecipes
        self.editTitleActionTitle = editTitleActionTitle
        self.addRecipeActionTitle = addRecipeActionTitle
        self.deleteConfirmation = deleteConfirmation
    }
}

public struct CookbookDetailViewModel: Sendable {
    public let cookbook: Cookbook
    public let id: String
    public let title: String
    public let chefLine: String
    public let recipeCountLabel: String
    public let cover: CookbookCover
    public let recipes: [CookbookRecipeRowViewModel]
    public let sharePayload: NativeSharePayload
    public let ownerTools: CookbookSurfaceOwnerTools
    public let availableActionIDs: [CookbookSurfaceActionID]
    public let offlineIndicator: OfflineIndicatorState
    public let queuedWorkSummary: String?
    public let conflictBanner: CookbookSurfaceConflictBanner?

    private let result: CookbookSurfaceDetailResult
    private let context: CookbookSurfaceContext
    private let queuedMutations: [NativeQueuedMutation]
    private let conflicts: [NativeSyncConflict]
    private let connectivity: CookbookSurfaceConnectivity
    private let now: @Sendable () -> Date
    private let timestamp: @Sendable () -> String

    public init(
        result: CookbookSurfaceDetailResult,
        context: CookbookSurfaceContext,
        queuedMutations: [NativeQueuedMutation],
        conflicts: [NativeSyncConflict],
        connectivity: CookbookSurfaceConnectivity,
        now: @escaping @Sendable () -> Date,
        timestamp: @escaping @Sendable () -> String
    ) {
        self.result = result
        self.context = context
        self.queuedMutations = queuedMutations
        self.conflicts = conflicts
        self.connectivity = connectivity
        self.now = now
        self.timestamp = timestamp
        cookbook = result.cookbook
        id = result.cookbook.id
        title = result.cookbook.title
        chefLine = "By \(result.cookbook.chef.username)"
        recipeCountLabel = CookbookSurfaceRowViewModel.recipeCountLabel(result.cookbook.recipeCount)
        cover = result.cookbook.cover
        recipes = result.cookbook.recipes.map(CookbookRecipeRowViewModel.init(summary:))
        sharePayload = (try? NativeSharePayload.publicCookbook(result.cookbook)) ?? NativeSharePayload.publicRoute(.cookbookDetail(id: result.cookbook.id))!
        let isOwner = context.currentChefID == result.cookbook.chef.id
        ownerTools = CookbookSurfaceOwnerTools(
            isVisible: isOwner,
            availableRecipes: result.availableRecipes,
            editTitleActionTitle: "Edit title",
            addRecipeActionTitle: "Add recipe",
            deleteConfirmation: isOwner ? Self.deleteConfirmationPrompt(for: result.cookbook) : nil
        )
        availableActionIDs = isOwner ? [.share, .editTitle, .addRecipe, .removeRecipe, .deleteCookbook] : [.share]
        let cookbookQueuedMutations = Self.cookbookQueuedMutations(
            queuedMutations,
            dependencyKey: Self.dependencyKey(for: result.cookbook.id)
        )
        queuedWorkSummary = Self.queuedWorkSummary(count: cookbookQueuedMutations.count)
        let cookbookConflicts = Self.cookbookConflicts(conflicts, queuedMutations: cookbookQueuedMutations)
        conflictBanner = cookbookConflicts.first.map {
            CookbookSurfaceConflictBanner(
                localClientMutationID: $0.clientMutationID,
                message: $0.message,
                actionTitle: "Review cookbook conflict"
            )
        }
        if let conflict = cookbookConflicts.first {
            offlineIndicator = OfflineIndicatorState(
                display: .conflict(recordID: conflict.clientMutationID, mutationID: conflict.clientMutationID),
                dismissal: nil
            )
        } else if !cookbookQueuedMutations.isEmpty {
            offlineIndicator = OfflineIndicatorState(
                display: .queuedWork(count: cookbookQueuedMutations.count, oldestClientMutationID: cookbookQueuedMutations.first?.clientMutationID),
                dismissal: nil
            )
        } else if connectivity == .offline {
            offlineIndicator = OfflineIndicatorState(display: .offline, dismissal: nil)
        } else {
            offlineIndicator = result.offlineIndicator(now: now())
        }
    }

    public func plan(_ action: CookbookSurfaceAction) throws -> CookbookSurfaceActionPlan {
        switch action {
        case .create(let title, let clientMutationID):
            guard context.currentChefID != nil else {
                return blocked("Sign in to create a cookbook.")
            }
            let normalizedTitle = Self.normalizedTitle(title)
            guard !normalizedTitle.isEmpty else {
                return blocked("Enter a cookbook title.")
            }
            return try mutationPlan(
                online: CookbookWriteRequests.createCookbook(clientMutationID: clientMutationID, title: normalizedTitle),
                offline: NativeQueuedMutation.cookbookCreate(
                    clientMutationID: clientMutationID,
                    title: normalizedTitle,
                    createdAt: timestamp()
                ),
                updatedCookbook: nil,
                successRoute: .cookbooks
            )
        case .rename(let title, let clientMutationID):
            guard isOwner else {
                return blocked("Only \(cookbook.chef.username) can edit this cookbook.")
            }
            let normalizedTitle = Self.normalizedTitle(title)
            guard !normalizedTitle.isEmpty else {
                return blocked("Enter a cookbook title.")
            }
            return try mutationPlan(
                online: CookbookWriteRequests.updateCookbook(
                    id: cookbook.id,
                    clientMutationID: clientMutationID,
                    title: normalizedTitle
                ),
                offline: NativeQueuedMutation.cookbookUpdate(
                    cookbookID: cookbook.id,
                    title: normalizedTitle,
                    clientMutationID: clientMutationID,
                    createdAt: timestamp()
                ),
                updatedCookbook: cookbook.copy(title: normalizedTitle),
                successRoute: .cookbookDetail(id: cookbook.id)
            )
        case .deleteCookbook(let clientMutationID, let confirmation):
            guard isOwner else {
                return blocked("Only \(cookbook.chef.username) can delete this cookbook.")
            }
            guard confirmation == .confirmed else {
                return CookbookSurfaceActionPlan(confirmationPrompt: Self.deleteConfirmationPrompt(for: cookbook))
            }
            return try mutationPlan(
                online: CookbookWriteRequests.deleteCookbook(
                    id: cookbook.id,
                    clientMutationID: clientMutationID,
                    idempotency: .query
                ),
                offline: NativeQueuedMutation.cookbookDelete(
                    cookbookID: cookbook.id,
                    clientMutationID: clientMutationID,
                    createdAt: timestamp()
                ),
                updatedCookbook: nil,
                successRoute: .cookbooks
            )
        case .addRecipe(let recipeID, let clientMutationID):
            guard isOwner else {
                return blocked("Only \(cookbook.chef.username) can edit this cookbook.")
            }
            guard !cookbook.recipes.contains(where: { $0.id == recipeID }) else {
                return blocked("This recipe is already in the cookbook.")
            }
            guard let recipe = result.availableRecipes.first(where: { $0.id == recipeID }) else {
                return blocked("Choose one of your recipes before adding it.")
            }
            return try mutationPlan(
                online: CookbookWriteRequests.addRecipe(
                    cookbookID: cookbook.id,
                    recipeID: recipeID,
                    clientMutationID: clientMutationID
                ),
                offline: NativeQueuedMutation.cookbookAddRecipe(
                    cookbookID: cookbook.id,
                    recipeID: recipeID,
                    clientMutationID: clientMutationID,
                    createdAt: timestamp()
                ),
                updatedCookbook: cookbook.copy(recipes: cookbook.recipes + [recipe]),
                successRoute: .cookbookDetail(id: cookbook.id)
            )
        case .removeRecipe(let recipeID, let clientMutationID, let confirmation):
            guard isOwner else {
                return blocked("Only \(cookbook.chef.username) can edit this cookbook.")
            }
            guard let recipe = cookbook.recipes.first(where: { $0.id == recipeID }) else {
                return blocked("This recipe is not in the cookbook.")
            }
            guard confirmation == .confirmed else {
                return CookbookSurfaceActionPlan(confirmationPrompt: Self.removeConfirmationPrompt(for: recipe))
            }
            return try mutationPlan(
                online: CookbookWriteRequests.removeRecipe(
                    cookbookID: cookbook.id,
                    recipeID: recipeID,
                    clientMutationID: clientMutationID,
                    idempotency: .body
                ),
                offline: NativeQueuedMutation.cookbookRemoveRecipe(
                    cookbookID: cookbook.id,
                    recipeID: recipeID,
                    clientMutationID: clientMutationID,
                    createdAt: timestamp()
                ),
                updatedCookbook: cookbook.copy(recipes: cookbook.recipes.filter { $0.id != recipeID }),
                successRoute: .cookbookDetail(id: cookbook.id)
            )
        }
    }

    public func applying(updatedCookbook: Cookbook, queuedMutation: NativeQueuedMutation? = nil) -> CookbookDetailViewModel {
        CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: updatedCookbook,
                source: result.source,
                availableRecipes: availableRecipes(afterApplying: updatedCookbook)
            ),
            context: context,
            queuedMutations: queuedMutation.map { queuedMutations + [$0] } ?? queuedMutations,
            conflicts: conflicts,
            connectivity: connectivity,
            now: now,
            timestamp: timestamp
        )
    }

    private var isOwner: Bool {
        context.currentChefID == cookbook.chef.id
    }

    private func availableRecipes(afterApplying updatedCookbook: Cookbook) -> [RecipeSummary] {
        let originalRecipeIDs = Set(cookbook.recipes.map(\.id))
        let updatedRecipeIDs = Set(updatedCookbook.recipes.map(\.id))
        let newlySavedRecipeIDs = updatedRecipeIDs.subtracting(originalRecipeIDs)
        let removedRecipes = cookbook.recipes.filter { !updatedRecipeIDs.contains($0.id) }

        return (result.availableRecipes.filter { !newlySavedRecipeIDs.contains($0.id) } + removedRecipes)
            .deduplicatedByID()
    }

    private func mutationPlan(
        online: APIRequestBuilder,
        offline: NativeQueuedMutation,
        updatedCookbook: Cookbook?,
        successRoute: AppRoute?
    ) -> CookbookSurfaceActionPlan {
        if !Self.cookbookQueuedMutations(queuedMutations, dependencyKey: offline.dependencyKey).isEmpty {
            return CookbookSurfaceActionPlan(
                queuedMutation: offline,
                updatedCookbook: updatedCookbook,
                successRoute: successRoute
            )
        }

        switch connectivity {
        case .online:
            return CookbookSurfaceActionPlan(
                remoteRequestBuilder: online,
                offlineFallbackMutation: offline,
                updatedCookbook: updatedCookbook,
                successRoute: successRoute
            )
        case .offline:
            return CookbookSurfaceActionPlan(
                queuedMutation: offline,
                updatedCookbook: updatedCookbook,
                successRoute: successRoute
            )
        }
    }

    private func blocked(_ reason: String) -> CookbookSurfaceActionPlan {
        CookbookSurfaceActionPlan(blockedReason: reason)
    }

    private static func cookbookQueuedMutations(_ mutations: [NativeQueuedMutation], dependencyKey: String) -> [NativeQueuedMutation] {
        mutations.filter { mutation in
            mutation.blocksDependencyKey(dependencyKey)
        }
    }

    private static func cookbookConflicts(
        _ conflicts: [NativeSyncConflict],
        queuedMutations: [NativeQueuedMutation]
    ) -> [NativeSyncConflict] {
        let cookbookClientMutationIDs = Set(queuedMutations.map(\.clientMutationID))
        return conflicts.filter { cookbookClientMutationIDs.contains($0.clientMutationID) }
    }

    private static func queuedWorkSummary(count: Int) -> String? {
        guard count > 0 else {
            return nil
        }

        return count == 1 ? "1 cookbook change waiting to sync" : "\(count) cookbook changes waiting to sync"
    }

    private static func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dependencyKey(for cookbookID: String) -> String {
        "cookbook:\(cookbookID)"
    }

    private static func deleteConfirmationPrompt(for cookbook: Cookbook) -> CookbookActionConfirmationPrompt {
        CookbookActionConfirmationPrompt(
            title: "Delete \(cookbook.title)?",
            message: "This permanently deletes the cookbook and removes its recipe associations. Recipes stay in your kitchen.",
            confirmButtonTitle: "Delete Cookbook",
            isDestructive: true
        )
    }

    private static func removeConfirmationPrompt(for recipe: RecipeSummary) -> CookbookActionConfirmationPrompt {
        CookbookActionConfirmationPrompt(
            title: "Remove \(recipe.title)?",
            message: "This removes the recipe from this cookbook. The recipe itself stays in your kitchen.",
            confirmButtonTitle: "Remove Recipe",
            isDestructive: true
        )
    }
}

public struct CookbookSurfaceListViewModel: Equatable, Sendable {
    public let list: CookbookSurfaceListState

    public init(page: CookbookSurfacePage, now: @escaping @Sendable () -> Date = Date.init) {
        list = CookbookSurfaceListState.from(page: page, now: now())
    }
}

@MainActor public final class CookbookSurfaceViewModel {
    private let repository: any CookbookSurfaceRepository
    private let context: CookbookSurfaceContext
    private let queuedMutations: [NativeQueuedMutation]
    private let conflicts: [NativeSyncConflict]
    private let connectivity: CookbookSurfaceConnectivity
    private let now: @Sendable () -> Date
    private let timestamp: @Sendable () -> String

    public private(set) var list: CookbookSurfaceListState
    public private(set) var detail: CookbookDetailViewModel?

    public var canCreateCookbook: Bool {
        context.currentChefID != nil
    }

    public init(
        repository: any CookbookSurfaceRepository,
        context: CookbookSurfaceContext,
        queuedMutations: [NativeQueuedMutation],
        conflicts: [NativeSyncConflict],
        connectivity: CookbookSurfaceConnectivity,
        now: @escaping @Sendable () -> Date = Date.init,
        timestamp: @escaping @Sendable () -> String
    ) {
        self.repository = repository
        self.context = context
        self.queuedMutations = queuedMutations
        self.conflicts = conflicts
        self.connectivity = connectivity
        self.now = now
        self.timestamp = timestamp
        list = .empty()
    }

    public func loadList(query: String?, limit: Int = 20, cursor: PaginationCursor? = nil) async throws {
        let request = CookbookSurfaceListRequest(query: query, limit: limit, cursor: cursor)
        let page = try await repository.listCookbooks(request: request)
        list = CookbookSurfaceListState.from(page: page, now: now())
    }

    public func loadDetail(id: String) async throws {
        let result = try await repository.cookbookDetail(id: id)
        detail = CookbookDetailViewModel(
            result: result,
            context: context,
            queuedMutations: queuedMutations,
            conflicts: conflicts,
            connectivity: connectivity,
            now: now,
            timestamp: timestamp
        )
    }

    public func apply(page: CookbookSurfacePage) {
        list = CookbookSurfaceListState.from(page: page, now: now())
    }

    public func openCookbookRoute(id: String) -> AppRoute {
        .cookbookDetail(id: id)
    }

    public func planCreate(title: String, clientMutationID: String) throws -> CookbookSurfaceActionPlan {
        try CookbookCreatePlanner(
            currentChefID: context.currentChefID,
            currentChef: context.currentChef,
            queuedMutations: queuedMutations,
            connectivity: connectivity,
            timestamp: timestamp
        ).planCreate(title: title, clientMutationID: clientMutationID)
    }
}

private extension Array where Element == RecipeSummary {
    func deduplicatedByID() -> [RecipeSummary] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}

private extension Cookbook {
    func copy(title: String? = nil, recipes: [RecipeSummary]? = nil) -> Cookbook {
        let nextRecipes = recipes ?? self.recipes
        let nextTitle = title ?? self.title
        return Cookbook(
            id: id,
            title: nextTitle,
            chef: chef,
            recipeCount: nextRecipes.count,
            cover: cover,
            href: href,
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(
                creditText: "\(nextTitle) by \(chef.username) on Spoonjoy",
                canonicalURL: canonicalURL
            ),
            createdAt: createdAt,
            updatedAt: updatedAt,
            recipes: nextRecipes
        )
    }
}
