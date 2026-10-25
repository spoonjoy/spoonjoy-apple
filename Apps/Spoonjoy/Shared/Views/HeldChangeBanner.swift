import SpoonjoyCore
import SwiftUI

/// Shown above a recipe page when the server turned down a saved edit. The edit stays in the queue with the
/// server's message; Retry sends it again, Discard removes it and every queued edit that depends on it.
///
/// When the recipe was changed somewhere else in a field the edit changes too, the banner shows both versions
/// of each such field instead, and the cook keeps one: their own edit, or the version saved elsewhere.
struct HeldChangeBanner: View {
    let message: String
    let editConflict: NativeRecipeEditConflict?
    let retry: @MainActor () async -> Void
    let discard: @MainActor () async -> Void
    let resolve: @MainActor (NativeRecipeEditChoice) async -> Void

    @State private var isWorking = false

    init(
        message: String,
        editConflict: NativeRecipeEditConflict? = nil,
        retry: @escaping @MainActor () async -> Void,
        discard: @escaping @MainActor () async -> Void,
        resolve: @escaping @MainActor (NativeRecipeEditChoice) async -> Void = { _ in }
    ) {
        self.message = message
        self.editConflict = editConflict
        self.retry = retry
        self.discard = discard
        self.resolve = resolve
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                editConflict == nil ? "A change to this recipe was not saved" : "This recipe changed somewhere else",
                systemImage: "exclamationmark.triangle"
            )
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.tomato)
            .accessibilityIdentifier("recipe.heldChange.title")
            // A conflict's heading already says the recipe changed somewhere else, so the body only asks for
            // the choice instead of repeating it.
            Text(editConflict == nil ? message : NativeRecipeEditConflict.choicePrompt)
                .font(KitchenTableTheme.bodyNote)
                .accessibilityIdentifier("recipe.heldChange.message")
            if let editConflict {
                ForEach(editConflict.fields, id: \.field) { field in
                    ConflictFieldComparison(field: field)
                }
                HStack(spacing: 12) {
                    Button {
                        run { await resolve(.mine) }
                    } label: {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text("Keep My Edit")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                    .accessibilityIdentifier("recipe.heldChange.keepMine")
                    Button("Use Saved Version") {
                        run { await resolve(.theirs) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                    .accessibilityIdentifier("recipe.heldChange.useTheirs")
                }
                .font(KitchenTableTheme.uiLabel)
            } else {
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.page)
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

/// One field changed both here and elsewhere: the cook's value above the value saved elsewhere.
private struct ConflictFieldComparison: View {
    let field: NativeRecipeEditConflict.Field

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.field.label)
                .font(KitchenTableTheme.uiLabel)
            version("Yours", value: field.mine, identifier: "mine")
            version("Saved elsewhere", value: field.theirs, identifier: "theirs")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recipe.heldChange.field.\(field.field.rawValue)")
    }

    private func version(_ title: String, value: String?, identifier: String) -> some View {
        Text("\(Text("\(title):").bold()) \(value ?? "(empty)")")
            .font(KitchenTableTheme.bodyNote)
            // Both versions wrap in full; a cut-off title would hide the difference the cook is choosing between.
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("recipe.heldChange.field.\(field.field.rawValue).\(identifier)")
    }
}
