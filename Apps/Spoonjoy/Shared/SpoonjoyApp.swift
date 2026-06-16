import SwiftUI

struct SpoonjoyRootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Kitchen") {
                    Label("Spoonjoy", systemImage: "fork.knife")
                    Text("Native shell ready")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Spoonjoy")
        }
    }
}
