import SpoonjoyCore
import SwiftUI

struct OfflineStatusView: View {
    let state: OfflineState

    var body: some View {
        Label(state.statusLabel, systemImage: symbol)
            .font(KitchenTableTheme.bodyNote)
            .foregroundStyle(foregroundStyle)
            .padding(.vertical, 4)
            .accessibilityLabel(state.statusLabel)
    }

    private var symbol: String {
        switch state {
        case .available:
            "externaldrive.badge.checkmark"
        case .unavailable:
            "externaldrive.badge.xmark"
        }
    }

    private var foregroundStyle: Color {
        switch state {
        case .available:
            KitchenTableTheme.herb
        case .unavailable:
            KitchenTableTheme.tomato
        }
    }
}
