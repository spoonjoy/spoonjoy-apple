import Foundation
import SpoonjoyCore

enum JourneyQAClientError: Error, CustomStringConvertible {
    case invalidURL(String)
    case unexpectedStatus(Int, path: String)
    case missingRecipeID
    case missingIngredient(String)
    case cookSessionNotSynced(String)

    var description: String {
        switch self {
        case .invalidURL(let path):
            "Could not build a QA URL for \(path)."
        case .unexpectedStatus(let status, let path):
            "QA answered HTTP \(status) for \(path)."
        case .missingRecipeID:
            "QA created a recipe but the response had no data.recipe.id."
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

    /// Creates a recipe as this account and returns its id.
    func createRecipe(title: String, steps: [RecipeStepDraft]) async throws -> String {
        let builder = try RecipeWriteRequests.createRecipe(
            clientMutationID: "journey-\(UUID().uuidString.lowercased())",
            title: title,
            description: nil,
            servings: nil,
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

    func shoppingList() async throws -> ShoppingListState {
        try await LiveShoppingSurfaceRepository(configuration: configuration).fetchShoppingList()
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

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw JourneyQAClientError.unexpectedStatus(status, path: request.url.path)
        }
        return data
    }
}

private struct JourneyCookSessionEnvelope: Decodable {
    struct State: Decodable {
        struct Progress: Decodable {
            let checkedIngredientIds: [String]
        }

        let revision: Int
        let progress: Progress
    }

    let state: State
}
