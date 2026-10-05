import Foundation

/// A photo the chef picked while creating a recipe whose upload has not succeeded yet.
/// The recipe itself is saved; the page for that recipe shows `message` with a retry.
public struct PendingRecipeCoverUpload: Equatable, Sendable {
    public static let failureMessage = "Your recipe is saved, but its photo did not upload."

    public let recipeID: String
    public let photo: NativeStagedMediaUpload
    public let message: String

    public init(recipeID: String, photo: NativeStagedMediaUpload, message: String = PendingRecipeCoverUpload.failureMessage) {
        self.recipeID = recipeID
        self.photo = photo
        self.message = message
    }

    /// The same upload the cover controls make: the photo becomes the active cover, the way the web
    /// editor makes a photo chosen on create the cover. Nothing else is posted with it.
    public func uploadPlan(clientMutationID: String) throws -> RecipeCoverControlsMutationPlan {
        try RecipeCoverControlsMutationPlan.plan(
            .uploadPhoto(
                photo: photo,
                activateWhenReady: true,
                generateEditorial: false,
                postAsSpoon: false,
                note: nil,
                nextTime: nil,
                cookedAt: nil,
                clientMutationID: clientMutationID
            ),
            recipeID: recipeID,
            connectivity: .online
        )
    }
}

public enum RecipeCreateResponse {
    /// The new recipe's ID from the create response: `recipe.id`, or a top-level `recipeId`.
    public static func recipeID(from response: JSONValue) -> String? {
        guard case .object(let object) = response else {
            return nil
        }
        if case .object(let recipe)? = object["recipe"], case .string(let id)? = recipe["id"], !id.isEmpty {
            return id
        }
        if case .string(let id)? = object["recipeId"], !id.isEmpty {
            return id
        }
        return nil
    }
}

public enum RecipeCreateWithPhotoResult: Equatable, Sendable {
    /// The recipe exists and the photo is its cover.
    case uploaded(recipeID: String)
    /// The recipe exists but the photo did not upload; keep `pending` so the chef can retry.
    case photoPending(PendingRecipeCoverUpload)
    /// The create response had no recipe ID, so the photo has nowhere to go.
    case createdWithoutID

    public var route: AppRoute {
        switch self {
        case .uploaded, .createdWithoutID:
            .recipes
        case .photoPending(let pending):
            .recipeDetail(id: pending.recipeID, presentation: .detail)
        }
    }
}

@MainActor
public enum RecipeCreateWithPhoto {
    /// Creates the recipe, then uploads the photo as its cover. A create that throws leaves the editor
    /// as it was. An upload that throws never loses the recipe: it comes back as `.photoPending`.
    public static func run(
        photo: NativeStagedMediaUpload,
        clientMutationID: (String) -> String,
        create: () async throws -> String?,
        upload: (RecipeCoverControlsMutationPlan) async throws -> Void
    ) async throws -> RecipeCreateWithPhotoResult {
        guard let recipeID = try await create() else {
            return .createdWithoutID
        }
        let pending = PendingRecipeCoverUpload(recipeID: recipeID, photo: photo)
        return await retry(pending, clientMutationID: clientMutationID, upload: upload)
    }

    /// Uploads a pending photo again. Returns `.uploaded` or the same photo still pending.
    public static func retry(
        _ pending: PendingRecipeCoverUpload,
        clientMutationID: (String) -> String,
        upload: (RecipeCoverControlsMutationPlan) async throws -> Void
    ) async -> RecipeCreateWithPhotoResult {
        do {
            try await upload(try pending.uploadPlan(clientMutationID: clientMutationID("cover-upload")))
            return .uploaded(recipeID: pending.recipeID)
        } catch {
            return .photoPending(pending)
        }
    }
}
