import SpoonjoyCore
import SwiftUI

struct OfflineStatusView: View {
    let display: OfflineIndicatorDisplay
    var onDismiss: (() -> Void)?

    init(display: OfflineIndicatorDisplay, onDismiss: (() -> Void)? = nil) {
        self.display = display
        self.onDismiss = onDismiss
    }

    var body: some View {
        if !isDismissed {
            HStack(spacing: 8) {
                Label(label, systemImage: symbol)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(foregroundStyle)
                    .accessibilityLabel(label)

                if display.informationalOnly, display != .synced {
                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide offline status")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var label: String {
        switch display {
        case .synced:
            "Offline cache ready"
        case .offline:
            "Working offline"
        case .stale:
            "Offline cache may be stale"
        case .dismissed:
            "Offline status hidden"
        case .queuedWork(let count, _):
            "\(count) offline \(count == 1 ? "change" : "changes") queued"
        case .syncFailure:
            "Sync needs attention"
        case .conflict:
            "Offline conflict needs review"
        case .blocker:
            "Provider secret required"
        case .destructiveConfirmation:
            "Confirmation required"
        }
    }

    private var isDismissed: Bool {
        switch display {
        case .dismissed:
            true
        case .synced, .offline, .stale, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            false
        }
    }

    private var symbol: String {
        switch display {
        case .synced:
            "externaldrive.badge.checkmark"
        case .offline:
            "wifi.slash"
        case .stale:
            "clock.badge.exclamationmark"
        case .dismissed:
            "xmark.circle"
        case .queuedWork:
            "tray.and.arrow.up.fill"
        case .syncFailure:
            "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        case .conflict:
            "exclamationmark.triangle.fill"
        case .blocker:
            "lock.shield.fill"
        case .destructiveConfirmation:
            "trash.slash.fill"
        }
    }

    private var foregroundStyle: Color {
        switch display {
        case .synced:
            KitchenTableTheme.herb
        case .offline, .stale:
            KitchenTableTheme.brass
        case .dismissed:
            KitchenTableTheme.charcoal.opacity(0.7)
        case .queuedWork:
            KitchenTableTheme.charcoal
        case .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            KitchenTableTheme.tomato
        }
    }
}
