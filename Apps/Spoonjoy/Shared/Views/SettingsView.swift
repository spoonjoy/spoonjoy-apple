import SpoonjoyCore
import SwiftUI

struct SettingsView: View {
    let viewModel: SettingsViewModel
    var onDismissOfflineIndicator: () -> Void = {}

    var body: some View {
        Form {
            Section("Status") {
                ForEach(settings.statusRows, id: \.id) { row in
                    LabeledContent(row.title, value: row.value)
                }
            }

            Section("Session") {
                LabeledContent("Auth", value: authSummary)
                LabeledContent("Environment", value: viewModel.environmentSwitcher.rawValue)
            }

            Section("Shopping") {
                Label(
                    settings.canReadShoppingList ? "Shopping read enabled" : "Shopping read unavailable",
                    systemImage: settings.canReadShoppingList ? "checkmark.circle" : "xmark.circle"
                )
                Label(
                    settings.canWriteShoppingList ? "Shopping write enabled" : "Shopping write unavailable",
                    systemImage: settings.canWriteShoppingList ? "checkmark.circle" : "xmark.circle"
                )
            }

            Section("Offline") {
                OfflineStatusView(display: viewModel.offlineIndicatorDisplay) {
                    _ = viewModel.dismissOfflineIndicator
                    onDismissOfflineIndicator()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .tint(KitchenTableTheme.herb)
    }

    private var settings: SettingsState {
        viewModel.settings
    }

    private var authSummary: String {
        switch viewModel.authSessionState {
        case .signedOut:
            "Signed out"
        case .authenticated:
            "Signed in"
        case .refreshRequired:
            "Refresh required"
        }
    }
}
