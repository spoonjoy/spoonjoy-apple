import Foundation

public struct ChefSummary: Codable, Equatable, Sendable {
    public let id: String
    public let username: String
    public let photoURL: URL?

    public init(id: String, username: String, photoURL: URL? = nil) {
        self.id = id
        self.username = username
        self.photoURL = photoURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case photoURL = "photoUrl"
    }
}

public enum RecipeCoverSourceType: String, Equatable, Sendable {
    case chefUpload = "chef-upload"
    case editorializedChefPhoto = "editorialized-chef-photo"
    case imported = "import"
    case aiGenerated = "ai-generated"
    case aiPlaceholder = "ai-placeholder"
    case spoon
}

extension RecipeCoverSourceType: Codable {
    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case "chef-upload":
            self = .chefUpload
        case "editorialized-chef-photo":
            self = .editorializedChefPhoto
        case "import", "imported":
            self = .imported
        case "ai-generated":
            self = .aiGenerated
        case "ai-placeholder":
            self = .aiPlaceholder
        case "spoon":
            self = .spoon
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown recipe cover source type: \(rawValue)")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum RecipeCoverVariant: String, Codable, Equatable, Sendable {
    case image
    case illustration
    case stylized
}

public struct SourceRecipeAttribution: Codable, Equatable, Sendable {
    public let id: String
    public let title: String?
    public let chef: ChefSummary?
    public let href: String?
    public let canonicalURL: URL?
    public let deleted: Bool

    public var safeCanonicalURL: URL? {
        deleted ? nil : canonicalURL?.safeHTTPURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case chef
        case href
        case canonicalURL = "canonicalUrl"
        case deleted
    }
}

public struct RecipeAttribution: Codable, Equatable, Sendable {
    public let creditText: String
    public let canonicalURL: URL
    public let sourceURLRaw: String?
    public let sourceHost: String?
    public let sourceRecipe: SourceRecipeAttribution?

    public var sourceURL: URL? {
        guard let sourceURLRaw else {
            return nil
        }

        return URL(string: sourceURLRaw.trimmingCharacters(in: .whitespacesAndNewlines))?.safeHTTPURL
    }

    public var hasUnsafeSourceURL: Bool {
        sourceURLRaw != nil && sourceURL == nil
    }

    private enum CodingKeys: String, CodingKey {
        case creditText
        case canonicalURL = "canonicalUrl"
        case sourceURLRaw = "sourceUrl"
        case sourceHost
        case sourceRecipe
    }
}

public struct RecipeIngredient: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let quantity: Double
    public let unit: String?

    public init(id: String, name: String, quantity: Double, unit: String?) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
}

public struct RecipeStep: Codable, Equatable, Sendable {
    public let id: String
    public let stepNum: Int
    public let stepTitle: String?
    public let description: String
    public let duration: Int?
    public let ingredients: [RecipeIngredient]
    public let usingSteps: [RecipeStepOutputUse]

    public init(
        id: String,
        stepNum: Int,
        stepTitle: String?,
        description: String,
        duration: Int?,
        ingredients: [RecipeIngredient],
        usingSteps: [RecipeStepOutputUse] = []
    ) {
        self.id = id
        self.stepNum = stepNum
        self.stepTitle = stepTitle
        self.description = description
        self.duration = duration
        self.ingredients = ingredients
        self.usingSteps = usingSteps
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case stepNum
        case stepTitle
        case description
        case duration
        case ingredients
        case usingSteps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        stepNum = try container.decode(Int.self, forKey: .stepNum)
        stepTitle = try container.decodeIfPresent(String.self, forKey: .stepTitle)
        description = try container.decode(String.self, forKey: .description)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        ingredients = try container.decode([RecipeIngredient].self, forKey: .ingredients)
        usingSteps = try container.decodeIfPresent([RecipeStepOutputUse].self, forKey: .usingSteps) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(stepNum, forKey: .stepNum)
        try container.encodeIfPresent(stepTitle, forKey: .stepTitle)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(usingSteps, forKey: .usingSteps)
    }
}

public struct RecipeStepOutputReference: Codable, Equatable, Sendable {
    public let stepNum: Int
    public let stepTitle: String?

    public init(stepNum: Int, stepTitle: String?) {
        self.stepNum = stepNum
        self.stepTitle = stepTitle
    }
}

public struct RecipeStepOutputUse: Codable, Equatable, Sendable {
    public let id: String
    public let inputStepNum: Int
    public let outputStepNum: Int
    public let outputOfStep: RecipeStepOutputReference

    public init(
        id: String,
        inputStepNum: Int,
        outputStepNum: Int,
        outputOfStep: RecipeStepOutputReference
    ) {
        self.id = id
        self.inputStepNum = inputStepNum
        self.outputStepNum = outputStepNum
        self.outputOfStep = outputOfStep
    }
}

public struct CookbookLink: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let href: String
    public let canonicalURL: URL

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case href
        case canonicalURL = "canonicalUrl"
    }
}

public struct RecipeSummary: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String?
    public let servings: String?
    public let chef: ChefSummary
    public let coverImageURL: URL?
    public let coverProvenanceLabel: String?
    public let coverSourceType: RecipeCoverSourceType?
    public let coverVariant: RecipeCoverVariant?
    public let href: String
    public let canonicalURL: URL
    public let attribution: RecipeAttribution
    public let createdAt: String
    public let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case servings
        case chef
        case coverImageURL = "coverImageUrl"
        case coverProvenanceLabel
        case coverSourceType
        case coverVariant
        case href
        case canonicalURL = "canonicalUrl"
        case attribution
        case createdAt
        case updatedAt
    }

    public init(recipe: Recipe) {
        id = recipe.id
        title = recipe.title
        description = recipe.description
        servings = recipe.servings
        chef = recipe.chef
        coverImageURL = recipe.coverImageURL
        coverProvenanceLabel = recipe.coverProvenanceLabel
        coverSourceType = recipe.coverSourceType
        coverVariant = recipe.coverVariant
        href = recipe.href
        canonicalURL = recipe.canonicalURL
        attribution = recipe.attribution
        createdAt = recipe.createdAt
        updatedAt = recipe.updatedAt
    }

    public var displayCoverImageURL: URL? {
        coverSourceType == .aiPlaceholder ? nil : coverImageURL
    }

    public var displayCoverProvenanceLabel: String? {
        displayCoverImageURL == nil ? nil : coverProvenanceLabel
    }
}

public struct Recipe: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String?
    public let servings: String?
    public let chef: ChefSummary
    public let coverImageURL: URL?
    public let coverProvenanceLabel: String?
    public let coverSourceType: RecipeCoverSourceType?
    public let coverVariant: RecipeCoverVariant?
    public let href: String
    public let canonicalURL: URL
    public let attribution: RecipeAttribution
    public let createdAt: String
    public let updatedAt: String
    public let steps: [RecipeStep]
    public let cookbooks: [CookbookLink]
    public let recentSpoons: [RecipeDetailRecentSpoon]

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case servings
        case chef
        case coverImageURL = "coverImageUrl"
        case coverProvenanceLabel
        case coverSourceType
        case coverVariant
        case href
        case canonicalURL = "canonicalUrl"
        case attribution
        case createdAt
        case updatedAt
        case steps
        case cookbooks
        case recentSpoons
    }

    public init(
        id: String,
        title: String,
        description: String?,
        servings: String?,
        chef: ChefSummary,
        coverImageURL: URL?,
        coverProvenanceLabel: String?,
        coverSourceType: RecipeCoverSourceType?,
        coverVariant: RecipeCoverVariant?,
        href: String,
        canonicalURL: URL,
        attribution: RecipeAttribution,
        createdAt: String,
        updatedAt: String,
        steps: [RecipeStep],
        cookbooks: [CookbookLink],
        recentSpoons: [RecipeDetailRecentSpoon] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.servings = servings
        self.chef = chef
        self.coverImageURL = coverImageURL
        self.coverProvenanceLabel = coverProvenanceLabel
        self.coverSourceType = coverSourceType
        self.coverVariant = coverVariant
        self.href = href
        self.canonicalURL = canonicalURL
        self.attribution = attribution
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.steps = steps
        self.cookbooks = cookbooks
        self.recentSpoons = recentSpoons
    }

    public var displayCoverImageURL: URL? {
        coverSourceType == .aiPlaceholder ? nil : coverImageURL
    }

    public var displayCoverProvenanceLabel: String? {
        displayCoverImageURL == nil ? nil : coverProvenanceLabel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        servings = try container.decodeIfPresent(String.self, forKey: .servings)
        chef = try container.decode(ChefSummary.self, forKey: .chef)
        coverImageURL = try container.decodeIfPresent(URL.self, forKey: .coverImageURL)
        coverProvenanceLabel = try container.decodeIfPresent(String.self, forKey: .coverProvenanceLabel)
        coverSourceType = try container.decodeIfPresent(RecipeCoverSourceType.self, forKey: .coverSourceType)
        coverVariant = try container.decodeIfPresent(RecipeCoverVariant.self, forKey: .coverVariant)
        href = try container.decode(String.self, forKey: .href)
        canonicalURL = try container.decode(URL.self, forKey: .canonicalURL)
        attribution = try container.decode(RecipeAttribution.self, forKey: .attribution)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        steps = try container.decode([RecipeStep].self, forKey: .steps)
        cookbooks = try container.decode([CookbookLink].self, forKey: .cookbooks)
        recentSpoons = try container.decodeIfPresent([RecipeDetailRecentSpoon].self, forKey: .recentSpoons) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(servings, forKey: .servings)
        try container.encode(chef, forKey: .chef)
        try container.encodeIfPresent(coverImageURL, forKey: .coverImageURL)
        try container.encodeIfPresent(coverProvenanceLabel, forKey: .coverProvenanceLabel)
        try container.encodeIfPresent(coverSourceType, forKey: .coverSourceType)
        try container.encodeIfPresent(coverVariant, forKey: .coverVariant)
        try container.encode(href, forKey: .href)
        try container.encode(canonicalURL, forKey: .canonicalURL)
        try container.encode(attribution, forKey: .attribution)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(steps, forKey: .steps)
        try container.encode(cookbooks, forKey: .cookbooks)
        try container.encode(recentSpoons, forKey: .recentSpoons)
    }
}

public struct RecipeDetailRecentSpoon: Codable, Equatable, Sendable {
    public let id: String
    public let chefID: String
    public let recipeID: String
    public let cookedAt: String?
    public let photoURL: URL?
    public let note: String?
    public let nextTime: String?
    public let deletedAt: String?
    public let createdAt: String
    public let updatedAt: String
    public let chef: ChefSummary

    public init(
        id: String,
        chefID: String,
        recipeID: String,
        cookedAt: String?,
        photoURL: URL?,
        note: String?,
        nextTime: String?,
        deletedAt: String?,
        createdAt: String,
        updatedAt: String,
        chef: ChefSummary
    ) {
        self.id = id
        self.chefID = chefID
        self.recipeID = recipeID
        self.cookedAt = cookedAt
        self.photoURL = photoURL
        self.note = note
        self.nextTime = nextTime
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.chef = chef
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case chefID = "chefId"
        case recipeID = "recipeId"
        case cookedAt
        case photoURL = "photoUrl"
        case note
        case nextTime
        case deletedAt
        case createdAt
        case updatedAt
        case chef
    }
}

public enum CookbookCoverPresentation: String, Equatable, Sendable {
    case collage
    case textOnly
}

public struct CookbookCover: Equatable, Sendable {
    public let imageURLs: [URL?]

    public init(imageURLs: [URL?]) {
        self.imageURLs = imageURLs
    }

    public var primaryImageURL: URL? {
        imageURLs.compactMap { $0 }.first
    }

    public var presentation: CookbookCoverPresentation {
        primaryImageURL == nil ? .textOnly : .collage
    }
}

public struct CookbookAttribution: Codable, Equatable, Sendable {
    public let creditText: String
    public let canonicalURL: URL

    private enum CodingKeys: String, CodingKey {
        case creditText
        case canonicalURL = "canonicalUrl"
    }
}

public struct CookbookSummary: Equatable, Sendable {
    public let id: String
    public let title: String
    public let chef: ChefSummary
    public let recipeCount: Int
    public let cover: CookbookCover
    public let href: String
    public let canonicalURL: URL
    public let attribution: CookbookAttribution
    public let createdAt: String
    public let updatedAt: String
}

extension CookbookSummary: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case chef
        case recipeCount
        case coverImageURLs = "coverImageUrls"
        case href
        case canonicalURL = "canonicalUrl"
        case attribution
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        chef = try container.decode(ChefSummary.self, forKey: .chef)
        recipeCount = try container.decode(Int.self, forKey: .recipeCount)
        cover = CookbookCover(imageURLs: try container.decode([URL?].self, forKey: .coverImageURLs))
        href = try container.decode(String.self, forKey: .href)
        canonicalURL = try container.decode(URL.self, forKey: .canonicalURL)
        attribution = try container.decode(CookbookAttribution.self, forKey: .attribution)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(chef, forKey: .chef)
        try container.encode(recipeCount, forKey: .recipeCount)
        try container.encode(cover.imageURLs, forKey: .coverImageURLs)
        try container.encode(href, forKey: .href)
        try container.encode(canonicalURL, forKey: .canonicalURL)
        try container.encode(attribution, forKey: .attribution)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

public struct Cookbook: Equatable, Sendable {
    public let id: String
    public let title: String
    public let chef: ChefSummary
    public let recipeCount: Int
    public let cover: CookbookCover
    public let href: String
    public let canonicalURL: URL
    public let attribution: CookbookAttribution
    public let createdAt: String
    public let updatedAt: String
    public let recipes: [RecipeSummary]
}

extension Cookbook: Codable {
    private enum CodingKeys: String, CodingKey {
        case recipes
    }

    public init(from decoder: Decoder) throws {
        let summary = try CookbookSummary(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = summary.id
        title = summary.title
        chef = summary.chef
        recipeCount = summary.recipeCount
        cover = summary.cover
        href = summary.href
        canonicalURL = summary.canonicalURL
        attribution = summary.attribution
        createdAt = summary.createdAt
        updatedAt = summary.updatedAt
        recipes = try container.contains(.recipes)
            ? container.decode([RecipeSummary].self, forKey: .recipes)
            : []
    }

    public func encode(to encoder: Encoder) throws {
        try CookbookSummary(cookbook: self).encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(recipes, forKey: .recipes)
    }
}

extension CookbookSummary {
    public init(cookbook: Cookbook) {
        id = cookbook.id
        title = cookbook.title
        chef = cookbook.chef
        recipeCount = cookbook.recipeCount
        cover = cookbook.cover
        href = cookbook.href
        canonicalURL = cookbook.canonicalURL
        attribution = cookbook.attribution
        createdAt = cookbook.createdAt
        updatedAt = cookbook.updatedAt
    }
}

public enum RecipeCookbookValidationError: Error, Equatable, CustomStringConvertible {
    case emptyRecipeTitle(id: String)
    case recipeWithoutSteps(id: String)
    case emptyStepDescription(recipeID: String, stepID: String)
    case duplicateStepNumber(recipeID: String, stepNum: Int)
    case negativeIngredientQuantity(recipeID: String, ingredientID: String)
    case emptyCookbookTitle(id: String)
    case cookbookRecipeCountMismatch(id: String, declared: Int, actual: Int)

    public var description: String {
        switch self {
        case .emptyRecipeTitle(let id):
            "Recipe \(id) must have a non-empty title."
        case .recipeWithoutSteps(let id):
            "Recipe \(id) must include at least one step."
        case .emptyStepDescription(let recipeID, let stepID):
            "Recipe \(recipeID) step \(stepID) must have a non-empty description."
        case .duplicateStepNumber(let recipeID, let stepNum):
            "Recipe \(recipeID) must not repeat step number \(stepNum)."
        case .negativeIngredientQuantity(let recipeID, let ingredientID):
            "Recipe \(recipeID) ingredient \(ingredientID) must not have a negative quantity."
        case .emptyCookbookTitle(let id):
            "Cookbook \(id) must have a non-empty title."
        case .cookbookRecipeCountMismatch(let id, let declared, let actual):
            "Cookbook \(id) declares \(declared) recipes but contains \(actual)."
        }
    }
}

public struct RecipeFixtureCatalog: Codable, Equatable {
    public let recipes: [Recipe]

    public static func decodeFromBundle() throws -> RecipeFixtureCatalog {
        try decode(data: SpoonjoyFixture.data(named: "recipes-fixture"))
    }

    public static func decode(data: Data) throws -> RecipeFixtureCatalog {
        let catalog = try JSONDecoder().decode(RecipeFixtureCatalog.self, from: data)
        try catalog.validate()
        return catalog
    }

    public func recipe(id: String) -> Recipe? {
        recipes.first { $0.id == id }
    }

    private func validate() throws {
        for recipe in recipes {
            try validate(recipe: recipe)
        }
    }

    private func validate(recipe: Recipe) throws {
        guard !recipe.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeCookbookValidationError.emptyRecipeTitle(id: recipe.id)
        }

        guard !recipe.steps.isEmpty else {
            throw RecipeCookbookValidationError.recipeWithoutSteps(id: recipe.id)
        }

        var stepNumbers = Set<Int>()

        for step in recipe.steps {
            guard stepNumbers.insert(step.stepNum).inserted else {
                throw RecipeCookbookValidationError.duplicateStepNumber(
                    recipeID: recipe.id,
                    stepNum: step.stepNum
                )
            }

            guard !step.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecipeCookbookValidationError.emptyStepDescription(
                    recipeID: recipe.id,
                    stepID: step.id
                )
            }

            for ingredient in step.ingredients where ingredient.quantity < 0 {
                throw RecipeCookbookValidationError.negativeIngredientQuantity(
                    recipeID: recipe.id,
                    ingredientID: ingredient.id
                )
            }
        }
    }
}

public struct CookbookFixtureCatalog: Codable, Equatable {
    public let cookbooks: [Cookbook]

    public static func decodeFromBundle() throws -> CookbookFixtureCatalog {
        try decode(data: SpoonjoyFixture.data(named: "cookbooks-fixture"))
    }

    public static func decode(data: Data) throws -> CookbookFixtureCatalog {
        let catalog = try JSONDecoder().decode(CookbookFixtureCatalog.self, from: data)
        try catalog.validate()
        return catalog
    }

    public func cookbook(id: String) -> Cookbook? {
        cookbooks.first { $0.id == id }
    }

    private func validate() throws {
        for cookbook in cookbooks {
            guard !cookbook.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecipeCookbookValidationError.emptyCookbookTitle(id: cookbook.id)
            }

            guard cookbook.recipeCount == cookbook.recipes.count else {
                throw RecipeCookbookValidationError.cookbookRecipeCountMismatch(
                    id: cookbook.id,
                    declared: cookbook.recipeCount,
                    actual: cookbook.recipes.count
                )
            }
        }
    }
}

public enum PublicSearchSummaryKind: String, Equatable {
    case recipe
    case cookbook
}

public struct RecipeSearchSummary: Equatable {
    public let id: String
    public let kind: PublicSearchSummaryKind
    public let title: String
    public let subtitle: String
    public let href: String
    public let canonicalURL: URL
    public let imageURL: URL?
    public let accessibilityLabel: String

    public init(recipe: Recipe) {
        id = recipe.id
        kind = .recipe
        title = recipe.title
        subtitle = Self.subtitle(chef: recipe.chef.username, servings: recipe.servings)
        href = recipe.href
        canonicalURL = recipe.canonicalURL
        imageURL = recipe.coverImageURL
        accessibilityLabel = "Recipe, \(recipe.title) by \(recipe.chef.username)"
    }

    private static func subtitle(chef: String, servings: String?) -> String {
        guard let servings = servings?.trimmingCharacters(in: .whitespacesAndNewlines), !servings.isEmpty else {
            return chef
        }

        return "\(chef) - \(servings)"
    }
}

public struct CookbookSearchSummary: Equatable {
    public let id: String
    public let kind: PublicSearchSummaryKind
    public let title: String
    public let subtitle: String
    public let href: String
    public let canonicalURL: URL
    public let imageURL: URL?
    public let accessibilityLabel: String

    public init(cookbook: Cookbook) {
        self.init(cookbook: CookbookSummary(cookbook: cookbook))
    }

    public init(cookbook: CookbookSummary) {
        id = cookbook.id
        kind = .cookbook
        title = cookbook.title
        subtitle = "\(cookbook.chef.username) - \(cookbook.recipeCount) \(Self.recipeCountLabel(cookbook.recipeCount))"
        href = cookbook.href
        canonicalURL = cookbook.canonicalURL
        imageURL = cookbook.cover.primaryImageURL
        accessibilityLabel = "Cookbook, \(cookbook.title) by \(cookbook.chef.username), \(cookbook.recipeCount) \(Self.recipeCountLabel(cookbook.recipeCount))"
    }

    private static func recipeCountLabel(_ recipeCount: Int) -> String {
        recipeCount == 1 ? "recipe" : "recipes"
    }
}

private extension URL {
    var safeHTTPURL: URL? {
        guard let scheme = scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              host != nil else {
            return nil
        }

        return self
    }
}
