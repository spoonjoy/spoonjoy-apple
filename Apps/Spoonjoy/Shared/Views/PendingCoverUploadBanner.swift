import OuroHX
import SwiftUI

/// Shown above a recipe page when the photo chosen while creating the recipe did not upload.
/// The recipe is saved; Retry sends the same photo again.
struct PendingCoverUploadBanner: View {
    let message: String
    let isRetrying: Bool
    let retry: @MainActor () async -> Void
    let dismiss: @MainActor () -> Void

    var body: some View {
        OuroBanner(message, tone: .destructive, icon: .system("exclamationmark.triangle")) {
            HStack(spacing: 12) {
                OuroButton("Retry Upload", systemImage: "arrow.clockwise", size: .sm, loading: isRetrying, loadingLabel: "Retrying upload") {
                    Task { @MainActor in
                        await retry()
                    }
                }
                .accessibilityIdentifier("recipe.coverUpload.retry")
                OuroButton("Dismiss", tone: .secondary, variant: .outline, size: .sm) {
                    dismiss()
                }
                .disabled(isRetrying)
                .accessibilityIdentifier("recipe.coverUpload.dismiss")
            }
        }
        .accessibilityIdentifier("recipe.coverUpload.status")
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.page)
    }
}
