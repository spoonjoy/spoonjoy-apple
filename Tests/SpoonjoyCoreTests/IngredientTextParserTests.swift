import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Ingredient text parser")
struct IngredientTextParserTests {
    private func parsed(_ line: String) -> ParsedIngredientLine? {
        IngredientTextParser.parseLine(line)
    }

    @Test("pasted block becomes one row per line")
    func pastedBlockBecomesRows() {
        let rows = IngredientTextParser.parse("2 cups rice\n3 large eggs\n\n  \n1 tbsp soy sauce\r\n")
        #expect(rows == [
            ParsedIngredientLine(quantity: 2, unit: "cup", name: "rice", hadExplicitQuantity: true),
            ParsedIngredientLine(quantity: 3, unit: "large", name: "eggs", hadExplicitQuantity: true),
            ParsedIngredientLine(quantity: 1, unit: "tbsp", name: "soy sauce", hadExplicitQuantity: true),
        ])
        #expect(IngredientTextParser.parse("   \n").isEmpty)
    }

    @Test("fractions, mixed numbers, unicode fractions and decimals")
    func quantities() {
        #expect(parsed("1/2 cup milk")?.quantity == 0.5)
        #expect(parsed("3/4 cup milk")?.quantity == 0.75)
        #expect(parsed("1 1/2 cups flour")?.quantity == 1.5)
        #expect(parsed("1½ cups flour")?.quantity == 1.5)
        #expect(parsed("1 ½ cups flour")?.quantity == 1.5)
        #expect(parsed("½ tsp salt")?.quantity == 0.5)
        #expect(parsed("¼ tsp salt")?.quantity == 0.25)
        #expect(parsed("2.5 lb potatoes")?.quantity == 2.5)
        #expect(parsed("4/2 cup milk")?.quantity == 2)
        #expect(parsed("1/0 cup milk")?.hadExplicitQuantity == false)
        #expect(parsed("1.2.3 cup milk")?.hadExplicitQuantity == false)
        #expect(parsed("2 1 cup milk")?.quantity == 2)
    }

    @Test("ranges use the lower number")
    func ranges() {
        #expect(parsed("2-3 cups rice")?.quantity == 2)
        #expect(parsed("2 – 3 cups rice")?.quantity == 2)
        #expect(parsed("2 to 3 cups rice")?.quantity == 2)
        #expect(parsed("2 to 3 cups rice")?.unit == "cup")
        #expect(parsed("2 - cups rice")?.name == "- cups rice")
    }

    @Test("approximate words, bullets and checkbox-free markers are ignored")
    func noise() {
        #expect(parsed("about 2 cups rice")?.quantity == 2)
        #expect(parsed("Approximately about 2 cups rice")?.name == "rice")
        #expect(parsed("approx. 2 cups rice")?.quantity == 2)
        #expect(parsed("~2 cups rice")?.quantity == 2)
        #expect(parsed("- 2 cups rice")?.name == "rice")
        #expect(parsed("• 2 cups rice")?.name == "rice")
        #expect(parsed("* - 2 cups rice")?.name == "rice")
        #expect(parsed("-rice")?.name == "-rice")
    }

    @Test("units normalize to singular standard forms")
    func units() {
        let cases: [(String, String)] = [
            ("1 cups a", "cup"), ("1 Tablespoons a", "tbsp"), ("1 tbsp. a", "tbsp"), ("1 teaspoon a", "tsp"),
            ("1 ounces a", "oz"), ("1 lbs a", "lb"), ("1 pounds a", "lb"), ("1 grams a", "g"),
            ("1 kilograms a", "kg"), ("1 millilitres a", "ml"), ("1 liters a", "l"), ("1 cloves a", "clove"),
            ("1 pinches a", "pinch"), ("1 dashes a", "dash"), ("1 cans a", "can"), ("1 slices a", "slice"),
            ("1 pieces a", "piece"), ("1 sticks a", "stick"), ("1 bunches a", "bunch"), ("1 sprigs a", "sprig"),
            ("1 heads a", "head"), ("1 pkg a", "package"), ("1 Small a", "small"), ("1 medium a", "medium"), ("1 large a", "large"),
        ]
        for (line, unit) in cases {
            #expect(parsed(line)?.unit == unit, "\(line)")
        }
    }

    @Test("countable items use whole, and of after a unit is dropped")
    func countableAndOf() {
        #expect(parsed("2 eggs") == ParsedIngredientLine(quantity: 2, unit: "whole", name: "eggs", hadExplicitQuantity: true))
        #expect(parsed("3 cloves of garlic") == ParsedIngredientLine(quantity: 3, unit: "clove", name: "garlic", hadExplicitQuantity: true))
        #expect(parsed("pinch of salt") == ParsedIngredientLine(quantity: 1, unit: "pinch", name: "salt", hadExplicitQuantity: false))
        #expect(parsed("2 cups Of rice")?.name == "rice")
        #expect(parsed("3 large eggs") == ParsedIngredientLine(quantity: 3, unit: "large", name: "eggs", hadExplicitQuantity: true))
        #expect(parsed("salt") == ParsedIngredientLine(quantity: 1, unit: "whole", name: "salt", hadExplicitQuantity: false))
    }

    @Test("prep notes and modifiers stay with the name")
    func prepNotes() {
        #expect(parsed("1 cup flour, sifted")?.name == "flour, sifted")
        #expect(parsed("2 tbsp extra virgin olive oil")?.name == "extra virgin olive oil")
    }

    @Test("lines without a name return nil")
    func emptyNames() {
        #expect(parsed("") == nil)
        #expect(parsed("   ") == nil)
        #expect(parsed("2 cups") == nil)
        #expect(parsed("2") == nil)
        #expect(parsed("- ") == nil)
    }

    @Test("draft rows build from parsed lines and fill from a typed line")
    func draftRows() {
        let line = ParsedIngredientLine(quantity: 2, unit: "cup", name: "rice", hadExplicitQuantity: true)
        let built = RecipeEditorIngredientDraft(id: "local_1", parsed: line)
        #expect(built == RecipeEditorIngredientDraft(id: "local_1", name: "rice", quantity: 2, unit: "cup"))

        var typed = RecipeEditorIngredientDraft(id: "local_2", name: "2 cups rice", quantity: 1, unit: nil)
        let typedApplied = typed.applyTypedLine()
        #expect(typedApplied)
        #expect(typed == RecipeEditorIngredientDraft(id: "local_2", name: "rice", quantity: 2, unit: "cup"))

        var plain = RecipeEditorIngredientDraft(id: "local_3", name: "rice", quantity: 1, unit: nil)
        let plainApplied = plain.applyTypedLine()
        #expect(!plainApplied)
        #expect(plain.name == "rice")
        var empty = RecipeEditorIngredientDraft(id: "local_4", name: "", quantity: 1, unit: nil)
        let emptyApplied = empty.applyTypedLine()
        #expect(!emptyApplied)
    }
}
