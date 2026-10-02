import SpoonjoyCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Keeps the screen from auto-locking while the view is visible and the app is active.
/// The idle timer is restored when the view disappears, the app leaves the foreground, or the view is removed.
private struct KeepScreenAwakeModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                apply()
            }
            .onDisappear {
                isVisible = false
                apply()
            }
            .onChange(of: scenePhase) { _, _ in
                apply()
            }
    }

    private func apply() {
#if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = CookModeScreenAwakePolicy.shouldKeepScreenAwake(
            isCookModeVisible: isVisible,
            isAppActive: scenePhase == .active
        )
#endif
    }
}

extension View {
    /// Disables auto-lock while this view is on screen and the app is active.
    func keepsScreenAwake() -> some View {
        modifier(KeepScreenAwakeModifier())
    }
}
