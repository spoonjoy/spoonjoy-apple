import SwiftUI

struct KitchenSafeControls: View {
    let canGoBack: Bool
    let canAdvance: Bool
    let previous: () -> Void
    let markComplete: () -> Void
    let advance: () -> Void

    var body: some View {
        KitchenSafeControlDeck(
            canGoBack: canGoBack,
            canAdvance: canAdvance,
            previous: previous,
            markComplete: markComplete,
            advance: advance
        )
    }
}

struct KitchenSafeControlDeck: View {
    let canGoBack: Bool
    let canAdvance: Bool
    let previous: () -> Void
    let markComplete: () -> Void
    let advance: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                backStepAction
                primaryStepAction
                nextStepAction
            }

            VStack(alignment: .leading, spacing: 10) {
                primaryStepAction
                secondaryStepActions
            }
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                backStepAction
                nextStepAction
            }
            VStack(alignment: .leading, spacing: 10) {
                backStepAction
                nextStepAction
            }
        }
    }

    private var backStepAction: some View {
        Button(action: previous) {
            Label("Back step", systemImage: "chevron.backward.circle")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .quiet))
        .disabled(!canGoBack)
        .accessibilityLabel("Move to the previous step")
    }

    private var nextStepAction: some View {
        Button(action: advance) {
            Label("Next step", systemImage: "arrow.forward.circle")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        .disabled(!canAdvance)
        .accessibilityLabel("Move to the next step")
    }
}
