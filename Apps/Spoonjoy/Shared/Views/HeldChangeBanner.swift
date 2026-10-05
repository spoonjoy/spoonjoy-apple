import SwiftUI

/// Shown above a recipe page when the server turned down a saved edit. The edit stays in the queue with the
/// server's message; Retry sends it again, Discard removes it and every queued edit that depends on it.
struct HeldChangeBanner: View {
    let message: String
    let retry: @MainActor () async -> Void
    let discard: @MainActor () async -> Void

    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("A change to this recipe was not saved", systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.tomato)
                .accessibilityIdentifier("recipe.heldChange.title")
            Text(message)
                .font(KitchenTableTheme.bodyNote)
                .accessibilityIdentifier("recipe.heldChange.message")
            HStack(spacing: 12) {
                Button {
                    run(retry)
                } label: {
                    if isWorking {
                        ProgressView()
                    } else {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
                .accessibilityIdentifier("recipe.heldChange.retry")
                Button("Discard Change") {
                    run(discard)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)
                .accessibilityIdentifier("recipe.heldChange.discard")
            }
            .font(KitchenTableTheme.uiLabel)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.bone)
        .accessibilityElement(children: .contain)
    }

    private func run(_ action: @escaping @MainActor () async -> Void) {
        isWorking = true
        Task { @MainActor in
            await action()
            isWorking = false
        }
    }
}
