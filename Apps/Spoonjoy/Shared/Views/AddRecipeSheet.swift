import Foundation
import SwiftUI

/// Where a new recipe comes from. Spoonjoy has no recipe form: this sheet teaches the ways in and takes a pasted
/// link, which becomes a capture draft in Imports.
struct AddRecipeSheet: View {
    /// The App Shortcut phrase for `CaptureRecipeIntent` in `SpoonjoyAppShortcuts`, with the app name filled in.
    static let siriPhrase = "Save a recipe to Spoonjoy"

    let onPasteLink: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
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

                    AddRecipeWayRow(systemImage: "mic", title: "Tell Siri") {
                        Text("Say \u{201C}\(Self.siriPhrase)\u{201D}, then give it the link or the recipe.")
                    }
                    .accessibilityIdentifier("addRecipe.siri")

                    Divider().overlay(KitchenTableTheme.hairline)

                    AddRecipeWayRow(systemImage: "sparkles", title: "Ask Claude") {
                        // A literal, so SwiftUI renders the Markdown link to the web's connector page.
                        Text("Connect Claude to Spoonjoy and say \u{201C}Put this in Spoonjoy\u{201D}. [How to connect](https://spoonjoy.app/mcp)")
                    }
                    .accessibilityIdentifier("addRecipe.claude")

                    Divider().overlay(KitchenTableTheme.hairline)

                    AddRecipeWayRow(systemImage: "square.and.arrow.up", title: "Share from Safari") {
                        Text("Tap Share, choose Copy, and paste the link below.")
                    }
                    .accessibilityIdentifier("addRecipe.share")

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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    linkField
                    importButton
                        .fixedSize()
                }
                VStack(alignment: .leading, spacing: 10) {
                    linkField
                    importButton
                }
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
        .disabled(Self.recipeLink(from: link) == nil)
        .accessibilityIdentifier("addRecipe.import")
    }

    private func importLink() {
        guard let url = Self.recipeLink(from: link) else {
            return
        }
        isLinkFocused = false
        dismiss()
        onPasteLink(url)
    }

    /// A web link worth importing: http or https with a host. Anything else keeps Import disabled.
    static func recipeLink(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty else {
            return nil
        }
        return url
    }
}

/// One way into Spoonjoy: a tinted symbol tile, a title and a line of how-to.
private struct AddRecipeWayRow<Detail: View>: View {
    let systemImage: String
    let title: String
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
                Text(title)
                    .font(KitchenTableTheme.control)
                    .foregroundStyle(KitchenTableTheme.ink)
                detail()
                    .font(KitchenTableTheme.meta)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
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
