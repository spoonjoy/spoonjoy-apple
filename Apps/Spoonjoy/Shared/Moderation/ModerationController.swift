import Foundation
import SpoonjoyCore
import SwiftUI

// `ModerationController` lives in SpoonjoyCore so Ouro Reins drives the same report and block path headless.

extension ModerationController {
    /// A preview and test stand-in that never reaches the network.
    nonisolated static let inert = ModerationController(
        store: ChefModerationLedgerStore(directoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-moderation-inert")),
        send: { _, _ in nil }
    )
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
