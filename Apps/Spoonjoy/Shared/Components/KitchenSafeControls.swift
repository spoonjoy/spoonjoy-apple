import OuroHX
import SwiftUI

struct KitchenSafeControls: View {
    let canAdvance: Bool
    let markComplete: () -> Void
    let advance: () -> Void
    let close: () -> Void

    var body: some View {
        KitchenSafeControlDeck(
            canAdvance: canAdvance,
            markComplete: markComplete,
            advance: advance,
            close: close
        )
    }
}

struct KitchenSafeControlDeck: View {
    let canAdvance: Bool
    let markComplete: () -> Void
    let advance: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            primaryStepAction
            secondaryStepActions
        }
        .font(KitchenTableTheme.uiLabel)
        .controlSize(.large)
    }

    private var primaryStepAction: some View {
        Button(action: markComplete) {
            Label("Mark done", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(.ouro(.solid, fullWidth: true))
        .accessibilityLabel("Mark the current step done")
        .accessibilityHint("Mark this cooking step complete.")
    }

    private var secondaryStepActions: some View {
        HStack(spacing: 10) {
            Button(action: advance) {
                Label("Next step", systemImage: "arrow.forward.circle")
            }
            .buttonStyle(.ouro(.outline, tone: .secondary, fullWidth: true))
            .disabled(!canAdvance)
            .accessibilityLabel("Move to the next step")
            .accessibilityIdentifier("cookMode.next")

            Button(action: close) {
                Label("Close", systemImage: "text.book.closed")
            }
            .buttonStyle(.ouro(.plain, tone: .secondary, fullWidth: true))
            .accessibilityLabel("Return to recipe detail")
        }
    }
}
