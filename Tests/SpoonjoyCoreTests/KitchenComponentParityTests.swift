import Foundation
import Testing

/// Native's ingredient rows, checks and section headers take web's look (parity 1.2, Task 8): a serif name with its
/// aisle in muted serif under it and the amount on the right, a brass check with a bone tick, and one section header
/// (eyebrow, Fraunces title with tracked meta at the trailing edge, a full-width rule under it). These read the
/// views' source, as the repo's other view contracts do, because SwiftUI views can't be built in this test target.
@Suite("Kitchen components match web")
struct KitchenComponentParityTests {
    static let views = "Apps/Spoonjoy/Shared/Views"
    static let components = "Apps/Spoonjoy/Shared/Components"

    @Test("a checked ingredient is a brass circle with a bone tick, on every checklist")
    func testCheckedIngredientUsesBrass() throws {
        let mark = try Self.source("\(Self.components)/KitchenCheckMark.swift")
        #expect(mark.contains(#"isChecked ? "checkmark.circle.fill" : "circle""#))
        #expect(mark.contains(".symbolRenderingMode(.palette)"))
        // Palette layers: the tick (bone once checked) first, then the brass disc.
        #expect(mark.contains(".foregroundStyle(isChecked ? KitchenTableTheme.onInk : KitchenTableTheme.brass, KitchenTableTheme.brass)"))
        #expect(!mark.contains("herb"), "Herb is for cooked and finished, not a checked ingredient.")
        #expect(!mark.contains(".opacity("), "The mark takes palette colours as they are.")

        let rows = [
            try Self.declaration("struct RecipeSpreadIngredientRow", in: "\(Self.views)/RecipeDetailView.swift"),
            try Self.declaration("struct RecipeStepChecklistRow", in: "\(Self.views)/RecipeDetailView.swift"),
            try Self.declaration("struct CookIngredientCheckStyle", in: "\(Self.views)/CookModeComponents.swift"),
            // Web's checked shopping row is the same brass box (`--primary: var(--sj-brass)`).
            try Self.declaration("struct LargeCheckToggleStyle", in: "\(Self.components)/ReceiptListView.swift"),
        ]
        for row in rows {
            #expect(row.contains("KitchenCheckMark("), "\(row.prefix(60))")
            #expect(!row.contains("KitchenTableTheme.herb"), "\(row.prefix(60))")
            #expect(!row.contains("checkmark.circle.fill"), "\(row.prefix(60)) draws its own check")
        }
    }

    @Test("ingredient rows are serif name, muted serif aisle in sentence case and the amount on the right, with no cart")
    func ingredientRowsMatchWeb() throws {
        let stepRow = try Self.declaration("struct RecipeStepChecklistRow", in: "\(Self.views)/RecipeDetailView.swift")
        #expect(!stepRow.contains("systemImage"), "No icon per row.")
        #expect(!stepRow.contains(".textCase(.uppercase)"), "The aisle is in sentence case.")
        #expect(stepRow.contains("KitchenIngredientText("))

        let spreadRow = try Self.declaration("struct RecipeSpreadIngredientRow", in: "\(Self.views)/RecipeDetailView.swift")
        #expect(spreadRow.contains("KitchenIngredientText("))
        let cookLabel = try Self.declaration("struct CookModeIngredientChecklistLabel", in: "\(Self.views)/CookModeView.swift")
        #expect(cookLabel.contains("KitchenIngredientText("))

        let text = try Self.source("\(Self.components)/KitchenIngredientText.swift")
        #expect(text.contains(".font(KitchenTableTheme.bodyNote)"), "The name is serif.")
        #expect(text.contains(".font(KitchenTableTheme.ingredientNote)"), "The aisle is muted serif.")
        #expect(text.contains(".foregroundStyle(KitchenTableTheme.ink2)"))
        #expect(!text.contains(".textCase(") && !text.contains(".uppercased()"))
        #expect(!text.contains(".opacity("))

        let detail = try Self.source("\(Self.views)/RecipeDetailView.swift")
        #expect(!detail.contains(#"systemImage: "cart","#), "The cart icon on every row is gone.")
    }

    @Test("Add to list stays on every ingredient row, by context menu and by the same accessibility action")
    func addToListStaysOnTheRow() throws {
        let detail = try Self.source("\(Self.views)/RecipeDetailView.swift")
        let modifier = try Self.source("\(Self.components)/KitchenIngredientAddToList.swift")
        #expect(modifier.contains(".contextMenu {"))
        #expect(modifier.contains(#"Label("Add to list", systemImage: "cart.badge.plus")"#))
        #expect(modifier.contains(#".accessibilityAction(named: "Add to list", add)"#))
        // Both of the recipe page's ingredient rows carry it, and it adds that one ingredient.
        #expect(detail.components(separatedBy: ".kitchenIngredientAddToList(").count - 1 == 2)
        #expect(detail.contains("func addIngredientToList(_ ingredient: RecipeDetailIngredientRow)"))
        #expect(detail.contains(".addItem("))
        #expect(detail.contains("IngredientAddedCopy.status(name: oneItemNamed, queuedForSync: outcome == .queuedForSync)"))
    }

    @Test("the section header is an eyebrow, a Fraunces title with tracked meta at the trailing edge, and a rule below")
    func testSectionHeaderLayout() throws {
        let header = try Self.source("\(Self.components)/KitchenSectionHeader.swift")
        #expect(header.contains("struct KitchenSectionHeader<Action: View>: View"))
        #expect(header.contains("let eyebrow: String?"))
        #expect(header.contains("let title: String"))
        #expect(header.contains("let meta: String?"))
        #expect(!header.contains(".opacity("))

        // In the body: the eyebrow, then the title and the meta on one line, then the rule under them.
        let body = try #require(header.components(separatedBy: "var body: some View {").last)
        let eyebrow = try #require(body.range(of: ".kitchenEyebrow()"))
        let title = try #require(body.range(of: "titleText"))
        let meta = try #require(body.range(of: "metaText"))
        let action = try #require(body.range(of: "action()"))
        let rule = try #require(body.range(of: ".fill(KitchenTableTheme.lineStrong)"))
        #expect(eyebrow.lowerBound < title.lowerBound, "The eyebrow sits above the title.")
        #expect(title.lowerBound < meta.lowerBound, "The meta follows the title on its line.")
        #expect(meta.lowerBound < action.lowerBound, "A section action sits at the end of the title line, as web's does.")
        #expect(action.lowerBound < rule.lowerBound, "The rule runs under them all.")
        #expect(Self.containsLines(header, ["private var titleText: some View {", "Text(title)", ".font(KitchenTableTheme.sectionTitle)"]))
        #expect(header.contains(".kitchenEyebrow(KitchenTableTheme.ink2)"), "The meta is tracked like web's.")
        #expect(header.contains("Spacer(minLength:"), "The meta keeps to the trailing edge.")
        #expect(header.contains(".frame(maxWidth: .infinity, maxHeight: 1)"))
        // VoiceOver hears one header: the title as its label and the meta as its value. The eyebrow is a kicker.
        #expect(Self.containsLines(header, [".accessibilityAddTraits(.isHeader)", #".accessibilityValue(meta ?? "")"#]))
        let metaText = try #require(header.components(separatedBy: "private var metaText: some View {").last)
        #expect(metaText.contains(".accessibilityHidden(true)"))
        #expect(Self.containsLines(header, [".kitchenEyebrow()", ".accessibilityHidden(true)"]))

        let section = try Self.declaration("struct KitchenTableSection", in: "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift")
        #expect(section.contains("KitchenSectionHeader(eyebrow: eyebrow, title: title, meta: meta)"))
        // With no subtitle, the accessory (Kitchen's "See all") rides in the header, not on a row of its own.
        #expect(section.contains("KitchenSectionHeader(eyebrow: eyebrow, title: title, meta: meta, action: accessory)"))
        let kitchenSection = try Self.declaration("struct RecipeIndex: View", in: "\(Self.views)/KitchenView.swift")
        #expect(kitchenSection.contains(#"KitchenTableSection(title: "Your recipes", meta: summary)"#))
        #expect(kitchenSection.contains("} accessory: {"))
        #expect(!kitchenSection.contains("subtitle:"), "Kitchen has no subtitle, so See all sits in the header.")

        // Every section uses it; these take web's eyebrow and meta.
        let cookingNow = try Self.source("\(Self.views)/CookingNowViews.swift")
        #expect(cookingNow.contains(#"KitchenTableSection(eyebrow: "On the stove", title: "Cooking now", meta: meta)"#))
        #expect(detail(contains: #"KitchenTableSection(eyebrow: "Cook mode", title: "Steps", meta: "Tap ingredients as you go")"#))
        let cookbooks = try Self.source("\(Self.views)/CookbooksView.swift")
        #expect(cookbooks.contains(#"KitchenTableSection(title: "Cookbook Shelf", meta:"#))
        let profile = try Self.source("\(Self.views)/ProfileView.swift")
        for title in ["Recipes", "Cookbooks", "Cooked"] {
            #expect(profile.contains(#"KitchenTableSection(title: "\#(title)", meta:"#), "\(title)")
        }
    }

    @Test("a long chef handle wraps anywhere like web's, never hyphenated and never shrunk")
    func longHandleBreaksAnywhere() throws {
        let header = try Self.declaration("struct KitchenTableHeader", in: "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift")
        #expect(header.contains("let titleBreaksAnywhere: Bool"))
        #expect(header.contains("Text(titleBreaksAnywhere ? ChefHandle.breakingAnywhere(title) : title)"))
        // VoiceOver reads the handle, not the break points.
        #expect(header.contains(".accessibilityLabel(titleBreaksAnywhere ? \"@\\(title)\" : title)"))
        #expect(!header.contains("minimumScaleFactor"), "The handle wraps; the type stays its size.")
        #expect(header.contains(".lineLimit(titleBreaksAnywhere ? nil : 3)"), "A long handle never ends in an ellipsis.")

        let profile = try Self.source("\(Self.views)/ProfileView.swift")
        #expect(Self.containsLines(profile, ["title: viewModel.header.username,", "subtitle: viewModel.header.joinedLabel,", "titleBreaksAnywhere: true"]))
        #expect(!profile.contains("title: \"@\\(viewModel.header.username)\""))
    }

    @Test("photographs take the photo radius and a lifted cover takes web's soft shadow")
    func photosAndCoversTakeTheirTokens() throws {
        let cover = try Self.source("\(Self.components)/RecipeCoverImage.swift")
        #expect(cover.contains(".kitchenLiftShadow()"))
        #expect(!cover.contains(".shadow(color:"))
        let plate = try Self.declaration("struct CookingNowPlate", in: "\(Self.views)/CookingNowViews.swift")
        #expect(plate.contains("RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.photo"))
        #expect(!plate.contains("cornerRadius: 14"))
        let spread = try Self.source("\(Self.views)/RecipeDetailView.swift")
        #expect(Self.containsLines(spread, [".frame(height: 220)", ".clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.photo))"]))
    }

    // MARK: - Source

    private func detail(contains text: String) -> Bool {
        (try? Self.source("\(Self.views)/RecipeDetailView.swift").contains(text)) ?? false
    }

    static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// True when `expected` appear as consecutive lines of `text`, ignoring indentation.
    static func containsLines(_ text: String, _ expected: [String]) -> Bool {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !expected.isEmpty, lines.count >= expected.count else { return false }
        return (0...(lines.count - expected.count)).contains { Array(lines[$0..<($0 + expected.count)]) == expected }
    }

    /// One top-level declaration: from its line to the closing brace at the start of a line.
    static func declaration(_ start: String, in path: String) throws -> String {
        let text = try source(path)
        let begin = try #require(text.range(of: start), "\(start) in \(path)")
        let end = text.range(of: "\n}\n", range: begin.upperBound..<text.endIndex)?.upperBound ?? text.endIndex
        return String(text[begin.lowerBound..<end])
    }
}
