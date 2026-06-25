import SpoonjoyCore
import SwiftUI

struct SettingsView: View {
    let viewModel: SettingsViewModel
    var onDismissOfflineIndicator: () -> Void = {}

    var body: some View {
        Form {
            Section("Status") {
                ForEach(viewModel.rows, id: \.id) { row in
                    LabeledContent(row.title, value: row.value)
                }
            }

            Section("Session") {
                LabeledContent("Auth", value: authSummary)
                LabeledContent("Environment", value: viewModel.environmentSwitcher.rawValue)
            }

            Section("Shopping") {
                Label(
                    viewModel.canReadShoppingList ? "Shopping read enabled" : "Shopping read unavailable",
                    systemImage: viewModel.canReadShoppingList ? "checkmark.circle" : "xmark.circle"
                )
                Label(
                    viewModel.canWriteShoppingList ? "Shopping write enabled" : "Shopping write unavailable",
                    systemImage: viewModel.canWriteShoppingList ? "checkmark.circle" : "xmark.circle"
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
