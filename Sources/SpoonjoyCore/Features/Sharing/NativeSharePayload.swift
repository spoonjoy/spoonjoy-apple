import Foundation

public enum NativeShareDomain: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case recipe
    case cookbook
    case shoppingList = "shopping-list"
    case shoppingItem = "shopping-item"
    case spoon
    case captureDraft = "capture-draft"
}

public enum NativeSharePayloadKind: String, Codable, Equatable, Sendable {
    case publicURL = "public-url"
    case privateTransfer = "private-transfer"
}

public enum NativeShareDestination: String, Codable, Equatable, Sendable {
    case shareSheet = "share-sheet"
}

public enum NativeShareTransfer: Equatable, Sendable {
    case publicURL(URL)
    case privateTransfer(String)
}

public enum NativeSharePayloadError: Error, Equatable, CustomStringConvertible {
    case invalidPublicURL(domain: NativeShareDomain, url: URL)

    public var description: String {
        switch self {
        case .invalidPublicURL(let domain, let url):
            "Invalid public \(domain.rawValue) share URL: \(url.absoluteString)"
        }
    }
}

public struct NativeSharePayload: Equatable, Identifiable, Sendable {
    public let id: String
    public let domain: NativeShareDomain
    public let kind: NativeSharePayloadKind
    public let publicURL: URL?
    public let route: AppRoute?
    public let title: String
    public let subtitle: String
    public let nativeTransfer: NativeShareTransfer?
    public let serializedTransferValue: String

    public static func publicRecipe(_ recipe: Recipe) throws -> NativeSharePayload {
        try publicObjectPayload(
            domain: .recipe,
            resourceID: recipe.id,
            title: recipe.title,
            subtitle: "Recipe by \(recipe.chef.username)",
            publicURL: recipe.canonicalURL,
            route: .recipeDetail(id: recipe.id, presentation: .detail)
        )
    }

    public static func publicCookbook(_ cookbook: Cookbook) throws -> NativeSharePayload {
        try publicObjectPayload(
            domain: .cookbook,
            resourceID: cookbook.id,
            title: cookbook.title,
            subtitle: "\(cookbook.recipeCount) recipes by \(cookbook.chef.username)",
            publicURL: cookbook.canonicalURL,
            route: .cookbookDetail(id: cookbook.id)
        )
    }

    public static func publicRoute(_ route: AppRoute) -> NativeSharePayload? {
        switch route {
        case .recipeDetail(let id, .detail):
            guard let publicURL = NativePublicShareRoutePolicy.publicURL(for: route) else {
                return nil
            }
            return NativeSharePayload(
                domain: .recipe,
                resourceID: id,
                kind: .publicURL,
                publicURL: publicURL,
                route: route,
                title: "Recipe",
                subtitle: "Spoonjoy recipe",
                nativeTransfer: .publicURL(publicURL),
                serializedTransferValue: publicURL.absoluteString
            )
        case .cookbookDetail(let id):
            guard let publicURL = NativePublicShareRoutePolicy.publicURL(for: route) else {
                return nil
            }
            return NativeSharePayload(
                domain: .cookbook,
                resourceID: id,
                kind: .publicURL,
                publicURL: publicURL,
                route: route,
                title: "Cookbook",
                subtitle: "Spoonjoy cookbook",
                nativeTransfer: .publicURL(publicURL),
                serializedTransferValue: publicURL.absoluteString
            )
        default:
            return nil
        }
    }

    public static func privateShoppingList(_ shoppingList: ShoppingListState) -> NativeSharePayload {
        let activeItems = shoppingList.activeItems
        let serializedValue = privateTransferValue(
            domain: .shoppingList,
            resourceID: shoppingList.id,
            title: "Shopping List",
            fields: [
                ("chefID", shoppingList.chef.id),
                ("itemIDs", activeItems.map(\.id).joined(separator: ",")),
                ("updatedAt", shoppingList.updatedAt)
            ]
        )

        return NativeSharePayload(
            domain: .shoppingList,
            resourceID: shoppingList.id,
            kind: .privateTransfer,
            publicURL: nil,
            route: nil,
            title: "Shopping List",
            subtitle: "\(activeItems.count) active items",
            nativeTransfer: .privateTransfer(serializedValue),
            serializedTransferValue: serializedValue
        )
    }

    public static func privateShoppingItem(_ item: ShoppingListItem, listID: String) -> NativeSharePayload {
        let serializedValue = privateTransferValue(
            domain: .shoppingItem,
            resourceID: item.id,
            title: item.name,
            fields: [
                ("listID", listID),
                ("quantity", item.displayQuantity),
                ("checked", item.checked ? "true" : "false"),
                ("updatedAt", item.updatedAt)
            ]
        )

        return NativeSharePayload(
            domain: .shoppingItem,
            resourceID: item.id,
            kind: .privateTransfer,
            publicURL: nil,
            route: nil,
            title: item.name,
            subtitle: item.displayQuantity.isEmpty ? "Shopping list item" : item.displayQuantity,
            nativeTransfer: .privateTransfer(serializedValue),
            serializedTransferValue: serializedValue
        )
    }

    public static func privateSpoon(_ spoon: RecipeDetailRecentSpoon, recipeTitle: String) -> NativeSharePayload {
        let serializedValue = privateTransferValue(
            domain: .spoon,
            resourceID: spoon.id,
            title: recipeTitle,
            fields: [
                ("recipeID", spoon.recipeID),
                ("chefID", spoon.chefID),
                ("cookedAt", spoon.cookedAt),
                ("note", spoon.note),
                ("nextTime", spoon.nextTime),
                ("updatedAt", spoon.updatedAt)
            ]
        )

        return NativeSharePayload(
            domain: .spoon,
            resourceID: spoon.id,
            kind: .privateTransfer,
            publicURL: nil,
            route: nil,
            title: recipeTitle,
            subtitle: spoon.note ?? spoon.cookedAt ?? "Cook log",
            nativeTransfer: .privateTransfer(serializedValue),
            serializedTransferValue: serializedValue
        )
    }

    public static func privateCaptureDraft(_ draft: CaptureDraft) -> NativeSharePayload {
        let title = draft.previewLines.first ?? "Capture Draft"
        let serializedValue = privateTransferValue(
            domain: .captureDraft,
            resourceID: draft.id,
            title: title,
            fields: [
                ("source", draft.source.rawValue),
                ("sourceURL", draft.sourceURL?.absoluteString),
                ("capturedURL", draft.capturedURL?.absoluteString),
                ("createdAt", draft.createdAt)
            ]
        )

        return NativeSharePayload(
            domain: .captureDraft,
            resourceID: draft.id,
            kind: .privateTransfer,
            publicURL: nil,
            route: nil,
            title: title,
            subtitle: draft.source.rawValue,
            nativeTransfer: .privateTransfer(serializedValue),
            serializedTransferValue: serializedValue
        )
    }

    private init(
        domain: NativeShareDomain,
        resourceID: String,
        kind: NativeSharePayloadKind,
        publicURL: URL?,
        route: AppRoute?,
        title: String,
        subtitle: String,
        nativeTransfer: NativeShareTransfer?,
        serializedTransferValue: String
    ) {
        id = "\(domain.rawValue):\(resourceID)"
        self.domain = domain
        self.kind = kind
        self.publicURL = publicURL
        self.route = route
        self.title = title
        self.subtitle = subtitle
        self.nativeTransfer = nativeTransfer
        self.serializedTransferValue = serializedTransferValue
    }

    private static func publicObjectPayload(
        domain: NativeShareDomain,
        resourceID: String,
        title: String,
        subtitle: String,
        publicURL: URL,
        route: AppRoute
    ) throws -> NativeSharePayload {
        guard NativePublicShareRoutePolicy.validatedPublicObjectURL(publicURL, for: route) else {
            throw NativeSharePayloadError.invalidPublicURL(domain: domain, url: publicURL)
        }

        return NativeSharePayload(
            domain: domain,
            resourceID: resourceID,
            kind: .publicURL,
            publicURL: publicURL,
            route: route,
            title: title,
            subtitle: subtitle,
            nativeTransfer: .publicURL(publicURL),
            serializedTransferValue: publicURL.absoluteString
        )
    }

    private static func privateTransferValue(
        domain: NativeShareDomain,
        resourceID: String,
        title: String,
        fields: [(String, String?)]
    ) -> String {
        let baseFields: [(String, String?)] = [
            ("schema", "app.spoonjoy.native-share.v1"),
            ("domain", domain.rawValue),
            ("id", resourceID),
            ("title", title)
        ]
        return (baseFields + fields)
            .compactMap { key, value -> String? in
                guard let value, !value.isEmpty else {
                    return nil
                }
                return "\(key)=\(escaped(value))"
            }
            .joined(separator: ";")
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

public enum NativePublicShareRoutePolicy {
    public static let publicHost = "spoonjoy.app"

    public static func publicURL(for route: AppRoute) -> URL? {
        switch route {
        case .recipeDetail(let id, .detail):
            return objectURL(kind: "recipes", id: id)
        case .cookbookDetail(let id):
            return objectURL(kind: "cookbooks", id: id)
        case .recipeDetail(_, .cook),
             .kitchen,
             .recipes,
             .recipeEditor,
             .recipeCoverControls,
             .cookbooks,
             .shoppingList,
             .search,
             .capture,
             .settings,
             .unknownLink:
            return nil
        }
    }

    public static func validatedPublicObjectURL(_ url: URL, for route: AppRoute) -> Bool {
        guard let expectedURL = publicURL(for: route),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == publicHost,
              components.queryItems == nil,
              components.percentEncodedFragment == nil else {
            return false
        }

        return url == expectedURL
    }

    private static func objectURL(kind: String, id: String) -> URL? {
        guard isSafeObjectID(id) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = publicHost
        components.path = "/\(kind)/\(id)"
        return components.url
    }

    private static func isSafeObjectID(_ id: String) -> Bool {
        guard id.trimmingCharacters(in: .whitespacesAndNewlines) == id, !id.isEmpty else {
            return false
        }
        guard !id.contains("/"), !id.contains("\\"), !id.contains(".."), id != ".", id != ".." else {
            return false
        }
        return id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }
}

public struct NativeShareSurfaceCatalog: Equatable, Sendable {
    public let publicURLDomains: [NativeShareDomain]
    public let publicURLRouteTemplates: [String]
    public let privateTransferDomains: [NativeShareDomain]
    public let systemDestinations: [NativeShareDestination]
    public let productDestinations: [NativeShareDestination]
    public let allSurfaceIdentifiers: [String]

    public static let spoonjoy = NativeShareSurfaceCatalog(
        publicURLDomains: [.recipe, .cookbook],
        publicURLRouteTemplates: [
            "https://spoonjoy.app/recipes/{id}",
            "https://spoonjoy.app/cookbooks/{id}"
        ],
        privateTransferDomains: [.shoppingList, .shoppingItem, .spoon, .captureDraft],
        systemDestinations: [.shareSheet],
        productDestinations: [],
        allSurfaceIdentifiers: [
            "share-sheet",
            "share-recipe",
            "share-cookbook",
            "native-shopping-list-transfer",
            "native-shopping-item-transfer",
            "native-spoon-transfer",
            "native-capture-draft-transfer"
        ]
    )
}
