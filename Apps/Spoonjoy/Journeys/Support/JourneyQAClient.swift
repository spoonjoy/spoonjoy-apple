import Foundation
import SpoonjoyCore

enum JourneyQAClientError: Error, CustomStringConvertible {
    case invalidURL(String)
    case unexpectedStatus(Int, path: String, detail: String)
    case missingRecipeID
    case missingCookbookID
    case missingIngredient(String)
    case missingRecipeTitle(String)
    case recipeTitleNotSynced(expected: String, last: String)
    case cookSessionNotSynced(String)
    case blockNotStored(username: String)

    var description: String {
        switch self {
        case .invalidURL(let path):
            "Could not build a QA URL for \(path)."
        case .unexpectedStatus(let status, let path, let detail):
            "QA answered HTTP \(status) for \(path)\(detail)."
        case .missingRecipeID:
            "QA created a recipe but the response had no data.recipe.id."
        case .missingCookbookID:
            "QA created a cookbook but the response had no cookbook id."
        case .missingRecipeTitle(let id):
            "QA returned recipe \(id) without data.recipe.title."
        case .blockNotStored(let username):
            "QA never listed @\(username) among this account's blocks."
        case .recipeTitleNotSynced(let expected, let last):
            "QA's recipe title never became \"\(expected)\". Last reading: \"\(last)\"."
        case .missingIngredient(let name):
            "The recipe QA returned has no ingredient named \(name)."
        case .cookSessionNotSynced(let detail):
            "QA's cook session never showed the app's check. \(detail)"
        }
    }
}

/// A test-runner-side QA API client: sets up and reads back data independently of the app,
/// using the same SpoonjoyCore request builders the app uses.
struct JourneyQAClient: Sendable {
    let configuration: APIClientConfiguration

    static func signIn(_ account: JourneyAccount) async throws -> JourneyQAClient {
        let builder = try NativePasswordSignInRequests.exchangeCredential(
            NativePasswordSignInCredential(emailOrUsername: account.username, password: account.password)
        )
        let data = try await send(builder, configuration: APIClientConfiguration(baseURL: JourneyQA.baseURL))
        let token = try (try? APIEnvelope<OAuthTokenResponse>.decode(data).data) ??
            JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        return JourneyQAClient(
            configuration: APIClientConfiguration(baseURL: JourneyQA.baseURL, bearerToken: token.accessToken)
        )
    }

    /// Signs `account` in as the app would and returns the session the app saves, for a journey that installs it
    /// instead of typing into the sign-in form (the Duo journey; see `DuoHinge.installSession`).
    static func nativeSession(_ account: JourneyAccount) async throws -> AuthSession {
        let builder = try NativePasswordSignInRequests.exchangeCredential(
            NativePasswordSignInCredential(emailOrUsername: account.username, password: account.password)
        )
        let data = try await send(builder, configuration: APIClientConfiguration(baseURL: JourneyQA.baseURL))
        let token = try (try? APIEnvelope<OAuthTokenResponse>.decode(data).data) ??
            JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        // Bound to its account, as the app binds a session after its first sync, so what the app saves under this
        // account is found again after a relaunch.
        let sync = try APIEnvelope<NativeSyncData>.decode(try await send(
            NativeSyncBootstrapRequest.defaultRequest(cursor: nil),
            configuration: APIClientConfiguration(baseURL: JourneyQA.baseURL, bearerToken: token.accessToken)
        ))
        return try AuthSession(
            clientID: token.clientID ?? NativeAuthSession.nativeClientID(forServerBaseURL: JourneyQA.baseURL),
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            tokenType: token.tokenType,
            expiresAt: Date().addingTimeInterval(TimeInterval(token.expiresIn)),
            scope: token.scope,
            accountID: sync.data.freshness.accountID
        )
    }

    /// Uploads `photo` as the recipe's cover and makes it the active one, without an editorial rendition.
    func uploadCover(recipeID: String, photo: UploadFile) async throws {
        let builder = try RecipeCoverRequests.uploadImage(
            recipeID: recipeID,
            image: photo,
            clientMutationID: "journey-\(UUID().uuidString.lowercased())",
            activateWhenReady: true,
            generateEditorial: false
        )
        _ = try await Self.send(builder, configuration: configuration)
    }

    /// Creates a recipe as this account and returns its id.
    func createRecipe(
        title: String,
        description: String? = nil,
        servings: String? = nil,
        steps: [RecipeStepDraft]
    ) async throws -> String {
        let builder = try RecipeWriteRequests.createRecipe(
            clientMutationID: "journey-\(UUID().uuidString.lowercased())",
            title: title,
            description: description,
            servings: servings,
            steps: steps
        )
        let envelope = try APIEnvelope<JSONValue>.decode(try await Self.send(builder, configuration: configuration))
        guard case .object(let data) = envelope.data,
              case .object(let recipe)? = data["recipe"],
              case .string(let id)? = recipe["id"] else {
            throw JourneyQAClientError.missingRecipeID
        }
        return id
    }

    /// Renames a recipe as this account without naming a version, the way another device saving over it would.
    func renameRecipe(_ recipeID: String, to title: String) async throws {
        let builder = try RecipeWriteRequests.updateRecipe(
            id: recipeID,
            clientMutationID: "journey-\(UUID().uuidString.lowercased())",
            edit: NativeRecipeEdit(
                changes: [NativeRecipeFieldChange(field: .title, value: title, base: nil)],
                expectedUpdatedAt: nil
            )
        )
        _ = try await Self.send(builder, configuration: configuration)
    }

    /// The recipe's title as QA holds it now.
    func recipeTitle(_ recipeID: String) async throws -> String {
        let data = try await Self.send(PublicCatalogRequests.recipeDetail(id: recipeID), configuration: configuration)
        let envelope = try APIEnvelope<JSONValue>.decode(data)
        guard case .object(let fields) = envelope.data,
              case .object(let recipe)? = fields["recipe"],
              case .string(let title)? = recipe["title"] else {
            throw JourneyQAClientError.missingRecipeTitle(recipeID)
        }
        return title
    }

    /// Waits for the app's queued edit to reach QA: reads the recipe once a second, up to `attempts` times,
    /// until its title is `expected`. Recursion instead of a loop keeps the journey rules simple.
    func recipeTitle(_ recipeID: String, waitingFor expected: String, attempts: Int = 30) async throws -> String {
        let title = try await recipeTitle(recipeID)
        if title == expected {
            return title
        }
        guard attempts > 1 else {
            throw JourneyQAClientError.recipeTitleNotSynced(expected: expected, last: title)
        }
        try await Task.sleep(for: .seconds(1))
        return try await recipeTitle(recipeID, waitingFor: expected, attempts: attempts - 1)
    }

    /// The chefs QA holds as blocked by this account (GET /api/v1/blocks).
    func blockedChefUsernames() async throws -> [String] {
        let data = try await Self.send(ModerationRequests.blocks(), configuration: configuration)
        return try APIEnvelope<ChefBlockListResponse>.decode(data).data.blocks.map(\.chef.username)
    }

    /// Waits for the app's block to reach QA: reads this account's blocks once a second, up to `attempts` times.
    /// Recursion instead of a loop keeps the journey rules simple.
    func blockedChefUsernames(waitingFor username: String, attempts: Int = 30) async throws -> [String] {
        let blocked = try await blockedChefUsernames()
        if blocked.contains(username) {
            return blocked
        }
        guard attempts > 1 else {
            throw JourneyQAClientError.blockNotStored(username: username)
        }
        try await Task.sleep(for: .seconds(1))
        return try await blockedChefUsernames(waitingFor: username, attempts: attempts - 1)
    }

    /// Creates a cookbook as this account and returns its id.
    func createCookbook(title: String) async throws -> String {
        let builder = try CookbookWriteRequests.createCookbook(
            clientMutationID: "journey-\(UUID().uuidString.lowercased())",
            title: title
        )
        let envelope = try APIEnvelope<JSONValue>.decode(try await Self.send(builder, configuration: configuration))
        guard case .object(let data) = envelope.data else {
            throw JourneyQAClientError.missingCookbookID
        }
        if case .object(let cookbook)? = data["cookbook"], case .string(let id)? = cookbook["id"] {
            return id
        }
        if case .string(let id)? = data["id"] {
            return id
        }
        throw JourneyQAClientError.missingCookbookID
    }

    /// Puts a recipe this account owns into a cookbook it owns.
    func addRecipe(_ recipeID: String, toCookbook cookbookID: String) async throws {
        let builder = try CookbookWriteRequests.addRecipe(
            cookbookID: cookbookID,
            recipeID: recipeID,
            clientMutationID: "journey-\(UUID().uuidString.lowercased())"
        )
        _ = try await Self.send(builder, configuration: configuration)
    }

    /// The id QA gave the ingredient called `name` (QA lowercases ingredient names), found by reading the recipe back.
    func ingredientID(named name: String, inRecipe recipeID: String) async throws -> String {
        let data = try await Self.send(PublicCatalogRequests.recipeDetail(id: recipeID), configuration: configuration)
        let envelope = try APIEnvelope<JSONValue>.decode(data)
        guard let id = Self.ingredientID(named: name.lowercased(), in: envelope.data) else {
            throw JourneyQAClientError.missingIngredient(name)
        }
        return id
    }

    private static func ingredientID(named name: String, in value: JSONValue) -> String? {
        switch value {
        case .object(let fields):
            if case .string(let id)? = fields["id"], case .string(let found)? = fields["name"], found.lowercased() == name {
                return id
            }
            return fields.values.compactMap { ingredientID(named: name, in: $0) }.first
        case .array(let items):
            return items.compactMap { ingredientID(named: name, in: $0) }.first
        default:
            return nil
        }
    }

    /// What QA's cook-session store holds for this account and recipe right now.
    struct CookSessionReading: Sendable {
        let revision: Int
        let checkedIngredientIDs: [String]
        /// The step the session is on, counting from 0.
        let activeStepIndex: Int
        /// The response body as QA sent it, with this client's bearer token replaced by `[redacted]`.
        let redactedBody: String
    }

    /// Reads `GET /api/cook-sessions/:recipeId` as this account, directly from the test process.
    func cookSession(recipeID: String) async throws -> CookSessionReading {
        let data = try await Self.send(CookSessionRequests.read(recipeID: recipeID), configuration: configuration)
        let envelope = try JSONDecoder().decode(JourneyCookSessionEnvelope.self, from: data)
        let body = String(decoding: data, as: UTF8.self)
        let redacted = configuration.bearerToken.map { body.replacingOccurrences(of: $0, with: "[redacted]") } ?? body
        return CookSessionReading(
            revision: envelope.state.revision,
            checkedIngredientIDs: envelope.state.progress.checkedIngredientIds,
            activeStepIndex: envelope.state.progress.activeStepIndex ?? 0,
            redactedBody: redacted
        )
    }

    /// Waits for the app's debounced cook sync to reach QA: reads the session once a second, up to `attempts` times,
    /// until it holds `ingredientID` as checked. Recursion instead of a loop keeps the journey rules simple.
    func cookSession(
        recipeID: String,
        waitingForChecked ingredientID: String,
        attempts: Int = 30
    ) async throws -> CookSessionReading {
        let reading = try? await cookSession(recipeID: recipeID)
        if let reading, reading.revision > 0, reading.checkedIngredientIDs.contains(ingredientID) {
            return reading
        }
        guard attempts > 1 else {
            throw JourneyQAClientError.cookSessionNotSynced(
                "Last reading: \(reading?.redactedBody ?? "no readable session (404 or an error status)")"
            )
        }
        try await Task.sleep(for: .seconds(1))
        return try await cookSession(recipeID: recipeID, waitingForChecked: ingredientID, attempts: attempts - 1)
    }

    /// Waits for the app's debounced cook sync to put the session on `stepIndex` (counting from 0), reading once a
    /// second up to `attempts` times.
    func cookSession(
        recipeID: String,
        waitingForStep stepIndex: Int,
        attempts: Int = 30
    ) async throws -> CookSessionReading {
        let reading = try? await cookSession(recipeID: recipeID)
        if let reading, reading.revision > 0, reading.activeStepIndex == stepIndex {
            return reading
        }
        guard attempts > 1 else {
            throw JourneyQAClientError.cookSessionNotSynced(
                "Waited for step index \(stepIndex). Last reading: \(reading?.redactedBody ?? "no readable session (404 or an error status)")"
            )
        }
        try await Task.sleep(for: .seconds(1))
        return try await cookSession(recipeID: recipeID, waitingForStep: stepIndex, attempts: attempts - 1)
    }

    func shoppingList() async throws -> ShoppingListState {
        try await LiveShoppingSurfaceRepository(configuration: configuration).fetchShoppingList()
    }

    /// Adds an item to this account's shopping list.
    func addShoppingItem(name: String, quantity: Double, unit: String) async throws {
        let builder = try ShoppingListRequests.addItem(
            name: name,
            quantity: quantity,
            unit: unit,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "journey-\(UUID().uuidString.lowercased())"
        )
        _ = try await Self.send(builder, configuration: configuration)
    }

    /// Reads QA's shopping list until an item whose name contains `name` arrives, or `attempts` reads have passed.
    func shoppingList(waitingForItemNamed name: String, attempts: Int = 30) async throws -> ShoppingListState {
        let list = try await shoppingList()
        if attempts <= 1 || list.receiptItems.contains(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
            return list
        }
        try await Task.sleep(for: .seconds(1))
        return try await shoppingList(waitingForItemNamed: name, attempts: attempts - 1)
    }

    /// Network failures that say nothing about QA's answer: the runner's connection dropped or timed out before a
    /// response arrived. A journey checks the app against QA, not the CI runner's network, so these are tried again.
    private static let droppedConnectionCodes: Set<URLError.Code> = [
        .networkConnectionLost, .timedOut, .notConnectedToInternet, .cannotConnectToHost, .dnsLookupFailed,
    ]

    /// Sends the identical request up to three times when the connection drops. Resending is safe: sign-in only issues
    /// a token, reads change nothing, and every write carries its clientMutationId, which QA treats as an idempotency
    /// key for exactly this retry.
    private static func dataSurvivingDroppedConnections(
        for request: URLRequest,
        attempts: Int = 3
    ) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError where attempts > 1 && droppedConnectionCodes.contains(error.code) {
            try await Task.sleep(for: .seconds(2))
            return try await dataSurvivingDroppedConnections(for: request, attempts: attempts - 1)
        }
    }

    private static func send(_ builder: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> Data {
        let request = try builder.urlRequest(
            configuration: configuration,
            authorization: configuration.bearerToken == nil ? .omit : .includeBearerToken
        )
        var components = URLComponents(url: request.url.baseURL, resolvingAgainstBaseURL: false)
        components?.path = request.url.path
        components?.queryItems = request.queryItems.isEmpty ? nil : request.queryItems
        guard let url = components?.url else {
            throw JourneyQAClientError.invalidURL(request.url.path)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (data, response) = try await dataSurvivingDroppedConnections(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw JourneyQAClientError.unexpectedStatus(status, path: request.url.path, detail: errorDetail(data) + QAResponseTrace.describe(response as? HTTPURLResponse))
        }
        return data
    }

    /// The error code and request id from an API error body, so a failed journey names the
    /// server's request in the QA Worker's logs. A body that is not an API error (a Cloudflare
    /// error page, for one) is quoted briefly instead. The message is left out: it adds nothing
    /// the code does not say, and an error body never needs to reach the log whole.
    static func errorDetail(_ data: Data) -> String {
        if let body = try? JSONDecoder().decode(JourneyAPIErrorBody.self, from: data) {
            let parts = [body.error?.code.map { "code \($0)" }, body.requestId.map { "request \($0)" }].compactMap { $0 }
            if !parts.isEmpty {
                return " (" + parts.joined(separator: ", ") + ")"
            }
        }
        let text = String(decoding: data.prefix(120), as: UTF8.self)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return text.isEmpty ? " (empty body)" : " (body: \(text))"
    }
}

private struct JourneyAPIErrorBody: Decodable {
    struct Detail: Decodable {
        let code: String?
    }

    let requestId: String?
    let error: Detail?
}

private struct JourneyCookSessionEnvelope: Decodable {
    struct State: Decodable {
        struct Progress: Decodable {
            let checkedIngredientIds: [String]
            let activeStepIndex: Int?
        }

        let revision: Int
        let progress: Progress
    }

    let state: State
}
