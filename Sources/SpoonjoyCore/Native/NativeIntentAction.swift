import Foundation

public enum NativeIntentActionError: Error, Equatable, CustomStringConvertible {
    case invalidRecipeID(String)
    case invalidCookbookID(String)
    case invalidProfileIdentifier(String)
    case invalidShoppingItemID(String)
    case invalidScaleFactor(Double)
    case emptyShoppingItem
    case emptyCaptureSource
    case authRequired
    case unresolvedRecipeEntity
    case unresolvedCookbookEntity
    case unresolvedShoppingListEntity
    case unresolvedShoppingItemEntity
    case unresolvedSpoonEntity
    case unresolvedCaptureDraftEntity
    case unresolvedChefProfileEntity
    case shareUnavailable(AppRoute)

    public var description: String {
        switch self {
        case .invalidRecipeID(let recipeID):
            "Recipe ID \(recipeID) is not safe for a native route."
        case .invalidCookbookID(let cookbookID):
            "Cookbook ID \(cookbookID) is not safe for a native route."
        case .invalidProfileIdentifier(let profileIdentifier):
            "Profile identifier \(profileIdentifier) is not safe for a native route."
        case .invalidShoppingItemID(let itemID):
            "Shopping item ID \(itemID) is not safe for a native route."
        case .invalidScaleFactor(let scaleFactor):
            "Scale factor \(scaleFactor) must be greater than zero."
        case .emptyShoppingItem:
            "Shopping item name must be non-empty."
        case .emptyCaptureSource:
            "Capture source must include text or a URL."
        case .authRequired:
            "Sign in to Spoonjoy before queueing this Siri action."
        case .unresolvedRecipeEntity:
            "Choose a Spoonjoy recipe before running this Siri action."
        case .unresolvedCookbookEntity:
            "Choose a Spoonjoy cookbook before running this Siri action."
        case .unresolvedShoppingListEntity:
            "Choose a Spoonjoy shopping list before running this Siri action."
        case .unresolvedShoppingItemEntity:
            "Choose a Spoonjoy shopping item before running this Siri action."
        case .unresolvedSpoonEntity:
            "Choose a Spoonjoy cook log before running this Siri action."
        case .unresolvedCaptureDraftEntity:
            "Choose a Spoonjoy capture draft before running this Siri action."
        case .unresolvedChefProfileEntity:
            "Choose a Spoonjoy chef profile before running this Siri action."
        case .shareUnavailable(let route):
            "Spoonjoy cannot create a native share value for \(route.stateIdentifier)."
        }
    }
}

public enum NativeIntentAction: Equatable {
    case openRoute(AppRoute, url: URL)
    case addShoppingListItem(QueuedMutation, route: AppRoute, url: URL)
    case shoppingMutation(NativeQueuedMutation, route: AppRoute, url: URL)
    case captureDraft(CaptureDraft, route: AppRoute, url: URL)

    public var route: AppRoute {
        switch self {
        case .openRoute(let route, _),
             .addShoppingListItem(_, let route, _),
             .shoppingMutation(_, let route, _),
             .captureDraft(_, let route, _):
            route
        }
    }

    public var url: URL {
        switch self {
        case .openRoute(_, let url),
             .addShoppingListItem(_, _, let url),
             .shoppingMutation(_, _, let url),
             .captureDraft(_, _, let url):
            url
        }
    }

    public var queuedMutation: QueuedMutation? {
        switch self {
        case .addShoppingListItem(let mutation, _, _):
            mutation
        case .openRoute, .shoppingMutation, .captureDraft:
            nil
        }
    }

    public var nativeQueuedMutation: NativeQueuedMutation? {
        switch self {
        case .addShoppingListItem(let mutation, _, _):
            try? NativeQueuedMutation.intentMutation(from: mutation)
        case .shoppingMutation(let mutation, _, _):
            mutation
        case .openRoute, .captureDraft:
            nil
        }
    }

    public var captureDraft: CaptureDraft? {
        switch self {
        case .captureDraft(let draft, _, _):
            draft
        case .openRoute, .addShoppingListItem, .shoppingMutation:
            nil
        }
    }
}

public struct NativeIntentShareValue: Equatable, Sendable {
    public let domain: NativeShareDomain
    public let kind: NativeSharePayloadKind
    public let publicURL: URL?
    public let route: AppRoute?
    public let title: String
    public let subtitle: String
    public let privateTransferValue: String?

    public init(
        domain: NativeShareDomain,
        kind: NativeSharePayloadKind,
        publicURL: URL?,
        route: AppRoute?,
        title: String,
        subtitle: String,
        privateTransferValue: String?
    ) {
        self.domain = domain
        self.kind = kind
        self.publicURL = publicURL
        self.route = route
        self.title = title
        self.subtitle = subtitle
        self.privateTransferValue = privateTransferValue
    }

    public var isPublicURL: Bool {
        kind == NativeSharePayloadKind.publicURL
    }

    public var isPrivateTransfer: Bool {
        kind == NativeSharePayloadKind.privateTransfer
    }
}

public struct NativeIntentActionResolver {
    public init() {}

    public func openRecipe(recipeID: String) throws -> NativeIntentAction {
        let id = try canonicalRecipeID(recipeID)
        return openRoute(.recipeDetail(id: id, presentation: .detail))
    }

    public func openRecipe(recipe: RecipeEntityDescriptor) throws -> NativeIntentAction {
        try openRoute(recipeDetailRoute(recipe, presentation: .detail))
    }

    public func openCookbook(cookbook: CookbookEntityDescriptor) throws -> NativeIntentAction {
        try openRoute(cookbookDetailRoute(cookbook))
    }

    public func openProfile(profile: ChefProfileEntityDescriptor) throws -> NativeIntentAction {
        try openRoute(profileRoute(profile))
    }

    public func searchSpoonjoy(query: String, scope: SearchScope) -> NativeIntentAction {
        let route = AppRoute.search(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            scope: scope
        )
        return openRoute(route)
    }

    public func startCookMode(recipeID: String) throws -> NativeIntentAction {
        let id = try canonicalRecipeID(recipeID)
        return openRoute(.recipeDetail(id: id, presentation: .cook))
    }

    public func startCookMode(recipe: RecipeEntityDescriptor) throws -> NativeIntentAction {
        try openRoute(recipeDetailRoute(recipe, presentation: .cook))
    }

    public func continueCookMode(recipeID: String) throws -> NativeIntentAction {
        try startCookMode(recipeID: recipeID)
    }

    public func continueCookMode(recipe: RecipeEntityDescriptor) throws -> NativeIntentAction {
        try startCookMode(recipe: recipe)
    }

    public func shareRecipe(recipe: RecipeEntityDescriptor) throws -> NativeIntentShareValue {
        try publicShareValue(route: recipeDetailRoute(recipe, presentation: .detail), title: recipe.title, subtitle: recipe.subtitle)
    }

    public func shareCookbook(cookbook: CookbookEntityDescriptor) throws -> NativeIntentShareValue {
        try publicShareValue(route: cookbookDetailRoute(cookbook), title: cookbook.title, subtitle: cookbook.subtitle)
    }

    public func shareShoppingList(shoppingList: ShoppingListEntityDescriptor) throws -> NativeIntentShareValue {
        guard !shoppingList.isPlaceholder else {
            throw NativeIntentActionError.unresolvedShoppingListEntity
        }
        return NativeIntentShareValue(
            domain: .shoppingList,
            kind: .privateTransfer,
            publicURL: nil,
            route: shoppingList.route,
            title: shoppingList.title,
            subtitle: shoppingList.subtitle,
            privateTransferValue: shoppingList.transferValue.privateTransferValue
        )
    }

    public func addShoppingListItem(
        name: String,
        quantity: Double?,
        unit: String?,
        createdAt: String
    ) throws -> NativeIntentAction {
        let normalizedName = try requiredTrimmed(name, error: .emptyShoppingItem).lowercased()
        let mutationID = "intent-shopping-add-\(stableToken(normalizedName))-\(stableToken(createdAt))"
        let mutation = QueuedMutation(
            id: mutationID,
            clientMutationID: mutationID,
            createdAt: createdAt,
            kind: .shoppingAdd(
                name: normalizedName,
                quantity: quantity,
                unit: normalizedOptional(unit),
                categoryKey: nil,
                iconKey: nil
            )
        )

        return .addShoppingListItem(
            mutation,
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func setShoppingListItemChecked(
        itemID: String,
        checked: Bool,
        createdAt: String
    ) throws -> NativeIntentAction {
        let id = try canonicalShoppingItemID(itemID)
        let mutationID = "intent-shopping-check-\(stableToken(id))-\(checked ? "checked" : "unchecked")-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingCheckItem(
                itemID: id,
                checked: checked,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func addRecipeIngredientsToShoppingList(
        recipeID: String,
        scaleFactor: Double,
        createdAt: String
    ) throws -> NativeIntentAction {
        let id = try canonicalRecipeID(recipeID)
        guard scaleFactor.isFinite && scaleFactor > 0 else {
            throw NativeIntentActionError.invalidScaleFactor(scaleFactor)
        }
        let mutationID = "intent-shopping-recipe-\(stableToken(id))-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingAddFromRecipe(
                recipeID: id,
                scaleFactor: scaleFactor,
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func clearCompletedShoppingItems(createdAt: String) -> NativeIntentAction {
        let mutationID = "intent-shopping-clear-completed-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingClearCompleted(
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func clearShoppingList(createdAt: String) -> NativeIntentAction {
        let mutationID = "intent-shopping-clear-all-\(stableToken(createdAt))"
        return .shoppingMutation(
            .shoppingClearAll(
                clientMutationID: mutationID,
                createdAt: createdAt
            ),
            route: .shoppingList,
            url: DeepLinkURLBuilder.url(for: .shoppingList)
        )
    }

    public func captureRecipe(source: String, createdAt: String) throws -> NativeIntentAction {
        let trimmedSource = try requiredTrimmed(source, error: .emptyCaptureSource)
        let draft = try CaptureDraft.localText(
            id: "intent-capture-\(stableToken(createdAt))",
            rawText: trimmedSource,
            createdAt: createdAt
        )

        return .captureDraft(
            draft,
            route: .capture,
            url: DeepLinkURLBuilder.url(for: .capture)
        )
    }

    private func canonicalRecipeID(_ recipeID: String) throws -> String {
        try canonicalObjectID(recipeID, invalidError: .invalidRecipeID(recipeID))
    }

    private func canonicalCookbookID(_ cookbookID: String) throws -> String {
        try canonicalObjectID(cookbookID, invalidError: .invalidCookbookID(cookbookID))
    }

    private func canonicalObjectID(
        _ rawID: String,
        invalidError: NativeIntentActionError
    ) throws -> String {
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !id.isEmpty,
            !id.contains("/"),
            !id.contains("\\"),
            !id.contains(".."),
            id != ".",
            id != "..",
            id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else {
            throw invalidError
        }

        return id
    }

    private func recipeDetailRoute(
        _ recipe: RecipeEntityDescriptor,
        presentation: RecipePresentation
    ) throws -> AppRoute {
        guard !recipe.isPlaceholder else {
            throw NativeIntentActionError.unresolvedRecipeEntity
        }
        let id = try canonicalRecipeID(recipe.id)
        guard recipe.route == .recipeDetail(id: id, presentation: .detail) else {
            throw NativeIntentActionError.invalidRecipeID(recipe.id)
        }
        return .recipeDetail(id: id, presentation: presentation)
    }

    private func cookbookDetailRoute(_ cookbook: CookbookEntityDescriptor) throws -> AppRoute {
        guard !cookbook.isPlaceholder else {
            throw NativeIntentActionError.unresolvedCookbookEntity
        }
        let id = try canonicalCookbookID(cookbook.id)
        guard cookbook.route == .cookbookDetail(id: id) else {
            throw NativeIntentActionError.invalidCookbookID(cookbook.id)
        }
        return .cookbookDetail(id: id)
    }

    private func profileRoute(_ profile: ChefProfileEntityDescriptor) throws -> AppRoute {
        guard !profile.isPlaceholder else {
            throw NativeIntentActionError.unresolvedChefProfileEntity
        }
        guard AppRoute.isSafeProfileIdentifier(profile.username),
              profile.route == .profile(identifier: profile.username) else {
            throw NativeIntentActionError.invalidProfileIdentifier(profile.username)
        }
        return .profile(identifier: profile.username)
    }

    private func openRoute(_ route: AppRoute) -> NativeIntentAction {
        .openRoute(route, url: DeepLinkURLBuilder.url(for: route))
    }

    func publicShareValue(
        route: AppRoute,
        title: String,
        subtitle: String
    ) throws -> NativeIntentShareValue {
        guard let payload = NativeSharePayload.publicRoute(route),
              payload.kind == NativeSharePayloadKind.publicURL,
              let publicURL = payload.publicURL else {
            throw NativeIntentActionError.shareUnavailable(route)
        }

        return NativeIntentShareValue(
            domain: payload.domain,
            kind: NativeSharePayloadKind.publicURL,
            publicURL: publicURL,
            route: route,
            title: title,
            subtitle: subtitle,
            privateTransferValue: nil
        )
    }

    private func canonicalShoppingItemID(_ itemID: String) throws -> String {
        let id = itemID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !id.isEmpty,
            !id.contains("/"),
            !id.contains("\\"),
            !id.contains(".."),
            id != ".",
            id != "..",
            id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else {
            throw NativeIntentActionError.invalidShoppingItemID(itemID)
        }

        return id
    }

    private func requiredTrimmed(_ value: String, error: NativeIntentActionError) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw error
        }

        return trimmed
    }

    private func normalizedOptional(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "" ? nil : normalized
    }

    private func stableToken(_ value: String) -> String {
        let token = value.unicodeScalars.map { scalar -> String in
            if CharacterSet.alphanumerics.contains(scalar) || scalar.value == 95 {
                return String(scalar)
            }

            return "-"
        }.joined()

        return token.split(separator: "-").joined(separator: "-")
    }

}
