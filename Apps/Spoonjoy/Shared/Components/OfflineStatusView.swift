import SpoonjoyCore
import SwiftUI

struct OfflineStatusView: View {
    enum Prominence {
        case standard
        case quiet
    }

    let display: OfflineIndicatorDisplay
    let prominence: Prominence?
    var onDismiss: (@MainActor @Sendable () -> Void)?

    init(
        display: OfflineIndicatorDisplay,
        prominence: Prominence? = nil,
        onDismiss: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.display = display
        self.prominence = prominence
        self.onDismiss = onDismiss
    }

    init(
        indicator: OfflineIndicatorState,
        prominence: Prominence? = nil,
        onDismiss: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.init(display: indicator.display, prominence: prominence, onDismiss: onDismiss)
    }

    var body: some View {
        if display.isVisible {
            HStack(spacing: 8) {
                Label(visibleLabel, systemImage: symbol)
                    .font(statusFont)
                    .foregroundStyle(foregroundStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .accessibilityLabel(label)

                if display.informationalOnly, display != .synced {
                    if let onDismiss {
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Hide offline status")
                    }
                }
            }
            .padding(.vertical, effectiveProminence == .quiet ? 2 : 4)
        }
    }

    private var visibleLabel: String {
        guard effectiveProminence == .quiet else {
            return label
        }

        switch display {
        case .offline:
            return "Saved copy"
        case .stale:
            return "Saved copy may be stale"
        default:
            return label
        }
    }

    private var statusFont: Font {
        switch effectiveProminence {
        case .standard:
            KitchenTableTheme.bodyNote
        case .quiet:
            KitchenTableTheme.uiLabel
        }
    }

    private var effectiveProminence: Prominence {
        prominence ?? (display.informationalOnly ? .quiet : .standard)
    }

    private var label: String {
        switch display {
        case .synced:
            "Saved for offline"
        case .offline:
            "Showing saved kitchen"
        case .stale:
            "Saved kitchen may be out of date"
        case .dismissed:
            "Offline status hidden"
        case .queuedWork(let count, _):
            "\(count) \(count == 1 ? "change" : "changes") waiting to sync"
        case .syncFailure:
            "Sync needs another try"
        case .conflict:
            "Changes need review"
        case .blocker(let blocker):
            switch blocker {
            case .providerSecret:
                "Recipe import setup needed"
            case .appleDeveloperProgram:
                "Apple Developer Program required"
            }
        case .destructiveConfirmation:
            "Confirmation required"
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
            effectiveProminence == .quiet ? quietInformationalForegroundStyle : KitchenTableTheme.brass
        case .dismissed:
            KitchenTableTheme.charcoal.opacity(0.7)
        case .queuedWork:
            KitchenTableTheme.charcoal
        case .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            KitchenTableTheme.tomato
        }
    }

    private var quietInformationalForegroundStyle: Color {
        KitchenTableTheme.inkMuted
    }
}

#if DEBUG
extension OfflineStatusView {
    static var screenshotAccessibilityProof: [String: Any] {
        let visibleProbeDisplays: [(name: String, display: OfflineIndicatorDisplay)] = [
            ("offline", .offline),
            ("stale", .stale(domain: .recipeCatalog)),
            ("queuedWork", .queuedWork(count: 2, oldestClientMutationID: "cm_accessibility_probe")),
            ("syncFailure", .syncFailure(errorID: "sync_accessibility_probe", retryAfter: nil)),
            ("conflict", .conflict(recordID: "recipe_accessibility_probe", mutationID: "cm_conflict_probe")),
            ("blocker", .blocker(.appleDeveloperProgram(capability: "apns-device-registration"))),
            ("destructiveConfirmation", .destructiveConfirmation(actionID: "delete-accessibility-probe"))
        ]
        let hiddenProbeDisplays: [(name: String, display: OfflineIndicatorDisplay)] = [
            ("synced", .synced),
            ("dismissed", .dismissed(previous: .offline, reason: .informationalOnly))
        ]
        let dismissibleStates = visibleProbeDisplays
            .filter { $0.display.informationalOnly && $0.display != .synced }
            .map(\.name)
        let severeStates = visibleProbeDisplays
            .filter { !$0.display.informationalOnly }
            .map(\.name)

        return [
            "source": "OfflineStatusView",
            "visibleStates": visibleProbeDisplays.filter { $0.display.isVisible }.map(\.name),
            "dismissibleStates": dismissibleStates,
            "severeStates": severeStates,
            "hiddenStates": hiddenProbeDisplays.filter { !$0.display.isVisible }.map(\.name),
            "voiceOverLabel": true,
            "dismissButtonLabel": "Hide offline status",
            "severityCorrect": dismissibleStates == ["offline", "stale"] &&
                severeStates == ["queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation"]
        ]
    }
}
#endif
