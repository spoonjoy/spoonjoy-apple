import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SpoonjoyCore

@Suite("Recipe editor reordering and photo on create")
struct RecipeEditorReorderTests {
    private static func ingredient(_ id: String, _ name: String? = nil) -> RecipeEditorIngredientDraft {
        RecipeEditorIngredientDraft(id: id, name: name ?? id, quantity: 1, unit: "cup")
    }

    private static func step(_ id: String, num: Int, ingredients: [RecipeEditorIngredientDraft] = [], uses: [Int] = []) -> RecipeEditorStepDraft {
        RecipeEditorStepDraft(id: id, stepNum: num, title: nil, description: "Do \(id).", duration: nil, ingredients: ingredients, outputStepNums: uses)
    }

    private static func draft(_ steps: [RecipeEditorStepDraft], recipeID: String? = "recipe_1") -> RecipeEditorDraft {
        RecipeEditorDraft(recipeID: recipeID, currentChefID: "chef_ari", title: "Pasta", description: nil, servings: nil, steps: steps)
    }

    private static func plan(original: RecipeEditorDraft, draft: RecipeEditorDraft) -> [RecipeEditorAction] {
        RecipeEditorDraftChangePlanner.actions(original: original, draft: draft, clientMutationID: { "cm_\($0)" })
    }

    // MARK: Step moves

    @Test("moving a step renumbers every step and its output uses")
    func movingAStepRenumbers() {
        var draft = Self.draft([Self.step("a", num: 1), Self.step("b", num: 2), Self.step("c", num: 3, uses: [2])])
        #expect(draft.moveStep(id: "c", by: -1) == .blocked("Step 2 feeds step 3, so step 2 has to stay before it. Clear \"Uses Output From\" first to move it."))
        #expect(draft.steps.map(\.id) == ["a", "b", "c"])

        #expect(draft.moveStep(id: "a", by: 1) == .moved)
        #expect(draft.steps.map(\.id) == ["b", "a", "c"])
        #expect(draft.steps.map(\.stepNum) == [1, 2, 3])
        #expect(draft.steps[2].outputStepNums == [1])
    }

    @Test("a step cannot move past the step that uses its output")
    func stepCannotMovePastDependent() {
        var draft = Self.draft([Self.step("a", num: 1), Self.step("b", num: 2, uses: [1])])
        let outcome = draft.moveStep(id: "a", by: 1)
        #expect(outcome == .blocked("Step 1 feeds step 2, so step 1 has to stay before it. Clear \"Uses Output From\" first to move it."))
        #expect(draft.steps.map(\.id) == ["a", "b"])
    }

    @Test("moves that change nothing are reported as unchanged")
    func unchangedMoves() {
        var draft = Self.draft([Self.step("a", num: 1, ingredients: [Self.ingredient("i1")]), Self.step("b", num: 2)])
        #expect(draft.moveStep(id: "a", by: -1) == .unchanged)
        #expect(draft.moveStep(id: "b", by: 1) == .unchanged)
        #expect(draft.moveStep(id: "a", by: 0) == .unchanged)
        #expect(draft.moveStep(id: "missing", by: 1) == .unchanged)
        #expect(draft.moveSteps(fromOffsets: IndexSet(integer: 0), toOffset: 1) == .unchanged)
    }

    @Test("onMove offsets move one or several steps")
    func onMoveOffsets() {
        var draft = Self.draft([Self.step("a", num: 1), Self.step("b", num: 2), Self.step("c", num: 3), Self.step("d", num: 4)])
        #expect(draft.moveSteps(fromOffsets: IndexSet(integer: 0), toOffset: 3) == .moved)
        #expect(draft.steps.map(\.id) == ["b", "c", "a", "d"])
        #expect(draft.moveSteps(fromOffsets: IndexSet([0, 3]), toOffset: 2) == .moved)
        #expect(draft.steps.map(\.id) == ["c", "b", "d", "a"])
        #expect(draft.steps.map(\.stepNum) == [1, 2, 3, 4])
    }

    // MARK: Planner

    @Test("swapping two steps saves the new order")
    func swapSavesOrder() {
        let original = Self.draft([Self.step("a", num: 1), Self.step("b", num: 2)])
        var edited = original
        edited.moveStep(id: "b", by: -1)
        let actions = Self.plan(original: original, draft: edited)
        #expect(actions.contains(.reorderStep(stepID: "b", toStepNum: 1, clientMutationID: "cm_reorder-step-b-1")))
        #expect(applyReorders(actions, to: ["a", "b"]) == ["b", "a"])
    }

    @Test("every permutation of four steps ends in the draft's order")
    func everyPermutationEndsInDraftOrder() {
        let ids = ["a", "b", "c", "d"]
        let original = Self.draft(ids.enumerated().map { Self.step($1, num: $0 + 1) })
        for permutation in ids.permutations() {
            var edited = original
            edited.steps = permutation.map { id in original.steps.first { $0.id == id }! }
            edited.renumberStepsPreservingOutputIdentities()
            let actions = Self.plan(original: original, draft: edited)
            #expect(applyReorders(actions, to: ids) == permutation, "order \(permutation)")
        }
    }

    @Test("a step whose number is unchanged still gets a move when earlier moves displace it")
    func displacedStepIsMoved() {
        // c stays number 2... after a moves, c would shift: [b, c, a] to [c, b, a] with b at 2 unchanged.
        let original = Self.draft([Self.step("a", num: 1), Self.step("b", num: 2), Self.step("c", num: 3)])
        var edited = original
        edited.steps = [original.steps[2], original.steps[1], original.steps[0]]
        edited.renumberStepsPreservingOutputIdentities()
        #expect(applyReorders(Self.plan(original: original, draft: edited), to: ["a", "b", "c"]) == ["c", "b", "a"])
    }

    @Test("new steps and deleted steps keep the saved order consistent")
    func createdAndDeletedSteps() {
        let original = Self.draft([Self.step("a", num: 1), Self.step("b", num: 2), Self.step("c", num: 3)])
        var edited = original
        edited.steps = [Self.step("new", num: 1), original.steps[2], original.steps[0]]
        edited.renumberStepsPreservingOutputIdentities()
        let actions = Self.plan(original: original, draft: edited)
        #expect(actions.contains(.deleteStep(stepID: "b", clientMutationID: "cm_delete-step-b", confirmation: .confirmed)))
        #expect(actions.contains { if case .createStep = $0 { true } else { false } })
        // After the delete and the create (inserted at 1), the server holds new, a, c. c has to move to 2.
        #expect(actions.contains(.reorderStep(stepID: "c", toStepNum: 2, clientMutationID: "cm_reorder-step-c-2")))
    }

    @Test("an unchanged recipe plans only the recipe save")
    func unchangedPlansOnlySave() {
        let original = Self.draft([Self.step("a", num: 1, ingredients: [Self.ingredient("i1")]), Self.step("b", num: 2)])
        #expect(Self.plan(original: original, draft: original) == [.save(clientMutationID: "cm_recipe-save")])
    }

    // MARK: Photo on create

    @Test("the create response yields the recipe id")
    func createResponseRecipeID() {
        #expect(RecipeCreateResponse.recipeID(from: .object(["recipe": .object(["id": .string("recipe_9")])])) == "recipe_9")
        #expect(RecipeCreateResponse.recipeID(from: .object(["recipeId": .string("recipe_8")])) == "recipe_8")
        #expect(RecipeCreateResponse.recipeID(from: .object(["recipe": .object(["id": .string("")]), "recipeId": .string("recipe_7")])) == "recipe_7")
        #expect(RecipeCreateResponse.recipeID(from: .object(["recipe": .object([:])])) == nil)
        #expect(RecipeCreateResponse.recipeID(from: .object(["recipeId": .string("")])) == nil)
        #expect(RecipeCreateResponse.recipeID(from: .array([])) == nil)
    }

    @MainActor
    @Test("a created recipe uploads its photo as the active cover")
    func photoUploadsAsActiveCover() async throws {
        let photo = try Self.photo()
        let uploaded = UploadedPlans()
        let result = try await RecipeCreateWithPhoto.run(
            photo: photo,
            clientMutationID: { "\($0)-1" },
            create: { "recipe_new" },
            upload: { await uploaded.record($0.remoteRequestBuilder) }
        )
        #expect(result == .uploaded(recipeID: "recipe_new"))
        #expect(result.route == .recipes)
        let requests = await uploaded.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.method == .post)
        #expect(request.pathComponents == ["api", "v1", "recipes", "recipe_new", "image"])
        let bodyData = try #require(request.body)
        let body = try #require(String(data: bodyData, encoding: .isoLatin1))
        #expect(Self.fieldValue("activateWhenReady", in: body) == "true")
        #expect(Self.fieldValue("postAsSpoon", in: body) == "false")
        #expect(Self.fieldValue("generateEditorial", in: body) == "false")
    }

    @MainActor
    @Test("a failed upload keeps the recipe and the photo, and a retry can finish it")
    func failedUploadKeepsRecipe() async throws {
        let photo = try Self.photo()
        let result = try await RecipeCreateWithPhoto.run(
            photo: photo,
            clientMutationID: { "\($0)-1" },
            create: { "recipe_new" },
            upload: { _ in throw TestFailure() }
        )
        guard case .photoPending(let pending) = result else {
            Issue.record("Expected a pending upload; got \(result)")
            return
        }
        #expect(pending.recipeID == "recipe_new")
        #expect(pending.photo == photo)
        #expect(pending.message == PendingRecipeCoverUpload.failureMessage)
        #expect(result.route == .recipeDetail(id: "recipe_new", presentation: .detail))

        let stillFailing = await RecipeCreateWithPhoto.retry(pending, clientMutationID: { "\($0)-2" }, upload: { _ in throw TestFailure() })
        #expect(stillFailing == .photoPending(pending))
        let uploaded = UploadedPlans()
        let finished = await RecipeCreateWithPhoto.retry(pending, clientMutationID: { "\($0)-3" }, upload: { await uploaded.record($0.remoteRequestBuilder) })
        #expect(finished == .uploaded(recipeID: "recipe_new"))
        #expect(await uploaded.requests.count == 1)
    }

    @MainActor
    @Test("a photo that cannot be prepared for upload stays pending instead of crashing")
    func unpreparablePhotoStaysPending() async throws {
        let bad = NativeStagedMediaUpload(localStageID: "bad", fileName: "cover.jpg", contentType: "image/jpeg", data: Data([1, 2, 3]))
        let result = try await RecipeCreateWithPhoto.run(
            photo: bad,
            clientMutationID: { $0 },
            create: { "recipe_new" },
            upload: { _ in }
        )
        #expect(result == .photoPending(PendingRecipeCoverUpload(recipeID: "recipe_new", photo: bad)))
    }

    @MainActor
    @Test("a create that fails leaves the editor as it was, and one without an id has nowhere to put the photo")
    func createFailureAndMissingID() async throws {
        let photo = try Self.photo()
        await #expect(throws: TestFailure.self) {
            _ = try await RecipeCreateWithPhoto.run(photo: photo, clientMutationID: { $0 }, create: { throw TestFailure() }, upload: { _ in })
        }
        let result = try await RecipeCreateWithPhoto.run(photo: photo, clientMutationID: { $0 }, create: { nil }, upload: { _ in })
        #expect(result == .createdWithoutID)
        #expect(result.route == .recipes)
    }

    // MARK: Helpers

    private static func photo() throws -> NativeStagedMediaUpload {
        let width = 8
        let height = 8
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.9, green: 0.4, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return NativeStagedMediaUpload(localStageID: "stage_photo", fileName: "cover.jpg", contentType: "image/jpeg", data: data as Data)
    }

    private static func fieldValue(_ name: String, in body: String) -> String? {
        guard let start = body.range(of: "name=\"\(name)\"\r\n\r\n") else {
            return nil
        }
        return body[start.upperBound...].components(separatedBy: "\r\n").first
    }

    /// Plays the reorder actions on a server list the way the API does: remove the step, insert it at the position.
    private func applyReorders(_ actions: [RecipeEditorAction], to start: [String]) -> [String] {
        var order = start
        for action in actions {
            guard case .reorderStep(let id, let toStepNum, _) = action,
                  let from = order.firstIndex(of: id) else {
                continue
            }
            order.remove(at: from)
            order.insert(id, at: min(toStepNum - 1, order.count))
        }
        return order
    }
}

private struct TestFailure: Error {}

private actor UploadedPlans {
    private(set) var requests: [APIRequestBuilder] = []
    func record(_ request: APIRequestBuilder?) { requests.append(contentsOf: request.map { [$0] } ?? []) }
}

private extension Array where Element == String {
    func permutations() -> [[String]] {
        guard count > 1 else { return [self] }
        return indices.flatMap { index -> [[String]] in
            var rest = self
            let head = rest.remove(at: index)
            return rest.permutations().map { [head] + $0 }
        }
    }

}

@Suite("Journey photo fixture")
struct NativeJourneyPhotoFixtureTests {
    @Test("the launch environment key turns the fixture on")
    func environmentKey() {
        #expect(NativeJourneyPhotoFixture.isRequested(environment: [NativeJourneyPhotoFixture.environmentKey: " TRUE "]))
        #expect(NativeJourneyPhotoFixture.isRequested(environment: [NativeJourneyPhotoFixture.environmentKey: "1"]))
        #expect(!NativeJourneyPhotoFixture.isRequested(environment: [NativeJourneyPhotoFixture.environmentKey: "0"]))
        #expect(!NativeJourneyPhotoFixture.isRequested(environment: [:]))
    }

    @Test("the fixture is a JPEG the cover preparation accepts")
    func fixtureIsPreparable() throws {
        let upload = NativeJourneyPhotoFixture.stagedUpload()
        #expect(upload.contentType == "image/jpeg")
        #expect(upload.data.prefix(2) == Data([0xFF, 0xD8]))
        _ = try RecipeCoverImageNormalizer().normalize(upload: upload)
    }
}
