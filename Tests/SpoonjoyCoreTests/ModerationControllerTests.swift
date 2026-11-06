import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Moderation controller: report, block and unblock reach the server and the device ledger")
@MainActor
struct ModerationControllerTests {
    private static let chef = BlockedChef(id: "chef_sam", username: "sam")
    private static let recipe = ContentReportTarget(type: .recipe, id: "recipe_1")

    private final class Recorder {
        var sent: [(String, SettingsActionResponseHandling)] = []
        var blocks: [ChefBlock] = []
        var error: Error?
    }

    private static func controller(_ directory: URL, recorder: Recorder) -> ModerationController {
        ModerationController(store: ChefModerationLedgerStore(directoryURL: directory)) { request, handling in
            recorder.sent.append(("\(request.method.rawValue) /\(request.pathComponents.joined(separator: "/"))", handling))
            if let error = recorder.error { throw error }
            return handling == .captureChefBlocks ? .chefBlocks(recorder.blocks) : nil
        }
    }

    private static func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("moderation-controller-\(UUID().uuidString)")
    }

    @Test("a report hides the recipe, a block hides the chef, and both outlive the controller")
    func reportBlockPersist() async throws {
        let directory = Self.directory()
        let recorder = Recorder()
        let moderation = Self.controller(directory, recorder: recorder)
        moderation.useAccount("chef_me")
        moderation.useAccount("chef_me")

        try await moderation.report(Self.recipe, reason: .spam, details: nil)
        #expect(moderation.ledger.hiddenNotice(recipeID: "recipe_1", chefID: "chef_sam", chefUsername: "sam")
            == ModerationHiddenNotice(message: "You reported this recipe, so it's hidden for you.", unblockChef: nil))

        try await moderation.block(Self.chef, from: Self.recipe)
        let notice = moderation.ledger.hiddenNotice(recipeID: "recipe_2", chefID: "chef_sam", chefUsername: "sam")
        #expect(notice?.message == "You blocked @sam, so their recipes are hidden.")
        #expect(notice?.unblockChef == Self.chef)
        #expect(moderation.ledger.hiddenNotice(recipeID: "recipe_3", chefID: "chef_ann", chefUsername: "ann") == nil)

        let reopened = Self.controller(directory, recorder: recorder)
        reopened.useAccount("chef_me")
        #expect(reopened.ledger.isBlocked(chefID: "chef_sam"))
        #expect(reopened.ledger.isHidden(Self.recipe))

        try await reopened.unblock(chefID: "chef_sam")
        #expect(!reopened.ledger.isBlocked(chefID: "chef_sam"))
        #expect(recorder.sent.map(\.0) == ["POST /api/v1/reports", "POST /api/v1/blocks", "DELETE /api/v1/blocks/chef_sam"])
        #expect(recorder.sent.allSatisfy { $0.1 == .refreshInBackground })
    }

    @Test("signing out empties the ledger on screen and keeps the account's ledger on disk")
    func signOutEmptiesLedger() async throws {
        let directory = Self.directory()
        let moderation = Self.controller(directory, recorder: Recorder())
        moderation.useAccount("chef_me")
        try await moderation.block(Self.chef, from: nil)
        moderation.useAccount(nil)
        #expect(moderation.accountID == nil)
        #expect(!moderation.ledger.isBlocked(chefID: "chef_sam"))
        moderation.useAccount("chef_me")
        #expect(moderation.ledger.isBlocked(chefID: "chef_sam"))
    }

    @Test("refreshing blocks replaces the ledger's list, and with no account nothing is saved")
    func refreshAndSignedOut() async throws {
        let directory = Self.directory()
        let recorder = Recorder()
        recorder.blocks = [ChefBlock(chef: Self.chef, createdAt: "2026-11-05T00:00:00Z")]
        let moderation = Self.controller(directory, recorder: recorder)

        #expect(!moderation.canModerate(chefID: "chef_sam", isOwner: false))
        try await moderation.refreshBlocks()
        #expect(moderation.ledger.blockedChefs == [Self.chef])
        #expect(!FileManager.default.fileExists(atPath: directory.path))

        moderation.useAccount("chef_me")
        #expect(moderation.canModerate(chefID: "chef_sam", isOwner: false))
        #expect(!moderation.canModerate(chefID: "chef_sam", isOwner: true))
        #expect(!moderation.canModerate(chefID: "chef_me", isOwner: false))
        recorder.blocks = []
        try await moderation.refreshBlocks()
        #expect(moderation.ledger.blockedChefs.isEmpty)

        let silent = ModerationController(store: ChefModerationLedgerStore(directoryURL: directory)) { _, _ in nil }
        try await silent.refreshBlocks()
        #expect(silent.ledger.blockedChefs.isEmpty)
    }

    @Test("a failed request changes nothing and explains itself")
    func failures() async {
        let recorder = Recorder()
        recorder.error = APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let moderation = Self.controller(Self.directory(), recorder: recorder)
        moderation.useAccount("chef_me")
        await #expect(throws: APITransportError.self) { try await moderation.block(Self.chef, from: nil) }
        #expect(!moderation.ledger.isBlocked(chefID: "chef_sam"))

        #expect(ModerationController.failureMessage(recorder.error!, action: "block") == "Connect to the internet to block.")
        let refused = APITransportError(
            kind: .apiError, requestID: "r", statusCode: 409,
            apiError: APIError(requestID: "r", code: "conflict", message: "Already blocked", status: 409),
            retryDecision: .doNotRetry
        )
        #expect(ModerationController.failureMessage(refused, action: "block") == "Already blocked")
        #expect(ModerationController.failureMessage(CocoaError(.fileNoSuchFile), action: "report") == "Spoonjoy couldn't report. Try again.")
    }

    @Test("a prompt names its kind, and the sheets read their copy from Core")
    func prompts() {
        let report = ModerationPrompt(kind: .report(Self.recipe, subject: "this recipe"))
        let block = ModerationPrompt(kind: .block(Self.chef, from: Self.recipe))
        #expect(report.id == "report-recipe-recipe_1")
        #expect(block.id == "block-chef_sam")
        #expect(report.reportTarget?.subject == "this recipe")
        #expect(block.reportTarget == nil)
        #expect(block.blockedChef == Self.chef)
        #expect(report.blockedChef == nil)
        #expect(block.blockedFrom == Self.recipe)
        #expect(report.blockedFrom == nil)
        #expect(ModerationPrompt.reportThanks == "Thanks — we review reports within 24 hours.")
        #expect(ModerationPrompt.blockTitle(Self.chef) == "Block @sam?")
        #expect(ModerationPrompt.blockTitle(nil) == "Block chef?")
    }
}
