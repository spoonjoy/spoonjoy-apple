import Foundation

public struct APIDiscoveryResponse: Decodable, Equatable {
    public let app: String
    public let version: String
    public let status: String
    public let docsURL: URL
    public let openAPIPath: String
    public let sdkOpenAPIPath: String
    public let connectorOpenAPIPath: String

    private enum CodingKeys: String, CodingKey {
        case app
        case version
        case status
        case docsURL = "docsUrl"
        case openAPIPath = "openapiUrl"
        case sdkOpenAPIPath = "sdkOpenapiUrl"
        case connectorOpenAPIPath = "connectorOpenapiUrl"
    }
}

public enum APIDiscoveryRequests {
    public static func root() -> APIRequestBuilder {
        anonymousGET(["api", "v1"])
    }

    public static func health() -> APIRequestBuilder {
        anonymousGET(["api", "v1", "health"])
    }

    public static func openAPI() -> APIRequestBuilder {
        anonymousGET(["api", "v1", "openapi.json"])
    }

    public static func sdkOpenAPI() -> APIRequestBuilder {
        anonymousGET(["api", "v1", "openapi.sdk.json"])
    }

    public static func connectorOpenAPI() -> APIRequestBuilder {
        anonymousGET(["api", "v1", "openapi.connector.json"])
    }

    public static func docsHandoffURL(baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIRequestBuildError.invalidBaseURL
        }
        components.path = "/api"
        components.query = nil
        components.fragment = nil
        return components.url!
    }

    private static func anonymousGET(_ pathComponents: [String]) -> APIRequestBuilder {
        APIRequestBuilder(
            method: .get,
            pathComponents: pathComponents,
            queryItems: []
        )
    }
}

public enum APIRequestBuildError: Error, Equatable {
    case invalidBaseURL
    case invalidMultipartHeaderValue(String)
}

public enum PrivateAccountRequests {
    public static func currentAccount() -> APIRequestBuilder {
        APIRequestSupport.privateRead(pathComponents: ["api", "v1", "me"])
    }

    public static func kitchen() -> APIRequestBuilder {
        APIRequestSupport.privateRead(pathComponents: ["api", "v1", "me", "kitchen"])
    }

    public static func notificationPreferences() -> APIRequestBuilder {
        APIRequestSupport.privateRead(pathComponents: ["api", "v1", "me", "notification-preferences"])
    }

    public static func connections() -> APIRequestBuilder {
        APIRequestSupport.privateRead(pathComponents: ["api", "v1", "me", "connections"])
    }

    public static func updateProfile(email: String, username: String) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "me"],
            body: [
                "email": email,
                "username": username
            ]
        )
    }

    public static func uploadProfilePhoto(photo: UploadFile) throws -> APIRequestBuilder {
        try APIRequestSupport.privateMultipart(
            method: .post,
            pathComponents: ["api", "v1", "me", "photo"],
            fileField: "photo",
            file: photo
        )
    }

    public static func removeProfilePhoto() -> APIRequestBuilder {
        APIRequestSupport.privateRead(
            method: .delete,
            pathComponents: ["api", "v1", "me", "photo"]
        )
    }

    public static func updateNotificationPreferences(
        notifySpoonOnMyRecipe: Bool,
        notifyForkOfMyRecipe: Bool,
        notifyCookbookSaveOfMine: Bool,
        notifyFellowChefOriginCook: Bool
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "me", "notification-preferences"],
            body: [
                "notifySpoonOnMyRecipe": notifySpoonOnMyRecipe,
                "notifyForkOfMyRecipe": notifyForkOfMyRecipe,
                "notifyCookbookSaveOfMine": notifyCookbookSaveOfMine,
                "notifyFellowChefOriginCook": notifyFellowChefOriginCook
            ]
        )
    }

    public static func registerAPNSDevice(
        deviceID: String,
        platform: NativeAPNSPlatform,
        environment: APNSEnvironment,
        token: String,
        deviceName: String,
        appVersion: String
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "me", "apns-devices"],
            body: [
                "deviceId": deviceID,
                "platform": platform.rawValue,
                "environment": environment.rawValue,
                "token": token,
                "deviceName": deviceName,
                "appVersion": appVersion
            ]
        )
    }

    public static func revokeAPNSDevice(deviceID: String) -> APIRequestBuilder {
        APIRequestSupport.privateRead(
            method: .delete,
            pathComponents: ["api", "v1", "me", "apns-devices", deviceID]
        )
    }

    public static func disconnectConnection(connectionID: String) -> APIRequestBuilder {
        APIRequestSupport.privateRead(
            method: .delete,
            pathComponents: ["api", "v1", "me", "connections", connectionID]
        )
    }
}

public enum NativeAPNSPlatform: String, Codable, Equatable, Sendable {
    case ios
    case macos
}

public enum APNSEnvironment: String, Codable, Equatable, Sendable {
    case development
    case production
}

public enum PrivateSyncRequests {
    public static func sync(cursor: PaginationCursor?, limit: Int) -> APIRequestBuilder {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor.rawValue))
        }

        return APIRequestSupport.privateRead(
            pathComponents: ["api", "v1", "me", "sync"],
            queryItems: queryItems
        )
    }
}

public enum TokenCredentialRequests {
    public static func listTokens() -> APIRequestBuilder {
        APIRequestSupport.privateRead(pathComponents: ["api", "v1", "tokens"])
    }

    public static func createToken(name: String, scopes: [String]) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "tokens"],
            body: [
                "name": name,
                "scopes": scopes
            ]
        )
    }

    public static func revokeToken(credentialID: String) -> APIRequestBuilder {
        APIRequestSupport.privateRead(
            method: .delete,
            pathComponents: ["api", "v1", "tokens", credentialID]
        )
    }
}

public enum PublicProfileRequests {
    public static func profile(identifier: String) -> APIRequestBuilder {
        APIRequestSupport.publicRead(pathComponents: ["api", "v1", "users", identifier])
    }

    public static func kitchenVisitors(identifier: String, page: Int, limit: Int) -> APIRequestBuilder {
        APIRequestSupport.publicRead(
            pathComponents: ["api", "v1", "users", identifier, "kitchen-visitors"],
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }

    public static func fellowChefs(identifier: String, page: Int, limit: Int) -> APIRequestBuilder {
        APIRequestSupport.publicRead(
            pathComponents: ["api", "v1", "users", identifier, "fellow-chefs"],
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }
}

public enum SearchRequests {
    public static func search(query: String, scope: SearchScope, limit: Int) -> APIRequestBuilder {
        APIRequestSupport.publicRead(
            pathComponents: ["api", "v1", "search"],
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "scope", value: scope.rawValue),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }
}

public struct RecipeIngredientDraft: Equatable, Sendable {
    public let quantity: Double
    public let unit: String?
    public let name: String

    public init(quantity: Double, unit: String?, name: String) {
        self.quantity = quantity
        self.unit = unit
        self.name = name
    }

    var jsonObject: [String: Any] {
        var object: [String: Any] = [
            "quantity": quantity,
            "name": name
        ]
        if let unit {
            object["unit"] = unit
        }
        return object
    }
}

public struct RecipeStepDraft: Equatable, Sendable {
    public let stepNum: Int
    public let stepTitle: String?
    public let description: String
    public let duration: Int?
    public let ingredients: [RecipeIngredientDraft]
    public let outputStepNums: [Int]

    public init(
        stepNum: Int,
        stepTitle: String?,
        description: String,
        duration: Int?,
        ingredients: [RecipeIngredientDraft],
        outputStepNums: [Int]
    ) {
        self.stepNum = stepNum
        self.stepTitle = stepTitle
        self.description = description
        self.duration = duration
        self.ingredients = ingredients
        self.outputStepNums = outputStepNums
    }

    var jsonObject: [String: Any] {
        [
            "stepNum": stepNum,
            "stepTitle": stepTitle ?? NSNull(),
            "description": description,
            "duration": duration ?? NSNull(),
            "ingredients": ingredients.map(\.jsonObject),
            "outputStepNums": outputStepNums
        ]
    }
}

public enum RecipeWriteRequests {
    public static func createRecipe(
        clientMutationID: String,
        title: String,
        description: String?,
        servings: String?,
        steps: [RecipeStepDraft]
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes"],
            body: [
                "clientMutationId": clientMutationID,
                "title": title,
                "description": description ?? NSNull(),
                "servings": servings ?? NSNull(),
                "steps": steps.map(\.jsonObject)
            ]
        )
    }

    public static func updateRecipe(
        id: String,
        clientMutationID: String,
        title: String,
        description: String?,
        servings: String?
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "recipes", id],
            body: [
                "clientMutationId": clientMutationID,
                "title": title,
                "description": description ?? NSNull(),
                "servings": servings ?? NSNull()
            ]
        )
    }

    public static func deleteRecipe(
        id: String,
        clientMutationID: String,
        idempotency: MutationIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "recipes", id],
            clientMutationID: clientMutationID,
            idempotency: idempotency
        )
    }

    public static func forkRecipe(
        id: String,
        clientMutationID: String,
        titleOverride: String
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", id, "fork"],
            body: [
                "clientMutationId": clientMutationID,
                "title": titleOverride
            ]
        )
    }
}

public enum RecipeStepRequests {
    public static func createStep(
        recipeID: String,
        clientMutationID: String,
        stepNum: Int,
        stepTitle: String?,
        description: String,
        duration: Int?,
        ingredients: [RecipeIngredientDraft],
        outputStepNums: [Int]
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "steps"],
            body: [
                "clientMutationId": clientMutationID,
                "stepNum": stepNum,
                "stepTitle": stepTitle ?? NSNull(),
                "description": description,
                "duration": duration ?? NSNull(),
                "ingredients": ingredients.map(\.jsonObject),
                "outputStepNums": outputStepNums
            ]
        )
    }

    public static func updateStep(
        recipeID: String,
        stepID: String,
        clientMutationID: String,
        stepTitle: String?,
        description: String,
        duration: Int?,
        outputStepNums: [Int]
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "recipes", recipeID, "steps", stepID],
            body: [
                "clientMutationId": clientMutationID,
                "stepTitle": stepTitle ?? NSNull(),
                "description": description,
                "duration": duration ?? NSNull(),
                "outputStepNums": outputStepNums
            ]
        )
    }

    public static func deleteStep(
        recipeID: String,
        stepID: String,
        clientMutationID: String,
        idempotency: MutationIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "recipes", recipeID, "steps", stepID],
            clientMutationID: clientMutationID,
            idempotency: idempotency
        )
    }

    public static func reorderStep(
        recipeID: String,
        clientMutationID: String,
        stepID: String,
        toStepNum: Int
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "steps", "reorder"],
            body: [
                "clientMutationId": clientMutationID,
                "stepId": stepID,
                "toStepNum": toStepNum
            ]
        )
    }

    public static func createIngredient(
        recipeID: String,
        stepID: String,
        clientMutationID: String,
        quantity: Double,
        unit: String?,
        name: String
    ) throws -> APIRequestBuilder {
        var body: [String: Any] = [
            "clientMutationId": clientMutationID,
            "quantity": quantity,
            "name": name
        ]
        if let unit {
            body["unit"] = unit
        }

        return try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "steps", stepID, "ingredients"],
            body: body
        )
    }

    public static func deleteIngredient(
        recipeID: String,
        stepID: String,
        ingredientID: String,
        clientMutationID: String,
        idempotency: MutationIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "recipes", recipeID, "steps", stepID, "ingredients", ingredientID],
            clientMutationID: clientMutationID,
            idempotency: idempotency
        )
    }

    public static func replaceOutputUses(
        recipeID: String,
        clientMutationID: String,
        inputStepID: String,
        outputStepNums: [Int]
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .put,
            pathComponents: ["api", "v1", "recipes", recipeID, "step-output-uses"],
            body: [
                "clientMutationId": clientMutationID,
                "inputStepId": inputStepID,
                "outputStepNums": outputStepNums
            ]
        )
    }
}

public enum RecipeCoverAPIVariant: String, Codable, Equatable, Sendable {
    case image
    case stylized
}

public enum RecipeCoverRequests {
    public static func uploadImage(
        recipeID: String,
        image: UploadFile,
        clientMutationID: String,
        activate: Bool,
        generateEditorial: Bool
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateMultipart(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "image"],
            fileField: "image",
            file: image,
            fields: [
                "clientMutationId": clientMutationID,
                "activate": String(activate),
                "generateEditorial": String(generateEditorial)
            ]
        )
    }

    public static func listCovers(
        recipeID: String,
        includeArchived: Bool,
        limit: Int,
        offset: Int
    ) -> APIRequestBuilder {
        APIRequestSupport.privateRead(
            pathComponents: ["api", "v1", "recipes", recipeID, "covers"],
            queryItems: [
                URLQueryItem(name: "includeArchived", value: String(includeArchived)),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )
    }

    public static func createFromImageURL(
        recipeID: String,
        clientMutationID: String,
        imageURL: String,
        activate: Bool,
        generateEditorial: Bool
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "covers"],
            body: [
                "clientMutationId": clientMutationID,
                "imageUrl": imageURL,
                "activate": activate,
                "generateEditorial": generateEditorial
            ]
        )
    }

    public static func activate(
        recipeID: String,
        coverID: String,
        clientMutationID: String,
        variant: RecipeCoverAPIVariant
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "recipes", recipeID, "covers", coverID],
            body: [
                "clientMutationId": clientMutationID,
                "variant": variant.rawValue
            ]
        )
    }

    public static func archive(
        recipeID: String,
        coverID: String,
        clientMutationID: String,
        replacementCoverID: String,
        replacementVariant: RecipeCoverAPIVariant,
        confirmNoCover: Bool,
        deleteSafeObjects: Bool,
        idempotency: MutationIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "recipes", recipeID, "covers", coverID],
            clientMutationID: clientMutationID,
            idempotency: idempotency,
            body: [
                "replacementCoverId": replacementCoverID,
                "replacementVariant": replacementVariant.rawValue,
                "confirmNoCover": confirmNoCover,
                "deleteSafeObjects": deleteSafeObjects
            ]
        )
    }

    public static func regenerate(
        recipeID: String,
        clientMutationID: String,
        coverID: String,
        activateWhenReady: Bool
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "covers", "regenerate"],
            body: [
                "clientMutationId": clientMutationID,
                "coverId": coverID,
                "activateWhenReady": activateWhenReady
            ]
        )
    }

    public static func createFromSpoon(
        recipeID: String,
        spoonID: String,
        clientMutationID: String,
        activate: Bool,
        generateEditorial: Bool
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "covers", "from-spoon", spoonID],
            body: [
                "clientMutationId": clientMutationID,
                "activate": activate,
                "generateEditorial": generateEditorial
            ]
        )
    }
}

public enum RecipeSpoonRequests {
    public static func listSpoons(
        recipeID: String,
        cursor: PaginationCursor?,
        limit: Int
    ) -> APIRequestBuilder {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor.rawValue))
        }

        return APIRequestSupport.publicRead(
            pathComponents: ["api", "v1", "recipes", recipeID, "spoons"],
            queryItems: queryItems
        )
    }

    public static func createSpoon(
        recipeID: String,
        clientMutationID: String,
        note: String?,
        nextTime: String?,
        cookedAt: String?,
        photoURL: String,
        useAsRecipeCover: Bool
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "spoons"],
            body: [
                "clientMutationId": clientMutationID,
                "note": note ?? NSNull(),
                "nextTime": nextTime ?? NSNull(),
                "cookedAt": cookedAt ?? NSNull(),
                "photoUrl": photoURL,
                "useAsRecipeCover": useAsRecipeCover
            ]
        )
    }

    public static func createSpoon(
        recipeID: String,
        photo: UploadFile,
        clientMutationID: String,
        note: String?,
        nextTime: String?,
        cookedAt: String?,
        useAsRecipeCover: Bool
    ) throws -> APIRequestBuilder {
        var fields = [
            "clientMutationId": clientMutationID,
            "useAsRecipeCover": String(useAsRecipeCover)
        ]
        if let note {
            fields["note"] = note
        }
        if let nextTime {
            fields["nextTime"] = nextTime
        }
        if let cookedAt {
            fields["cookedAt"] = cookedAt
        }

        return try APIRequestSupport.privateMultipart(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "spoons"],
            fileField: "photo",
            file: photo,
            fields: fields
        )
    }

    public static func updateSpoon(
        recipeID: String,
        spoonID: String,
        clientMutationID: String,
        note: String?,
        nextTime: String?,
        cookedAt: String?,
        photoURL: String
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "recipes", recipeID, "spoons", spoonID],
            body: [
                "clientMutationId": clientMutationID,
                "note": note ?? NSNull(),
                "nextTime": nextTime ?? NSNull(),
                "cookedAt": cookedAt ?? NSNull(),
                "photoUrl": photoURL
            ]
        )
    }

    public static func deleteSpoon(
        recipeID: String,
        spoonID: String,
        clientMutationID: String,
        idempotency: MutationIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "recipes", recipeID, "spoons", spoonID],
            clientMutationID: clientMutationID,
            idempotency: idempotency
        )
    }
}

public enum CookbookWriteRequests {
    public static func createCookbook(clientMutationID: String, title: String) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "cookbooks"],
            body: [
                "clientMutationId": clientMutationID,
                "title": title
            ]
        )
    }

    public static func updateCookbook(id: String, clientMutationID: String, title: String) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "cookbooks", id],
            body: [
                "clientMutationId": clientMutationID,
                "title": title
            ]
        )
    }

    public static func deleteCookbook(
        id: String,
        clientMutationID: String,
        idempotency: MutationIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "cookbooks", id],
            clientMutationID: clientMutationID,
            idempotency: idempotency
        )
    }

    public static func addRecipe(
        cookbookID: String,
        recipeID: String,
        clientMutationID: String
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "cookbooks", cookbookID, "recipes", recipeID],
            body: ["clientMutationId": clientMutationID]
        )
    }

    public static func removeRecipe(
        cookbookID: String,
        recipeID: String,
        clientMutationID: String,
        idempotency: MutationIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "cookbooks", cookbookID, "recipes", recipeID],
            clientMutationID: clientMutationID,
            idempotency: idempotency
        )
    }
}

public struct RecipeImportResponse: Decodable, Equatable {
    public let recipe: Recipe?
    public let importCode: String?
    public let blockers: [JSONValue]?

    private enum CodingKeys: String, CodingKey {
        case recipe
        case importCode
        case blockers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipe = try container.decodeIfPresent(Recipe.self, forKey: .recipe)
        importCode = try container.decodeIfPresent(String.self, forKey: .importCode)
        blockers = try container.decodeIfPresent([JSONValue].self, forKey: .blockers)
    }
}

public enum RecipeImportRequests {
    public static func importURL(clientMutationID: String, url: URL) throws -> APIRequestBuilder {
        try importSource(
            clientMutationID: clientMutationID,
            source: [
                "type": "url",
                "url": url.absoluteString
            ]
        )
    }

    public static func importText(
        clientMutationID: String,
        text: String,
        sourceURL: URL?
    ) throws -> APIRequestBuilder {
        var source: [String: Any] = [
            "type": "text",
            "text": text
        ]
        if let sourceURL {
            source["url"] = sourceURL.absoluteString
        }

        return try importSource(clientMutationID: clientMutationID, source: source)
    }

    public static func importJSONLD(
        clientMutationID: String,
        jsonLD: JSONValue,
        sourceURL: URL?
    ) throws -> APIRequestBuilder {
        try importSource(
            clientMutationID: clientMutationID,
            source: [
                "type": "json-ld",
                "jsonLd": APIRequestSupport.jsonObject(from: jsonLD),
                "url": sourceURL?.absoluteString ?? NSNull()
            ]
        )
    }

    public static func importVideoURL(clientMutationID: String, url: URL) throws -> APIRequestBuilder {
        try importSource(
            clientMutationID: clientMutationID,
            source: [
                "type": "video-url",
                "url": url.absoluteString
            ]
        )
    }

    private static func importSource(clientMutationID: String, source: [String: Any]) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", "import"],
            body: [
                "clientMutationId": clientMutationID,
                "source": source
            ]
        )
    }
}
