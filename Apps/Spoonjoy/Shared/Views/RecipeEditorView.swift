import SpoonjoyCore
import SwiftUI

struct RecipeEditorView: View {
    let viewModel: RecipeEditorViewModel
    let mutationDidPlan: (RecipeEditorMutationPlan) -> Void
    let close: (AppRoute) -> Void

    @State private var draft: RecipeEditorDraft
    @State private var blockedMessage: String?
    @State private var showDeleteConfirmation = false

    init(
        viewModel: RecipeEditorViewModel,
        mutationDidPlan: @escaping (RecipeEditorMutationPlan) -> Void,
        close: @escaping (AppRoute) -> Void
    ) {
        self.viewModel = viewModel
        self.mutationDidPlan = mutationDidPlan
        self.close = close
        _draft = State(initialValue: viewModel.draft)
    }

    var body: some View {
        Form {
            if let blockedMessage {
                Label(blockedMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(KitchenTableTheme.tomato)
            }

            if let conflictBanner = viewModel.conflictBanner {
                Section("Conflict") {
                    Text(conflictBanner.title)
                        .font(.headline)
                    Text(conflictBanner.message)
                        .font(KitchenTableTheme.bodyNote)
                    HStack {
                        Button("Review") {}
                        Button("Keep Draft") {}
                    }
                }
            }

            Section("Recipe") {
                TextField("Title", text: $draft.title)
                TextEditor(text: descriptionText)
                    .frame(minHeight: 88)
                TextField("Servings", text: servingsText)
            }

            Section("Steps") {
                ForEach($draft.steps) { $step in
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Step title", text: optionalText($step.title))
                        TextEditor(text: $step.description)
                            .frame(minHeight: 72)
                        Stepper(value: durationBinding($step.duration), in: 0...7200, step: 30) {
                            Text("Duration \(step.duration ?? 0) seconds")
                        }

                        ForEach($step.ingredients) { $ingredient in
                            HStack {
                                TextField("Ingredient", text: $ingredient.name)
                                Stepper(value: $ingredient.quantity, in: 0...100, step: 0.25) {
                                    Text(ingredient.quantity.formatted(.number.precision(.fractionLength(0...2))))
                                }
                                TextField("Unit", text: optionalText($ingredient.unit))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onMove { indices, newOffset in
                    draft.steps.move(fromOffsets: indices, toOffset: newOffset)
                    renumberSteps()
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark.circle")
                }
                .disabled(!viewModel.updatingDraft(draft).canSubmit)

                if draft.recipeID != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .confirmationDialog(viewModel.deleteConfirmationTitle, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Recipe", role: .destructive) {
                deleteRecipe()
            }
            Button("Cancel", role: .cancel) {}
        }
        .safeAreaInset(edge: .bottom) {
            OfflineStatusView(display: viewModel.offlineIndicator.display)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .background(KitchenTableTheme.bone.opacity(0.94))
        }
    }

    private var descriptionText: Binding<String> {
        optionalText($draft.description)
    }

    private var servingsText: Binding<String> {
        optionalText($draft.servings)
    }

    private func optionalText(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { nextValue in
                value.wrappedValue = optionalString(nextValue)
            }
        )
    }

    private func durationBinding(_ value: Binding<Int?>) -> Binding<Int> {
        Binding(
            get: { value.wrappedValue ?? 0 },
            set: { nextValue in
                value.wrappedValue = nextValue == 0 ? nil : nextValue
            }
        )
    }

    private func save() {
        plan(.save(clientMutationID: clientMutationID("recipe-save")))
    }

    private func deleteRecipe() {
        plan(.deleteRecipe(clientMutationID: clientMutationID("recipe-delete"), confirmation: .confirmed))
    }

    private func plan(_ action: RecipeEditorAction) {
        do {
            let plan = try viewModel.updatingDraft(draft).plan(action)
            if let blockedReason = plan.blockedReason {
                blockedMessage = blockedReason
                return
            }
            blockedMessage = nil
            mutationDidPlan(plan)
            if let successRoute = plan.successRoute {
                close(successRoute)
            }
        } catch {
            blockedMessage = "Recipe editor action could not be prepared."
        }
    }

    private func renumberSteps() {
        for index in draft.steps.indices {
            draft.steps[index].stepNum = index + 1
        }
    }

    private func clientMutationID(_ prefix: String) -> String {
        "\(prefix)-\(Date().timeIntervalSince1970.formatted(.number.precision(.fractionLength(0))))"
    }

    private func optionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private typealias EditorSafetyControls = KitchenSafeControls
private struct ConfirmationDialogAnchor {}
