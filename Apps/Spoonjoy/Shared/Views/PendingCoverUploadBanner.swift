import SwiftUI

/// Shown above a recipe page when the photo chosen while creating the recipe did not upload.
/// The recipe is saved; Retry sends the same photo again.
struct PendingCoverUploadBanner: View {
    let message: String
    let isRetrying: Bool
    let retry: @MainActor () async -> Void
    let dismiss: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.tomato)
                .accessibilityIdentifier("recipe.coverUpload.status")
            HStack(spacing: 12) {
                Button {
                    Task { @MainActor in
                        await retry()
                    }
                } label: {
                    if isRetrying {
                        ProgressView()
                    } else {
                        Label("Retry Upload", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetrying)
                .accessibilityIdentifier("recipe.coverUpload.retry")
                Button("Dismiss") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isRetrying)
                .accessibilityIdentifier("recipe.coverUpload.dismiss")
            }
            .font(KitchenTableTheme.uiLabel)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.bone)
        .accessibilityElement(children: .contain)
    }
}
