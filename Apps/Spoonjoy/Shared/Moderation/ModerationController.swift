import Foundation
import Observation
import SpoonjoyCore
import SwiftUI

/// Report and block for the whole app (App Review guideline 1.2). Blocked and reported content leaves the screen
/// at once from the device ledger; the server filters it from feeds after the refresh the request triggers.
@MainActor @Observable
final class ModerationController {
    typealias Send = @MainActor (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?

    private(set) var ledger = ChefModerationLedger()
    private(set) var accountID: String?
    private let store: ChefModerationLedgerStore
    private let send: Send

    nonisolated init(store: ChefModerationLedgerStore, send: @escaping Send) {
        self.store = store
        self.send = send
    }

    /// A preview and test stand-in that never reaches the network.
    nonisolated static let inert = ModerationController(
        store: ChefModerationLedgerStore(directoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-moderation-inert")),
        send: { _, _ in nil }
    )

    func useAccount(_ accountID: String?) {
        guard accountID != self.accountID else { return }
        self.accountID = accountID
        ledger = accountID.map(store.load(accountID:)) ?? ChefModerationLedger()
    }

    func report(_ target: ContentReportTarget, reason: ContentReportReason, details: String?) async throws {
        _ = try await send(try ModerationRequests.report(target: target, reason: reason, details: details), .refreshOnly)
        update { $0.hide(target) }
    }

    func block(_ chef: BlockedChef, from target: ContentReportTarget?) async throws {
        _ = try await send(try ModerationRequests.block(chefID: chef.id), .refreshOnly)
        update { $0.block(chef, from: target) }
    }

    func unblock(chefID: String) async throws {
        _ = try await send(ModerationRequests.unblock(chefID: chefID), .refreshOnly)
        update { $0.unblock(chefID: chefID) }
    }

    func refreshBlocks() async throws {
        if case .chefBlocks(let blocks)? = try await send(ModerationRequests.blocks(), .captureChefBlocks) {
            update { $0.replaceBlocks(with: blocks) }
        }
    }

    private func update(_ change: (inout ChefModerationLedger) -> Void) {
        change(&ledger)
        guard let accountID else { return }
        try? store.save(ledger, accountID: accountID)
    }

    /// What to tell the person when a report or block fails.
    static func failureMessage(_ error: Error, action: String) -> String {
        if let transportError = error as? APITransportError, transportError.isOffline {
            return "Connect to the internet to \(action)."
        }
        return SettingsActionFailureMessage.serverMessage(for: error) ?? "Spoonjoy couldn't \(action). Try again."
    }
}

private struct ModerationControllerKey: EnvironmentKey {
    static let defaultValue = ModerationController.inert
}

extension EnvironmentValues {
    var moderation: ModerationController {
        get { self[ModerationControllerKey.self] }
        set { self[ModerationControllerKey.self] = newValue }
    }
}
