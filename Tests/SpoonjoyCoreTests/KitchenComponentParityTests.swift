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
    }

    @Test("the section header is an eyebrow, a Fraunces title with tracked meta at the trailing edge, and a rule below")
    func testSectionHeaderLayout() throws {
        let header = try Self.source("\(Self.components)/KitchenSectionHeader.swift")
        #expect(header.contains("struct KitchenSectionHeader: View"))
        #expect(header.contains("let eyebrow: String?"))
        #expect(header.contains("let title: String"))
        #expect(header.contains("let meta: String?"))
        #expect(!header.contains(".opacity("))

        // In the body: the eyebrow, then the title and the meta on one line, then the rule under them.
        let body = try #require(header.components(separatedBy: "var body: some View {").last)
        let eyebrow = try #require(body.range(of: ".kitchenEyebrow()"))
        let title = try #require(body.range(of: "titleText"))
        let meta = try #require(body.range(of: "metaText"))
        let rule = try #require(body.range(of: ".fill(KitchenTableTheme.lineStrong)"))
        #expect(eyebrow.lowerBound < title.lowerBound, "The eyebrow sits above the title.")
        #expect(title.lowerBound < meta.lowerBound, "The meta follows the title on its line.")
        #expect(meta.lowerBound < rule.lowerBound, "The rule runs under both.")
        #expect(header.contains("private var titleText: some View {\n        Text(title)\n            .font(KitchenTableTheme.sectionTitle)"))
        #expect(header.contains(".kitchenEyebrow(KitchenTableTheme.ink2)"), "The meta is tracked like web's.")
        #expect(header.contains("Spacer(minLength:"), "The meta keeps to the trailing edge.")
        #expect(header.contains(".frame(maxWidth: .infinity, maxHeight: 1)"))
        #expect(header.contains(".accessibilityAddTraits(.isHeader)"))

        let section = try Self.declaration("struct KitchenTableSection", in: "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift")
        #expect(section.contains("KitchenSectionHeader(eyebrow: eyebrow, title: title, meta: meta)"))

        // Every section uses it; these take web's eyebrow and meta.
        let cookingNow = try Self.source("\(Self.views)/CookingNowViews.swift")
        #expect(cookingNow.contains(#"KitchenTableSection(eyebrow: "On the stove", title: "Cooking now", meta: meta)"#))
        #expect(detail(contains: #"KitchenTableSection(eyebrow: "Cook mode", title: "Steps", meta: "Tap ingredients as you go")"#))
        let kitchen = try Self.source("\(Self.views)/KitchenView.swift")
        #expect(kitchen.contains(#"KitchenTableSection(title: "Your recipes", meta: summary)"#))
        let cookbooks = try Self.source("\(Self.views)/CookbooksView.swift")
        #expect(cookbooks.contains(#"KitchenTableSection(title: "Cookbook Shelf", meta:"#))
        let profile = try Self.source("\(Self.views)/ProfileView.swift")
        for title in ["Recipes", "Cookbooks", "Cooked"] {
            #expect(profile.contains(#"KitchenTableSection(title: "\#(title)", meta:"#), "\(title)")
        }
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
        #expect(spread.contains(".frame(height: 220)\n                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.photo))"))
    }

    // MARK: - Source

    private func detail(contains text: String) -> Bool {
        (try? Self.source("\(Self.views)/RecipeDetailView.swift").contains(text)) ?? false
    }

    static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// One top-level declaration: from its line to the closing brace at the start of a line.
    static func declaration(_ start: String, in path: String) throws -> String {
        let text = try source(path)
        let begin = try #require(text.range(of: start), "\(start) in \(path)")
        let end = text.range(of: "\n}\n", range: begin.upperBound..<text.endIndex)?.upperBound ?? text.endIndex
        return String(text[begin.lowerBound..<end])
    }
}
