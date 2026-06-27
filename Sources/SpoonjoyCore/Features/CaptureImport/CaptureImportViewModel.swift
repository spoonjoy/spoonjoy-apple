import Foundation

public enum CaptureImportConnectivity: Equatable, Sendable {
    case online
    case offline
}

public enum CaptureImportBlocker: Equatable, Sendable {
    case providerSecret(retryAfterSeconds: Int?)
}

public struct CaptureImportPlan: Equatable {
    public let requestBuilder: APIRequestBuilder?
    public let offlineRetryMutation: NativeQueuedMutation?
    public let blocker: CaptureImportBlocker?
    public let importedRecipeRoute: AppRoute?
    public let drainedClientMutationID: String?
    public let captureDraftAfterCompletion: CaptureDraft?
    public let userFacingMessage: String

    public init(
        requestBuilder: APIRequestBuilder? = nil,
        offlineRetryMutation: NativeQueuedMutation? = nil,
        blocker: CaptureImportBlocker? = nil,
        importedRecipeRoute: AppRoute? = nil,
        drainedClientMutationID: String? = nil,
        captureDraftAfterCompletion: CaptureDraft? = nil,
        userFacingMessage: String
    ) {
        self.requestBuilder = requestBuilder
        self.offlineRetryMutation = offlineRetryMutation
        self.blocker = blocker
        self.importedRecipeRoute = importedRecipeRoute
        self.drainedClientMutationID = drainedClientMutationID
        self.captureDraftAfterCompletion = captureDraftAfterCompletion
        self.userFacingMessage = userFacingMessage
    }
}

public struct CaptureImportViewModel: Equatable {
    public let draft: CaptureDraft
    public let connectivity: CaptureImportConnectivity
    public let pendingRetryMutation: NativeQueuedMutation?

    public init(
        draft: CaptureDraft,
        connectivity: CaptureImportConnectivity,
        pendingRetryMutation: NativeQueuedMutation? = nil
    ) {
        self.draft = draft
        self.connectivity = connectivity
        self.pendingRetryMutation = pendingRetryMutation
    }

    public func planSubmit(clientMutationID: String, createdAt: String) throws -> CaptureImportPlan {
        let mutation: NativeQueuedMutation
        if let pendingRetryMutation {
            mutation = pendingRetryMutation
        } else {
            mutation = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: clientMutationID,
                createdAt: createdAt
            )
        }

        switch connectivity {
        case .offline:
            return CaptureImportPlan(
                offlineRetryMutation: mutation,
                captureDraftAfterCompletion: draft,
                userFacingMessage: "Working offline. Import will retry when Spoonjoy reconnects."
            )
        case .online:
            return CaptureImportPlan(
                requestBuilder: try mutation.requestBuilder(),
                captureDraftAfterCompletion: draft,
                userFacingMessage: "Importing recipe."
            )
        }
    }

    public func planImportResult(
        _ response: RecipeImportResponse,
        clientMutationID: String,
        createdAt _: String
    ) throws -> CaptureImportPlan {
        if let blocker = Self.providerSecretBlocker(in: response) {
            return CaptureImportPlan(
                blocker: blocker,
                captureDraftAfterCompletion: draft,
                userFacingMessage: "ProviderSecret is required before Spoonjoy can finish this import."
            )
        }

        if let recipe = response.recipe {
            return CaptureImportPlan(
                importedRecipeRoute: .recipeDetail(id: recipe.id, presentation: .detail),
                drainedClientMutationID: clientMutationID,
                captureDraftAfterCompletion: nil,
                userFacingMessage: "Imported \(recipe.title)."
            )
        }

        return CaptureImportPlan(
            captureDraftAfterCompletion: draft,
            userFacingMessage: response.importCode ?? "Import did not return a recipe."
        )
    }

    private static func providerSecretBlocker(in response: RecipeImportResponse) -> CaptureImportBlocker? {
        for blocker in response.blockers ?? [] {
            guard case .object(let object) = blocker,
                  object["capability"] == .string("ProviderSecret") else {
                continue
            }
            return .providerSecret(retryAfterSeconds: object["retryAfterSeconds"]?.intValue)
        }
        return nil
    }
}
