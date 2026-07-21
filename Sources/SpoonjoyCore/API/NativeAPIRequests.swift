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
    case missingRequiredField(String)
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

public struct NativeTelemetryAppMetadata: Equatable, Sendable {
    public let platform: String?
    public let appVersion: String?
    public let buildNumber: String?

    public init(platform: String? = nil, appVersion: String? = nil, buildNumber: String? = nil) {
        self.platform = platform
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }

    public static let unknown = NativeTelemetryAppMetadata()
}

public struct NativeTelemetryEvent: Equatable, Sendable {
    public enum Name: String, Equatable, Sendable {
        case bootstrapFailed = "bootstrap_failed"
        case bootstrapOffline = "bootstrap_offline"
        case appIntentCompleted = "app_intent_completed"
        case appIntentFailed = "app_intent_failed"
        case authFlowStarted = "auth_flow_started"
        case authFlowCompleted = "auth_flow_completed"
        case authFlowFailed = "auth_flow_failed"
        case settingsRefreshFailed = "settings_refresh_failed"
        case syncFailed = "sync_failed"
        case searchStarted = "search_started"
        case searchCompleted = "search_completed"
        case searchFailed = "search_failed"
    }

    public let name: Name
    public let stage: String
    public let environment: String
    public let metadata: NativeTelemetryAppMetadata
    public let route: String?
    public let errorType: String?
    public let requestID: String?
    public let status: Int?
    public let apiCode: String?
    public let retry: String?
    public let accountBound: Bool?
    public let hasRenderableCacheContent: Bool?
    public let recipes: Int?
    public let cookbooks: Int?
    public let shoppingItems: Int?
    public let queuedMutations: Int?
    public let intentName: String?
    public let intentActionKind: String?
    public let intentOutcome: String?
    public let intentReturnsValue: Bool?
    public let intentQueuedMutationID: String?
    public let intentQueuedMutationKind: String?
    public let intentOpensURL: String?
    public let authProvider: String?
    public let authPhase: String?
    public let authOutcome: String?
    public let authDiagnosticCode: String?
    public let authSessionState: String?
    public let authCredentialPresent: Bool?
    public let authIdentityTokenPresent: Bool?
    public let authRawNoncePresent: Bool?
    public let authEmailPresent: Bool?
    public let authFullNamePresent: Bool?
    public let authOAuthStatePresent: Bool?
    public let authRedirectScheme: String?
    public let authRedirectHost: String?
    public let searchScope: String?
    public let searchQueryLength: Int?
    public let searchResultCount: Int?
    public let durationMilliseconds: Int?

    public init(
        name: Name,
        stage: String,
        environment: String,
        metadata: NativeTelemetryAppMetadata = .unknown,
        route: String? = nil,
        errorType: String? = nil,
        requestID: String? = nil,
        status: Int? = nil,
        apiCode: String? = nil,
        retry: String? = nil,
        accountBound: Bool? = nil,
        hasRenderableCacheContent: Bool? = nil,
        recipes: Int? = nil,
        cookbooks: Int? = nil,
        shoppingItems: Int? = nil,
        queuedMutations: Int? = nil,
        intentName: String? = nil,
        intentActionKind: String? = nil,
        intentOutcome: String? = nil,
        intentReturnsValue: Bool? = nil,
        intentQueuedMutationID: String? = nil,
        intentQueuedMutationKind: String? = nil,
        intentOpensURL: String? = nil,
        authProvider: String? = nil,
        authPhase: String? = nil,
        authOutcome: String? = nil,
        authDiagnosticCode: String? = nil,
        authSessionState: String? = nil,
        authCredentialPresent: Bool? = nil,
        authIdentityTokenPresent: Bool? = nil,
        authRawNoncePresent: Bool? = nil,
        authEmailPresent: Bool? = nil,
        authFullNamePresent: Bool? = nil,
        authOAuthStatePresent: Bool? = nil,
        authRedirectScheme: String? = nil,
        authRedirectHost: String? = nil,
        searchScope: String? = nil,
        searchQueryLength: Int? = nil,
        searchResultCount: Int? = nil,
        durationMilliseconds: Int? = nil
    ) {
        self.name = name
        self.stage = stage
        self.environment = environment
        self.metadata = metadata
        self.route = route
        self.errorType = errorType
        self.requestID = requestID
        self.status = status
        self.apiCode = apiCode
        self.retry = retry
        self.accountBound = accountBound
        self.hasRenderableCacheContent = hasRenderableCacheContent
        self.recipes = recipes
        self.cookbooks = cookbooks
        self.shoppingItems = shoppingItems
        self.queuedMutations = queuedMutations
        self.intentName = intentName
        self.intentActionKind = intentActionKind
        self.intentOutcome = intentOutcome
        self.intentReturnsValue = intentReturnsValue
        self.intentQueuedMutationID = intentQueuedMutationID
        self.intentQueuedMutationKind = intentQueuedMutationKind
        self.intentOpensURL = intentOpensURL
        self.authProvider = authProvider
        self.authPhase = authPhase
        self.authOutcome = authOutcome
        self.authDiagnosticCode = authDiagnosticCode
        self.authSessionState = authSessionState
        self.authCredentialPresent = authCredentialPresent
        self.authIdentityTokenPresent = authIdentityTokenPresent
        self.authRawNoncePresent = authRawNoncePresent
        self.authEmailPresent = authEmailPresent
        self.authFullNamePresent = authFullNamePresent
        self.authOAuthStatePresent = authOAuthStatePresent
        self.authRedirectScheme = authRedirectScheme
        self.authRedirectHost = authRedirectHost
        self.searchScope = searchScope
        self.searchQueryLength = searchQueryLength
        self.searchResultCount = searchResultCount
        self.durationMilliseconds = durationMilliseconds
    }
}

public struct NativeTelemetryResponse: Decodable, Equatable, Sendable {
    public let accepted: Bool
}

public enum NativeAuthTelemetryOutcome: String, Equatable, Sendable {
    case started
    case completed
    case failed

    var eventName: NativeTelemetryEvent.Name {
        switch self {
        case .started:
            .authFlowStarted
        case .completed:
            .authFlowCompleted
        case .failed:
            .authFlowFailed
        }
    }
}

public struct NativeAuthTelemetryDescriptor: Equatable, Sendable {
    public let provider: String
    public let phase: String
    public let outcome: NativeAuthTelemetryOutcome
    public let diagnosticCode: String?
    public let sessionState: String?
    public let credentialPresent: Bool?
    public let identityTokenPresent: Bool?
    public let rawNoncePresent: Bool?
    public let emailPresent: Bool?
    public let fullNamePresent: Bool?
    public let oauthStatePresent: Bool?
    public let redirectScheme: String?
    public let redirectHost: String?
    public let route: String?
    public let errorType: String?
    public let requestID: String?
    public let status: Int?
    public let apiCode: String?
    public let retry: String?
    public let accountBound: Bool?

    public init(
        authProvider provider: String,
        phase: String,
        outcome: NativeAuthTelemetryOutcome,
        diagnosticCode: String? = nil,
        sessionState: String? = nil,
        credentialPresent: Bool? = nil,
        identityTokenPresent: Bool? = nil,
        rawNoncePresent: Bool? = nil,
        emailPresent: Bool? = nil,
        fullNamePresent: Bool? = nil,
        oauthStatePresent: Bool? = nil,
        redirectScheme: String? = nil,
        redirectHost: String? = nil,
        route: String? = nil,
        errorType: String? = nil,
        requestID: String? = nil,
        status: Int? = nil,
        apiCode: String? = nil,
        retry: String? = nil,
        accountBound: Bool? = nil
    ) {
        self.provider = provider
        self.phase = phase
        self.outcome = outcome
        self.diagnosticCode = diagnosticCode
        self.sessionState = sessionState
        self.credentialPresent = credentialPresent
        self.identityTokenPresent = identityTokenPresent
        self.rawNoncePresent = rawNoncePresent
        self.emailPresent = emailPresent
        self.fullNamePresent = fullNamePresent
        self.oauthStatePresent = oauthStatePresent
        self.redirectScheme = redirectScheme
        self.redirectHost = redirectHost
        self.route = route
        self.errorType = errorType
        self.requestID = requestID
        self.status = status
        self.apiCode = apiCode
        self.retry = retry
        self.accountBound = accountBound
    }

    public func telemetryEvent(
        environment: String,
        metadata: NativeTelemetryAppMetadata
    ) -> NativeTelemetryEvent {
        NativeTelemetryEvent(
            name: outcome.eventName,
            stage: "auth",
            environment: environment,
            metadata: metadata,
            route: route,
            errorType: errorType,
            requestID: requestID,
            status: status,
            apiCode: apiCode,
            retry: retry,
            accountBound: accountBound,
            authProvider: provider,
            authPhase: phase,
            authOutcome: outcome.rawValue,
            authDiagnosticCode: diagnosticCode,
            authSessionState: sessionState,
            authCredentialPresent: credentialPresent,
            authIdentityTokenPresent: identityTokenPresent,
            authRawNoncePresent: rawNoncePresent,
            authEmailPresent: emailPresent,
            authFullNamePresent: fullNamePresent,
            authOAuthStatePresent: oauthStatePresent,
            authRedirectScheme: redirectScheme,
            authRedirectHost: redirectHost
        )
    }
}

public enum NativeTelemetryRequests {
    public static func recordEvent(_ event: NativeTelemetryEvent) throws -> APIRequestBuilder {
        var body: [String: Any] = [
            "event": event.name.rawValue,
            "stage": event.stage,
            "environment": event.environment
        ]
        put(event.metadata.platform, in: &body, key: "platform")
        put(event.metadata.appVersion, in: &body, key: "appVersion")
        put(event.metadata.buildNumber, in: &body, key: "buildNumber")
        put(event.route, in: &body, key: "route")
        put(event.errorType, in: &body, key: "errorType")
        put(event.requestID, in: &body, key: "requestId")
        put(event.status, in: &body, key: "status")
        put(event.apiCode, in: &body, key: "apiCode")
        put(event.retry, in: &body, key: "retry")
        put(event.accountBound, in: &body, key: "accountBound")
        put(event.hasRenderableCacheContent, in: &body, key: "hasRenderableCacheContent")
        put(event.recipes, in: &body, key: "recipes")
        put(event.cookbooks, in: &body, key: "cookbooks")
        put(event.shoppingItems, in: &body, key: "shoppingItems")
        put(event.queuedMutations, in: &body, key: "queuedMutations")
        put(event.intentName, in: &body, key: "intentName")
        put(event.intentActionKind, in: &body, key: "intentActionKind")
        put(event.intentOutcome, in: &body, key: "intentOutcome")
        put(event.intentReturnsValue, in: &body, key: "intentReturnsValue")
        put(event.intentQueuedMutationID, in: &body, key: "intentQueuedMutationId")
        put(event.intentQueuedMutationKind, in: &body, key: "intentQueuedMutationKind")
        put(event.intentOpensURL, in: &body, key: "intentOpensUrl")
        put(event.authProvider, in: &body, key: "authProvider")
        put(event.authPhase, in: &body, key: "authPhase")
        put(event.authOutcome, in: &body, key: "authOutcome")
        put(event.authDiagnosticCode, in: &body, key: "authDiagnosticCode")
        put(event.authSessionState, in: &body, key: "authSessionState")
        put(event.authCredentialPresent, in: &body, key: "authCredentialPresent")
        put(event.authIdentityTokenPresent, in: &body, key: "authIdentityTokenPresent")
        put(event.authRawNoncePresent, in: &body, key: "authRawNoncePresent")
        put(event.authEmailPresent, in: &body, key: "authEmailPresent")
        put(event.authFullNamePresent, in: &body, key: "authFullNamePresent")
        put(event.authOAuthStatePresent, in: &body, key: "authOAuthStatePresent")
        put(event.authRedirectScheme, in: &body, key: "authRedirectScheme")
        put(event.authRedirectHost, in: &body, key: "authRedirectHost")
        put(event.searchScope, in: &body, key: "searchScope")
        put(event.searchQueryLength, in: &body, key: "searchQueryLength")
        put(event.searchResultCount, in: &body, key: "searchResultCount")
        put(event.durationMilliseconds, in: &body, key: "durationMilliseconds")
        return try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "native", "telemetry"],
            body: body
        )
    }

    private static func put(_ value: String?, in body: inout [String: Any], key: String) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        body[key] = value
    }

    private static func put(_ value: Int?, in body: inout [String: Any], key: String) {
        guard let value else { return }
        body[key] = value
    }

    private static func put(_ value: Bool?, in body: inout [String: Any], key: String) {
        guard let value else { return }
        body[key] = value
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
                URLQueryItem(name: "limit", value: String(SearchSurfaceRequest.normalizedLimit(limit)))
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
        try validateCreateRecipeSteps(steps)
        return try APIRequestSupport.privateJSON(
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

    private static func validateCreateRecipeSteps(_ steps: [RecipeStepDraft]) throws {
        for (stepIndex, step) in steps.enumerated() {
            for (ingredientIndex, ingredient) in step.ingredients.enumerated() where ingredient.unit == nil {
                throw APIRequestBuildError.missingRequiredField("steps.\(stepIndex).ingredients.\(ingredientIndex).unit")
            }
        }
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
        try validateIngredients(ingredients, fieldPrefix: "ingredients")
        return try APIRequestSupport.privateJSON(
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
        guard let unit else {
            throw APIRequestBuildError.missingRequiredField("ingredient.unit")
        }
        var body: [String: Any] = [
            "clientMutationId": clientMutationID,
            "quantity": quantity,
            "name": name
        ]
        body["unit"] = unit

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

private func validateIngredients(_ ingredients: [RecipeIngredientDraft], fieldPrefix: String) throws {
    for (ingredientIndex, ingredient) in ingredients.enumerated() where ingredient.unit == nil {
        throw APIRequestBuildError.missingRequiredField("\(fieldPrefix).\(ingredientIndex).unit")
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
        try uploadImage(
            recipeID: recipeID,
            photo: image,
            clientMutationID: clientMutationID,
            activateWhenReady: activate,
            generateEditorial: generateEditorial,
            postAsSpoon: false
        )
    }

    public static func uploadImage(
        recipeID: String,
        image: UploadFile,
        clientMutationID: String,
        activateWhenReady: Bool,
        generateEditorial: Bool
    ) throws -> APIRequestBuilder {
        try uploadImage(
            recipeID: recipeID,
            photo: image,
            clientMutationID: clientMutationID,
            activateWhenReady: activateWhenReady,
            generateEditorial: generateEditorial,
            postAsSpoon: false
        )
    }

    public static func uploadImage(
        recipeID: String,
        photo: UploadFile,
        clientMutationID: String,
        activate: Bool,
        generateEditorial: Bool,
        postAsSpoon: Bool,
        note: String? = nil,
        nextTime: String? = nil,
        cookedAt: String? = nil
    ) throws -> APIRequestBuilder {
        try uploadImage(
            recipeID: recipeID,
            photo: photo,
            clientMutationID: clientMutationID,
            activateWhenReady: activate,
            generateEditorial: generateEditorial,
            postAsSpoon: postAsSpoon,
            note: note,
            nextTime: nextTime,
            cookedAt: cookedAt
        )
    }

    public static func uploadImage(
        recipeID: String,
        photo: UploadFile,
        clientMutationID: String,
        activateWhenReady: Bool,
        generateEditorial: Bool,
        postAsSpoon: Bool,
        note: String? = nil,
        nextTime: String? = nil,
        cookedAt: String? = nil
    ) throws -> APIRequestBuilder {
        var fields = [
            "clientMutationId": clientMutationID,
            "activateWhenReady": String(activateWhenReady),
            "generateEditorial": String(generateEditorial),
            "postAsSpoon": String(postAsSpoon)
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
            pathComponents: ["api", "v1", "recipes", recipeID, "image"],
            fileField: "photo",
            file: photo,
            fields: fields
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

    public static func generatePlaceholder(
        recipeID: String,
        clientMutationID: String,
        promptAddition: String?,
        activateWhenReady: Bool
    ) throws -> APIRequestBuilder {
        var body: [String: Any] = [
            "clientMutationId": clientMutationID,
            "activateWhenReady": activateWhenReady
        ]
        if let promptAddition {
            body["promptAddition"] = promptAddition
        }

        return try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "covers", "generate"],
            body: body
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

    public static func setNoCover(
        recipeID: String,
        clientMutationID: String,
        confirmNoCover: Bool
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "recipes", recipeID, "covers"],
            body: [
                "clientMutationId": clientMutationID,
                "confirmNoCover": confirmNoCover
            ]
        )
    }

    public static func archive(
        recipeID: String,
        coverID: String,
        clientMutationID: String,
        replacementCoverID: String?,
        replacementVariant: RecipeCoverAPIVariant?,
        confirmNoCover: Bool,
        deleteSafeObjects: Bool,
        idempotency: MutationIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "recipes", recipeID, "covers", coverID],
            clientMutationID: clientMutationID,
            idempotency: idempotency,
            body: [
                "replacementCoverId": replacementCoverID ?? NSNull(),
                "replacementVariant": replacementVariant?.rawValue ?? NSNull(),
                "confirmNoCover": confirmNoCover,
                "deleteSafeObjects": deleteSafeObjects
            ]
        )
    }

    public static func regenerate(
        recipeID: String,
        clientMutationID: String,
        coverID: String,
        promptAddition: String? = nil,
        activateWhenReady: Bool
    ) throws -> APIRequestBuilder {
        var body: [String: Any] = [
            "clientMutationId": clientMutationID,
            "coverId": coverID,
            "activateWhenReady": activateWhenReady
        ]
        if let promptAddition {
            body["promptAddition"] = promptAddition
        }

        return try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "recipes", recipeID, "covers", "regenerate"],
            body: body
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
        photoURL: String?,
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
                "photoUrl": photoURL ?? NSNull(),
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
        photoURL: String?
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "recipes", recipeID, "spoons", spoonID],
            body: [
                "clientMutationId": clientMutationID,
                "note": note ?? NSNull(),
                "nextTime": nextTime ?? NSNull(),
                "cookedAt": cookedAt ?? NSNull(),
                "photoUrl": photoURL ?? NSNull()
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

    public var providerSecretBlockerResourceID: String? {
        for blocker in blockers ?? [] {
            guard case .object(let object) = blocker,
                  object["capability"] == .string("ProviderSecret") else {
                continue
            }
            if case .string(let resourceID)? = object["resource"] {
                let trimmed = resourceID.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "recipe-import" : trimmed
            }
            return "recipe-import"
        }
        return nil
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
