import Foundation

/// What the root view shows for a bootstrap state.
///
/// Every state that has a kitchen to show maps to the single `.kitchen` case, so the root view builds the
/// navigation shell in one place. SwiftUI keys a view's identity to its position in the view builder: when each
/// state had its own branch, a sync moving the app from "queued" to "synced" swapped one branch for another and
/// threw away the tab paths, the search text and every child view's state.
public enum NativeShellPresentation: Equatable, Sendable {
    case signedOut
    case restoring
    case kitchen
    case settingsAfterSyncFailure(message: String)
    case syncFailed(message: String)
}

extension NativeShellContentState {
    /// True when there is something in the kitchen worth showing instead of a full-screen status page.
    public var hasRenderableKitchenContent: Bool {
        !recipes.isEmpty ||
            !cookbooks.isEmpty ||
            !(shoppingList?.activeItems.isEmpty ?? true)
    }
}

extension NativeAppBootstrapState {
    public func shellPresentation(isShowingSettings: Bool) -> NativeShellPresentation {
        switch self {
        case .signedOut:
            return .signedOut
        case .restoringCache:
            return .restoring
        // One case per state, rather than one comma-joined case, so the scenario verifier's source checks can find
        // every kitchen state by name.
        case .liveSynced:
            return .kitchen
        case .offlineStale:
            return .kitchen
        case .queuedWork:
            return .kitchen
        case .conflict:
            return .kitchen
        case .blocker:
            return .kitchen
        case .destructiveConfirmation:
            return .kitchen
        case .syncFailed(let contentState, let message):
            if isShowingSettings {
                return .settingsAfterSyncFailure(message: message)
            }
            return contentState.hasRenderableKitchenContent ? .kitchen : .syncFailed(message: message)
        }
    }
}
