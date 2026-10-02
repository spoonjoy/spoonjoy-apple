import SpoonjoyCore
import SwiftUI

/// Adds pull-to-refresh that first runs the shell's sync (when the shell provides one through the
/// environment) and then reloads this screen's own data.
private struct ReloadsOnPullModifier: ViewModifier {
    @Environment(\.refresh) private var shellRefresh
    let reload: @MainActor () async -> Void

    func body(content: Content) -> some View {
        content.refreshable {
            await shellRefresh?()
            await reload()
        }
    }
}

/// Adds pull-to-refresh to routes the policy lists, running `action` (the shell sync).
private struct ShellRefreshModifier: ViewModifier {
    let route: AppRoute
    let action: @MainActor () async -> Void

    func body(content: Content) -> some View {
        if PullToRefreshPolicy.supportsPullToRefresh(route) {
            content.refreshable { await action() }
        } else {
            content
        }
    }
}

extension View {
    /// Pull to refresh: runs the shell sync, then `reload`.
    func reloadsOnPull(_ reload: @escaping @MainActor () async -> Void) -> some View {
        modifier(ReloadsOnPullModifier(reload: reload))
    }

    /// Pull to refresh for the routes `PullToRefreshPolicy` lists.
    func shellRefreshable(for route: AppRoute, action: @escaping @MainActor () async -> Void) -> some View {
        modifier(ShellRefreshModifier(route: route, action: action))
    }
}
