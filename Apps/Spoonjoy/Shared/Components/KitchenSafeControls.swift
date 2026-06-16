import SwiftUI

struct KitchenSafeControls: View {
    let canAdvance: Bool
    let markComplete: () -> Void
    let advance: () -> Void
    let close: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                markCompleteButton
                advanceButton
                closeButton
            }

            VStack(spacing: 12) {
                markCompleteButton
                advanceButton
                closeButton
            }
        }
        .controlSize(.large)
        .labelStyle(.titleAndIcon)
    }

    private var markCompleteButton: some View {
        Button(action: markComplete) {
            Label("Done", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(KitchenTableTheme.herb)
        .accessibilityLabel("Mark the current step done")
    }

    private var advanceButton: some View {
        Button(action: advance) {
            Label("Next", systemImage: "arrow.forward.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!canAdvance)
        .accessibilityLabel("Move to the next step")
    }

    private var closeButton: some View {
        Button(action: close) {
            Label("Recipe", systemImage: "text.book.closed")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Return to recipe detail")
    }
}
