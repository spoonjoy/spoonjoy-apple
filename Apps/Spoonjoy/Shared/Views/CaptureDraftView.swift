import Foundation
import SpoonjoyCore
import SwiftUI

struct CaptureDraftView: View {
    @State private var rawText: String
    @State private var viewModel: CaptureDraftViewModel?
    private let draftDidChange: (CaptureDraftViewModel) -> Void

    init(
        viewModel: CaptureDraftViewModel?,
        draftDidChange: @escaping (CaptureDraftViewModel) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        _rawText = State(initialValue: viewModel?.draft.rawText ?? "")
        self.draftDidChange = draftDidChange
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Capture")
                    .font(KitchenTableTheme.displayTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)

                TextEditor(text: $rawText)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
                    .overlay {
                        RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                            .stroke(KitchenTableTheme.brass.opacity(0.22))
                    }
                    .accessibilityLabel("local draft text")

                Button {
                    createLocalDraft()
                } label: {
                    Label("Save Draft", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let viewModel {
                    draftPreview(viewModel)
                }
            }
            .padding()
        }
        .background(KitchenTableTheme.bone)
    }

    private func createLocalDraft() {
        guard
            let draft = try? CaptureDraft.localText(
                id: "draft-local-\(abs(rawText.hashValue))",
                rawText: rawText,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        else {
            return
        }

        let nextViewModel = CaptureDraftViewModel(draft: draft)
        viewModel = nextViewModel
        draftDidChange(nextViewModel)
    }

    private func draftPreview(_ viewModel: CaptureDraftViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Local Draft", systemImage: "doc.text")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
            ForEach(viewModel.previewLines, id: \.self) { line in
                Text(line)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.charcoal)
            }
            Label(
                viewModel.canCreateServerRecipe ? "Promotion requires a separate reviewed flow" : "Local-only until sync is built",
                systemImage: viewModel.canCreateServerRecipe ? "lock.open" : "iphone"
            )
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.bone)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(KitchenTableTheme.brass.opacity(0.24))
                .frame(height: 1)
        }
    }
}
