import Foundation
import SpoonjoyCore

enum JourneyQAClientError: Error, CustomStringConvertible {
    case invalidURL(String)
    case unexpectedStatus(Int, path: String)
    case missingRecipeID

    var description: String {
        switch self {
        case .invalidURL(let path):
            "Could not build a QA URL for \(path)."
        case .unexpectedStatus(let status, let path):
            "QA answered HTTP \(status) for \(path)."
        case .missingRecipeID:
            "QA created a recipe but the response had no data.recipe.id."
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
