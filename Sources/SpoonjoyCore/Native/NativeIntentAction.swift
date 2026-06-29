import Foundation

public enum NativeIntentActionError: Error, Equatable, CustomStringConvertible {
    case invalidRecipeID(String)
    case invalidShoppingItemID(String)
    case invalidScaleFactor(Double)
    case emptyShoppingItem
    case emptyCaptureSource
    case authRequired
    case unresolvedRecipeEntity
    case unresolvedShoppingItemEntity
    case unresolvedSpoonEntity

    public var description: String {
        switch self {
        case .invalidRecipeID(let recipeID):
            "Recipe ID \(recipeID) is not safe for a native route."
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
        case .unresolvedShoppingItemEntity:
            "Choose a Spoonjoy shopping item before running this Siri action."
        case .unresolvedSpoonEntity:
            "Choose a Spoonjoy cook log before running this Siri action."
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

public struct NativeIntentActionResolver {
    public init() {}

    public func openRecipe(recipeID: String) throws -> NativeIntentAction {
        let id = try canonicalRecipeID(recipeID)
        return .openRoute(
            .recipeDetail(id: id, presentation: .detail),
            url: schemeURL(host: "recipes", path: "/\(id)")
        )
    }

    public func startCookMode(recipeID: String) throws -> NativeIntentAction {
        let id = try canonicalRecipeID(recipeID)
        return .openRoute(
            .recipeDetail(id: id, presentation: .cook),
            url: schemeURL(host: "recipes", path: "/\(id)/cook")
        )
    }

    public func continueCookMode(recipeID: String) throws -> NativeIntentAction {
        try startCookMode(recipeID: recipeID)
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
            url: schemeURL(host: "shopping-list")
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
            url: schemeURL(host: "shopping-list")
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
            url: schemeURL(host: "shopping-list")
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
            url: schemeURL(host: "shopping-list")
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
            url: schemeURL(host: "shopping-list")
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
            url: schemeURL(host: "capture")
        )
    }

    private func canonicalRecipeID(_ recipeID: String) throws -> String {
        let id = recipeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !id.isEmpty,
            !id.contains("/"),
            !id.contains("\\"),
            !id.contains(".."),
            id != ".",
            id != "..",
            id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else {
            throw NativeIntentActionError.invalidRecipeID(recipeID)
        }

        return id
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

    private func schemeURL(host: String, path: String = "") -> URL {
        var components = URLComponents()
        components.scheme = DeepLinkManifest.urlSchemes[0]
        components.host = host
        components.path = path
        return components.url!
    }
}
