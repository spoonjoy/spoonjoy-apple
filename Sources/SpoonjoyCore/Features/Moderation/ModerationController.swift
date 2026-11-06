import Foundation
import Observation

/// Report and block for the whole app (App Review guideline 1.2). Blocked and reported content leaves the screen
/// at once from the device ledger; the server filters it from feeds after the refresh the request triggers.
///
/// The app hands it to every view through the environment; Ouro Reins drives the same controller headless.
@MainActor @Observable
public final class ModerationController {
    public typealias Send = @MainActor (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?

    public private(set) var ledger = ChefModerationLedger()
    public private(set) var accountID: String?
    private let store: ChefModerationLedgerStore
    private let send: Send

    public nonisolated init(store: ChefModerationLedgerStore, send: @escaping Send) {
        self.store = store
        self.send = send
    }

    public func useAccount(_ accountID: String?) {
        guard accountID != self.accountID else { return }
        self.accountID = accountID
        ledger = accountID.map(store.load(accountID:)) ?? ChefModerationLedger()
    }

    public func report(_ target: ContentReportTarget, reason: ContentReportReason, details: String?) async throws {
        _ = try await send(try ModerationRequests.report(target: target, reason: reason, details: details), .refreshInBackground)
        update { $0.hide(target) }
    }

    public func block(_ chef: BlockedChef, from target: ContentReportTarget?) async throws {
        _ = try await send(try ModerationRequests.block(chefID: chef.id), .refreshInBackground)
        update { $0.block(chef, from: target) }
    }

    public func unblock(chefID: String) async throws {
        _ = try await send(ModerationRequests.unblock(chefID: chefID), .refreshInBackground)
        update { $0.unblock(chefID: chefID) }
    }

    public func refreshBlocks() async throws {
        if case .chefBlocks(let blocks)? = try await send(ModerationRequests.blocks(), .captureChefBlocks) {
            update { $0.replaceBlocks(with: blocks) }
        }
    }

    /// Report and block appear on other chefs' content once someone is signed in.
    public func canModerate(chefID: String, isOwner: Bool) -> Bool {
        guard let accountID else { return false }
        return !isOwner && chefID != accountID
    }

    private func update(_ change: (inout ChefModerationLedger) -> Void) {
        change(&ledger)
        guard let accountID else { return }
        try? store.save(ledger, accountID: accountID)
    }

    /// What to tell the person when a report or block fails.
    public static func failureMessage(_ error: Error, action: String) -> String {
        if let transportError = error as? APITransportError, transportError.isOffline {
            return "Connect to the internet to \(action)."
        }
        return SettingsActionFailureMessage.serverMessage(for: error) ?? "Spoonjoy couldn't \(action). Try again."
    }
}

/// A report or block the person asked for from a menu, waiting for the sheet or confirmation that finishes it.
public struct ModerationPrompt: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case report(ContentReportTarget, subject: String)
        case block(BlockedChef, from: ContentReportTarget)
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public var id: String {
        switch kind {
        case .report(let target, _): "report-\(target.type.rawValue)-\(target.id)"
        case .block(let chef, _): "block-\(chef.id)"
        }
    }

    public var reportTarget: (target: ContentReportTarget, subject: String)? {
        if case .report(let target, let subject) = kind { return (target, subject) }
        return nil
    }

    public var blockedChef: BlockedChef? {
        if case .block(let chef, _) = kind { return chef }
        return nil
    }

    public var blockedFrom: ContentReportTarget? {
        if case .block(_, let target) = kind { return target }
        return nil
    }

    /// The report sheet's thanks once the report is sent.
    public static let reportThanks = "Thanks — we review reports within 24 hours."

    /// The block confirmation's title.
    public static func blockTitle(_ chef: BlockedChef?) -> String {
        chef.map { "Block \($0.name)?" } ?? "Block chef?"
    }
}

/// What a recipe page shows in place of a recipe the person reported or whose chef they blocked.
public struct ModerationHiddenNotice: Equatable, Sendable {
    public let message: String
    /// The chef to offer Unblock for, when the recipe is hidden because they are blocked.
    public let unblockChef: BlockedChef?

    public init(message: String, unblockChef: BlockedChef?) {
        self.message = message
        self.unblockChef = unblockChef
    }
}

extension ChefModerationLedger {
    /// The notice a loaded recipe page shows instead of the recipe, or nil when the recipe shows.
    public func hiddenNotice(recipeID: String, chefID: String, chefUsername: String) -> ModerationHiddenNotice? {
        guard hidesRecipe(id: recipeID, chefID: chefID) else {
            return nil
        }
        if isBlocked(chefID: chefID) {
            return ModerationHiddenNotice(
                message: "You blocked @\(chefUsername), so their recipes are hidden.",
                unblockChef: blockedChefs.first { $0.id == chefID }
            )
        }
        return ModerationHiddenNotice(message: "You reported this recipe, so it's hidden for you.", unblockChef: nil)
    }
}
