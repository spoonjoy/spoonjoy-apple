import Foundation
import SpoonjoyCore
import SwiftUI

/// Paste a block of ingredient text, review the parsed rows (quantity, unit, name), edit them, then add them to a step.
struct IngredientPasteSheet: View {
    let stepNumber: Int
    let makeLocalID: () -> String
    let onAdd: ([RecipeEditorIngredientDraft]) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @State private var rows: [RecipeEditorIngredientDraft] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Step \(stepNumber) ingredient text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 110)
                        .accessibilityIdentifier("editor.paste.text")
                        .onChange(of: text) { _, newValue in
                            rows = IngredientTextParser.parse(newValue).map {
                                RecipeEditorIngredientDraft(id: makeLocalID(), parsed: $0)
                            }
                        }
                    Text("One ingredient per line, like 2 cups rice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Preview") {
                    if rows.isEmpty {
                        Text("Parsed ingredients appear here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach($rows) { $row in
                        let number = (rows.firstIndex { $0.id == row.id } ?? 0) + 1
                        HStack {
                            TextField("Quantity", value: $row.quantity, format: .number.precision(.fractionLength(0...3)))
                                .frame(width: 56)
                                .accessibilityIdentifier("editor.paste.row.\(number).quantity")
                            TextField("Unit", text: unitBinding($row.unit))
                                .frame(width: 64)
                                .accessibilityIdentifier("editor.paste.row.\(number).unit")
                            TextField("Ingredient", text: $row.name)
                                .accessibilityIdentifier("editor.paste.row.\(number).name")
                            Button(role: .destructive) {
                                rows.removeAll { $0.id == row.id }
                            } label: {
                                Label("Remove Row", systemImage: "minus.circle")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Paste")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("editor.paste.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(rows.count == 1 ? "Add 1 Ingredient" : "Add \(rows.count) Ingredients") {
                        onAdd(rows.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                    }
                    .disabled(rows.isEmpty)
                    .accessibilityIdentifier("editor.paste.add")
                }
            }
        }
    }

    private func unitBinding(_ unit: Binding<String?>) -> Binding<String> {
        Binding(get: { unit.wrappedValue ?? "" }, set: { unit.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
