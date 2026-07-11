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
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
        .accessibilityLabel("Mark the current step done")
        .accessibilityHint("Mark this cooking step complete.")
    }

    private var secondaryStepActions: some View {
        HStack(spacing: 10) {
            Button(action: advance) {
                Label("Next step", systemImage: "arrow.forward.circle")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            .disabled(!canAdvance)
            .accessibilityLabel("Move to the next step")

            Button(action: close) {
                Label("Close", systemImage: "text.book.closed")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
            .accessibilityLabel("Return to recipe detail")
        }
    }
}
