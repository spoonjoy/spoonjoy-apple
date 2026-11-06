import Foundation
import SpoonjoyCore

/// A kitchen a headless journey writes for itself: recipes, cookbooks and shopping items in the same three files the
/// fixture kitchen ships (`native-app-state.json`, `native-durable-cache.json`, `native-sync-store.json`), so the live
/// store restores it from cache exactly as the app does with SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1.
///
/// A live journey makes the same kitchen on the QA server first (JourneyQAClient); here it is written straight to disk.
public struct SpoonjoyJourneyKitchen {
    public struct Chef: Equatable, Sendable {
        public let id: String
        public let username: String

        public init(id: String, username: String) {
            self.id = id
            self.username = username
        }

        /// The fixture kitchen's own chef: the signed-in account.
        public static let me = Chef(id: SpoonjoyFixtureKitchen.accountID, username: "kitchen")
    }

    public struct Ingredient: Equatable, Sendable {
        public let id: String
        public let name: String
        public let quantity: Double
        public let unit: String?

        public init(_ id: String, _ name: String, _ quantity: Double, _ unit: String? = nil) {
            self.id = id
            self.name = name
            self.quantity = quantity
            self.unit = unit
        }
    }

    public struct Step: Equatable, Sendable {
        public let id: String
        public let title: String?
        public let description: String
        public let duration: Int?
        public let ingredients: [Ingredient]

        public init(_ id: String, title: String? = nil, _ description: String, minutes duration: Int? = nil, ingredients: [Ingredient] = []) {
            self.id = id
            self.title = title
            self.description = description
            self.duration = duration
            self.ingredients = ingredients
        }
    }

    public struct RecipeSpec: Equatable, Sendable {
        public let id: String
        public let title: String
        public let description: String
        public let servings: String?
        public let chef: Chef
        public let steps: [Step]

        public init(_ id: String, _ title: String, description: String = "", servings: String? = "4", chef: Chef = .me, steps: [Step]) {
            self.id = id
            self.title = title
            self.description = description.isEmpty ? "\(title) for the journey." : description
            self.servings = servings
            self.chef = chef
            self.steps = steps
        }
    }

    public struct CookbookSpec: Equatable, Sendable {
        public let id: String
        public let title: String
        public let chef: Chef
        public let recipeIDs: [String]

        public init(_ id: String, _ title: String, chef: Chef = .me, recipeIDs: [String]) {
            self.id = id
            self.title = title
            self.chef = chef
            self.recipeIDs = recipeIDs
        }
    }

    public var accountID = SpoonjoyFixtureKitchen.accountID
    public var recipes: [RecipeSpec]
    public var cookbooks: [CookbookSpec]
    /// Saved cook progress, keyed by recipe id, as the app state keeps it.
    public var cookProgress: [String: CookModeProgress]

    public init(recipes: [RecipeSpec] = [], cookbooks: [CookbookSpec] = [], cookProgress: [String: CookModeProgress] = [:]) {
        self.recipes = recipes
        self.cookbooks = cookbooks
        self.cookProgress = cookProgress
    }

    /// The day every journey kitchen was fetched, so a kitchen written twice is the same bytes.
    public static let fetchedAt = Date(timeIntervalSinceReferenceDate: 803_304_540)
    static let stamp = "2026-06-01T00:00:00.000Z"

    /// The recipes as the app decodes them.
    public func recipeValues() throws -> [Recipe] {
        try recipes.map { try JSONDecoder().decode(Recipe.self, from: JSONSerialization.data(withJSONObject: recipeJSON($0))) }
    }

    public func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeAppState(to: directory.appendingPathComponent("native-app-state.json"))
        try writeCache(to: directory.appendingPathComponent("native-durable-cache.json"))
        try writeSyncStore(to: directory.appendingPathComponent("native-sync-store.json"))
    }

    // MARK: Files

    private func writeAppState(to url: URL) throws {
        let encoder = JSONEncoder()
        var progress: [String: Any] = [:]
        for (id, value) in cookProgress {
            progress[id] = try JSONSerialization.jsonObject(with: encoder.encode(value))
        }
        let state: [String: Any] = [
            "schemaVersion": 1,
            "accountID": accountID,
            "environment": "production",
            "hasCompletedFirstRun": true,
            "cookProgressByRecipeID": progress,
            "spoonCookLogDraftsByRecipeID": [String: Any](),
            "shoppingList": NSNull(),
            "captureDraft": NSNull(),
            "pendingCaptureImport": NSNull(),
            "captureImportProviderBlocker": NSNull(),
            "pendingMutations": ["mutations": [Any]()],
            "lastOpenedRoute": "kitchen",
            "savedAt": "2026-06-16T12:09:00.000Z",
        ]
        try Self.writeJSON(state, to: url)
    }

    private func writeCache(to url: URL) throws {
        func record(_ id: String, _ domain: NativeCacheDomain, _ endpoint: String, _ payload: NativeCachePayload) throws -> NativeCacheRecord {
            try NativeCacheRecord(id: id, metadata: NativeCacheRecordMetadata(
                accountID: accountID,
                environment: .production,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: domain,
                fetchedAt: Self.fetchedAt,
                lastValidatedAt: Self.fetchedAt,
                sourceEndpoint: endpoint,
                serverRevision: .cursor("journey-kitchen")
            ), payload: payload)
        }
        var records = [try record("recipe-catalog", .recipeCatalog, "/api/v1/recipes", .recipeCatalog(recipeIDs: recipes.map(\.id)))]
        for recipe in recipes {
            records.append(try record("recipe-detail:\(recipe.id)", .recipeDetail(id: recipe.id), "/api/v1/recipes/\(recipe.id)", .recipeDetail(id: recipe.id, title: recipe.title)))
        }
        records.append(try record("cookbook-list", .cookbookList, "/api/v1/cookbooks", .cookbookList(cookbookIDs: cookbooks.map(\.id))))
        for cookbook in cookbooks {
            records.append(try record("cookbook-detail:\(cookbook.id)", .cookbookDetail(id: cookbook.id), "/api/v1/cookbooks/\(cookbook.id)", .cookbookDetail(id: cookbook.id, title: cookbook.title)))
        }
        let snapshot = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: accountID,
            environment: .production,
            createdAt: Self.fetchedAt,
            records: records,
            dismissedIndicators: []
        )
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    private func writeSyncStore(to url: URL) throws {
        var cached: [[String: Any]] = recipes.map { ["kind": "recipe", "resourceID": $0.id, "payload": recipeJSON($0), "serverRevision": NSNull()] }
        cached += cookbooks.map { ["kind": "cookbook", "resourceID": $0.id, "payload": cookbookJSON($0), "serverRevision": NSNull()] }
        let store: [String: Any] = [
            "accountID": accountID,
            "environment": "production",
            "checkpoint": NSNull(),
            "queue": ["mutations": [Any]()],
            "cachedRecords": cached,
            "tombstones": [Any](),
        ]
        try Self.writeJSON(store, to: url)
    }

    // MARK: Payloads, as the API sends them

    private static func chefJSON(_ chef: Chef) -> [String: Any] {
        ["id": chef.id, "username": chef.username]
    }

    private func summaryJSON(_ recipe: RecipeSpec) -> [String: Any] {
        let url = "https://spoonjoy.app/recipes/\(recipe.id)"
        return [
            "id": recipe.id,
            "title": recipe.title,
            "description": recipe.description,
            "servings": recipe.servings as Any? ?? NSNull(),
            "chef": Self.chefJSON(recipe.chef),
            "coverImageUrl": NSNull(),
            "coverProvenanceLabel": NSNull(),
            "coverSourceType": NSNull(),
            "coverVariant": NSNull(),
            "href": "/recipes/\(recipe.id)",
            "canonicalUrl": url,
            "attribution": ["creditText": "\(recipe.title) by \(recipe.chef.username) on Spoonjoy", "canonicalUrl": url, "sourceUrl": NSNull(), "sourceHost": NSNull(), "sourceRecipe": NSNull()],
            "createdAt": Self.stamp,
            "updatedAt": Self.stamp,
        ]
    }

    private func recipeJSON(_ recipe: RecipeSpec) -> [String: Any] {
        var json = summaryJSON(recipe)
        json["steps"] = recipe.steps.enumerated().map { index, step -> [String: Any] in
            [
                "id": step.id,
                "stepNum": index + 1,
                "stepTitle": step.title as Any? ?? NSNull(),
                "description": step.description,
                "duration": step.duration as Any? ?? NSNull(),
                "ingredients": step.ingredients.map { ["id": $0.id, "name": $0.name, "quantity": $0.quantity, "unit": $0.unit as Any? ?? NSNull()] },
            ]
        }
        json["cookbooks"] = cookbooks.filter { $0.recipeIDs.contains(recipe.id) }.map {
            ["id": $0.id, "title": $0.title, "href": "/cookbooks/\($0.id)", "canonicalUrl": "https://spoonjoy.app/cookbooks/\($0.id)"]
        }
        json["recentSpoons"] = [Any]()
        return json
    }

    private func cookbookJSON(_ cookbook: CookbookSpec) -> [String: Any] {
        let url = "https://spoonjoy.app/cookbooks/\(cookbook.id)"
        let members = cookbook.recipeIDs.compactMap { id in recipes.first { $0.id == id } }
        return [
            "id": cookbook.id,
            "title": cookbook.title,
            "chef": Self.chefJSON(cookbook.chef),
            "recipeCount": members.count,
            "coverImageUrls": [Any](),
            "href": "/cookbooks/\(cookbook.id)",
            "canonicalUrl": url,
            "attribution": ["creditText": "\(cookbook.title) by \(cookbook.chef.username) on Spoonjoy", "canonicalUrl": url],
            "createdAt": Self.stamp,
            "updatedAt": Self.stamp,
            "recipes": members.map(summaryJSON),
        ]
    }

    private static func writeJSON(_ object: Any, to url: URL) throws {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    }
}
