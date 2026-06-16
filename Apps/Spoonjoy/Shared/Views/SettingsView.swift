import SpoonjoyCore
import SwiftUI

struct SettingsView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Status") {
                ForEach(viewModel.rows, id: \.id) { row in
                    LabeledContent(row.title, value: row.value)
                }
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
                OfflineStatusView(state: settings.offline)
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
}
