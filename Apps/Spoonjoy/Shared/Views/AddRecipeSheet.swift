import Foundation
import SpoonjoyCore
import SwiftUI

/// Where a new recipe comes from. Spoonjoy has no recipe form: this sheet teaches the ways in and takes a pasted
/// link, which becomes a capture draft in Imports.
struct AddRecipeSheet: View {
    /// The web's page for connecting Claude to Spoonjoy.
    static let claudeConnectorURL = URL(string: "https://spoonjoy.app/mcp")!

    let onPasteLink: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var link = ""
    @FocusState private var isLinkFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("You don't type it in. Pick whichever is closest.")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 8)

                    AddRecipeWayRow(systemImage: "mic", title: "Tell Siri", identifier: "addRecipe.siri") {
                        Text("Say \u{201C}\(AddRecipeCopy.siriPhrase)\u{201D}, then give it the link or the recipe.")
                    }

                    Divider().overlay(KitchenTableTheme.hairline)

                    AddRecipeWayRow(
                        systemImage: "sparkles",
                        title: "Ask Claude",
                        identifier: "addRecipe.claude",
                        link: AddRecipeWayLink(title: "How to connect", destination: Self.claudeConnectorURL, identifier: "addRecipe.claude.connect")
                    ) {
                        Text("Connect Claude to Spoonjoy and say \u{201C}Put this in Spoonjoy\u{201D}.")
                    }

                    Divider().overlay(KitchenTableTheme.hairline)

                    AddRecipeWayRow(systemImage: "square.and.arrow.up", title: "Share from Safari", identifier: "addRecipe.share") {
                        Text("Tap Share, choose Copy, and paste the link below.")
                    }

                    pasteField
                        .padding(.top, 16)
                }
                .padding(.horizontal, KitchenTableTheme.pagePadding)
                .padding(.bottom, KitchenTableTheme.pagePadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(KitchenTableTheme.page.ignoresSafeArea())
            .tint(KitchenTableTheme.action)
            .navigationTitle("Add a recipe")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .accessibilityIdentifier("addRecipe.close")
                }
            }
        }
        .presentationDetents([.large])
#if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
#endif
    }

    private var pasteField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste a link")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.ink2)
            // One field in one layout: swapping layouts while typing would swap fields and drop focus.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                linkField
                importButton
                    .fixedSize()
            }
        }
    }

    private var linkField: some View {
        TextField("https://", text: $link)
            .font(KitchenTableTheme.bodyNote)
            .foregroundStyle(KitchenTableTheme.ink)
            .textContentType(.URL)
            .autocorrectionDisabled()
#if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
#endif
            .submitLabel(.go)
            .focused($isLinkFocused)
            .onSubmit(importLink)
            .padding(.horizontal, 16)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget + 6)
            .background(KitchenTableTheme.vellum, in: Capsule())
            .accessibilityLabel("Recipe link")
            .accessibilityIdentifier("addRecipe.link")
    }

    private var importButton: some View {
        Button(action: importLink) {
            Label("Import", systemImage: "tray.and.arrow.down")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
        .disabled(AddRecipeCopy.recipeLink(from: link) == nil)
        .accessibilityIdentifier("addRecipe.import")
    }

    private func importLink() {
        guard let url = AddRecipeCopy.recipeLink(from: link) else {
            return
        }
        isLinkFocused = false
        dismiss()
        onPasteLink(url)
    }
}

private struct AddRecipeWayLink {
    let title: String
    let destination: URL
    let identifier: String
}

/// One way into Spoonjoy: a tinted symbol tile, a title and a line of how-to, with an optional link under it.
/// The title and how-to read as one element; the link stays its own, so VoiceOver and Switch Control reach it.
private struct AddRecipeWayRow<Detail: View>: View {
    let systemImage: String
    let title: String
    let identifier: String
    var link: AddRecipeWayLink? = nil
    @ViewBuilder let detail: () -> Detail

    @ScaledMetric(relativeTo: .title2) private var tileSize: CGFloat = 52

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.brass)
                .frame(width: tileSize, height: tileSize)
                .background(KitchenTableTheme.vellum, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(KitchenTableTheme.control)
                        .foregroundStyle(KitchenTableTheme.ink)
                    detail()
                        .font(KitchenTableTheme.meta)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(identifier)
                if let link {
                    Link(link.title, destination: link.destination)
                        .font(KitchenTableTheme.meta.weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.brass)
                        .frame(minHeight: KitchenTableTheme.minimumTouchTarget, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier(link.identifier)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
    }
}

private struct SpoonjoyAddRecipeFocusedKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    /// Opens Add a recipe in the focused window; the Mac's ⌘N command calls it.
    var spoonjoyAddRecipe: (() -> Void)? {
        get { self[SpoonjoyAddRecipeFocusedKey.self] }
        set { self[SpoonjoyAddRecipeFocusedKey.self] = newValue }
    }
}
