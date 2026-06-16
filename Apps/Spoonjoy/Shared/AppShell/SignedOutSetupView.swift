import SwiftUI

struct SignedOutSetupView: View {
    let openCapture: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spoonjoy")
                    .font(.largeTitle)
                Text("Open your kitchen, keep offline fixtures nearby, and connect spoonjoy.app when sign-in is ready.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Capture Draft", action: openCapture)
                    .buttonStyle(.borderedProminent)
                Button("Settings", action: openSettings)
                    .buttonStyle(.bordered)
                Link("spoonjoy.app", destination: URL(string: "https://spoonjoy.app") ?? URL(fileURLWithPath: "/"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
