import Foundation
import Testing
@testable import SpoonjoyCore

/// Web's `test/domains/food-knowledge/units.test.ts` and `combine-amounts.test.ts` (spoonjoy-v2 commit 71701356), case
/// for case, so native writes every amount in a cook's units exactly as web does. A case added on either side belongs
/// on both.
@Suite("Unit conversion, as web converts")
struct UnitConversionTests {
    // MARK: resolveUnit

    @Test(arguments: [
        ("tsp", "teaspoon"),
        ("Teaspoons", "teaspoon"),
        ("tbsp.", "tablespoon"),
        ("T", "tablespoon"),
        ("cups", "cup"),
        ("c", "cup"),
        ("C.", "cup"),
        ("fl oz", "us-fluid-ounce"),
        ("fl. oz.", "us-fluid-ounce"),
        ("pints", "us-pint"),
        ("qt", "us-quart"),
        ("gallon", "us-gallon"),
        ("mL", "milliliter"),
        ("cl", "centiliter"),
        ("decilitre", "deciliter"),
        ("L", "liter"),
        ("litres", "liter"),
        ("g", "gram"),
        ("kilos", "kilogram"),
        ("mg", "milligram"),
        ("ounces", "ounce"),
        ("lbs", "pound"),
        ("UK pint", "imperial-pint"),
        ("imperial fl oz", "imperial-fluid-ounce"),
    ])
    func readsUnitText(text: String, slug: String) {
        #expect(UnitConversion.resolveUnit(text)?.slug == slug)
    }

    @Test func readsALowerCaseTAsNothingSinceItMayBeEitherSpoon() {
        #expect(UnitConversion.resolveUnit("t") == nil)
    }

    @Test(arguments: ["whole", "clove", "pinch", "", nil] as [String?])
    func doesNotConvert(text: String?) {
        #expect(UnitConversion.resolveUnit(text) == nil)
    }

    // MARK: parseUnitSystem

    @Test func keepsAKnownSystem() {
        #expect(UnitSystem(parsing: "imperial") == .imperial)
    }

    @Test(arguments: ["kelvin", "", nil] as [String?])
    func readsAnUnknownSystemAsTheRecipeAsWritten(value: String?) {
        #expect(UnitSystem(parsing: value) == .original)
    }

    @Test func offersTheRecipeAsWrittenFirstThenMetricUSAndImperial() {
        #expect(UnitSystem.allCases.map(\.rawValue) == ["original", "metric", "us", "imperial"])
        #expect(UnitSystem.allCases.map(\.label) == ["Original", "Metric", "US", "Imperial"])
    }

    // MARK: formatAmountIn, as written

    @Test func writesTheAmountAsTheRecipeDoes() {
        #expect(UnitConversion.amountText(in: .original, quantity: 1, unit: "cup") == "1 cup")
    }

    @Test func passesTheShoppingListRoundingThrough() {
        #expect(UnitConversion.amountText(in: .original, quantity: 1.25, unit: "whole", roundCountsUp: true) == "2")
    }

    // MARK: Anything it cannot convert stays as written

    @Test func keepsACountedUnit() {
        #expect(UnitConversion.amountText(in: .metric, quantity: 2, unit: "clove") == "2 cloves")
    }

    @Test func keepsAnAmountWithoutAQuantity() {
        #expect(UnitConversion.amountText(in: .metric, quantity: nil, unit: "cup") == "cup")
    }

    @Test func keepsAQuantityItCannotRead() {
        #expect(UnitConversion.amountText(in: .metric, quantityText: "lots", unit: "cup") == "cup")
    }

    @Test func keepsAZeroAmount() {
        #expect(UnitConversion.amountText(in: .metric, quantity: 0, unit: "cup") == "0 cup")
    }

    @Test func keepsAUnitAlreadyInTheSystemInTheRecipesOwnSpelling() {
        #expect(UnitConversion.amountText(in: .us, quantity: 2, unit: "pounds") == "2 pounds")
    }

    @Test(arguments: [
        (UnitSystem.us, 1.0, "g", "1 g"),
        (.us, 0.3, "g", "⅓ g"),
        (.us, 2, "g", "2 g"),
        (.metric, 200, "mg", "200 mg"),
        (.us, 0.25, "ml", "¼ ml"),
    ])
    func keepsATinyAmountTheUnitsWouldRoundAwayOrBadly(system: UnitSystem, quantity: Double, unit: String, expected: String) {
        #expect(UnitConversion.amountText(in: system, quantity: quantity, unit: unit) == expected)
    }

    // MARK: Metric

    @Test(arguments: [
        (1.0, "cup", "235 ml"),
        (0.5, "cup", "120 ml"),
        (4, "cups", "945 ml"),
        (5, "cups", "1.18 l"),
        (1, "fl oz", "2 tbsp"),
        (0.25, "cup", "60 ml"),
        (2, "imperial pints", "1.14 l"),
        (1, "lb", "455 g"),
        (8, "oz", "225 g"),
        (1, "oz", "28 g"),
        (0.25, "oz", "7 g"),
        (0.1, "oz", "3 g"),
        (0.05, "oz", "1.5 g"),
        (2.5, "lb", "1.13 kg"),
        (1500, "g", "1.5 kg"),
        (1, "tsp", "1 tsp"),
        (2, "tbsp", "2 tbsp"),
        (3, "tbsp", "3 tbsp"),
        (5, "tbsp", "75 ml"),
        (2, "qt", "1.89 l"),
        (1, "gallon", "3.79 l"),
    ])
    func writesMetric(quantity: Double, unit: String, expected: String) {
        #expect(UnitConversion.amountText(in: .metric, quantity: quantity, unit: unit) == expected)
    }

    @Test func readsAQuantityGivenAsText() {
        #expect(UnitConversion.amountText(in: .metric, quantityText: "2", unit: "cups") == "475 ml")
    }

    // MARK: US

    @Test(arguments: [
        (240.0, "ml", "1 cup"),
        (120, "ml", "½ cup"),
        (5, "ml", "1 tsp"),
        (15, "ml", "1 tbsp"),
        (6, "tsp", "2 tbsp"),
        (12, "tbsp", "¾ cup"),
        (1, "l", "4 ¼ cups"),
        (1, "liter", "4 ¼ cups"),
        (2, "l", "8 ½ cups"),
        (4, "l", "1 gallon"),
        (100, "g", "3 ½ oz"),
        (500, "g", "1 ⅛ lb"),
        (1, "kg", "2 ¼ lb"),
    ])
    func writesUS(quantity: Double, unit: String, expected: String) {
        #expect(UnitConversion.amountText(in: .us, quantity: quantity, unit: unit) == expected)
    }

    // MARK: Imperial

    @Test(arguments: [
        (1.0, "cup", "8 ½ fl oz"),
        (2, "cups", "16 ½ fl oz"),
        (600, "ml", "1 pint"),
        (1.5, "l", "2 ⅝ pints"),
        (1, "us pint", "16 ½ fl oz"),
        (10, "ml", "2 tsp"),
        (30, "ml", "2 tbsp"),
        (250, "g", "8 ⅞ oz"),
    ])
    func writesImperial(quantity: Double, unit: String, expected: String) {
        #expect(UnitConversion.amountText(in: .imperial, quantity: quantity, unit: unit) == expected)
    }

    // MARK: Where the choice is kept (web: the sj_units cookie)

    @Test func keepsTheCooksChoiceOnTheDeviceAndReadsAnythingElseAsWritten() throws {
        let defaults = try #require(UserDefaults(suiteName: "unit-system-\(UUID().uuidString)"))
        #expect(UnitSystem.stored(in: defaults) == .original, "nothing picked yet is the recipe as written")
        UnitSystem.metric.store(in: defaults)
        #expect(defaults.string(forKey: "sj_units") == "metric", "kept under web's cookie name")
        #expect(UnitSystem.stored(in: defaults) == .metric)
        defaults.set("kelvin", forKey: UnitSystem.storageKey)
        #expect(UnitSystem.stored(in: defaults) == .original)
    }

    // MARK: combineAmounts

    @Test func addsAmountsInTheSameUnit() {
        #expect(UnitConversion.combine([.init(quantity: 1, unit: "cup"), .init(quantity: 2, unit: "cup")]) == .init(quantity: 3, unit: "cup"))
    }

    @Test func addsCountedAmountsThatHaveNoUnit() {
        #expect(UnitConversion.combine([.init(quantity: 2, unit: nil), .init(quantity: 1, unit: nil)]) == .init(quantity: 3, unit: nil))
    }

    @Test func addsAUnitWrittenTwoWaysInTheFirstWay() {
        #expect(UnitConversion.combine([.init(quantity: 1, unit: "clove"), .init(quantity: 2, unit: "clove")]) == .init(quantity: 3, unit: "clove"))
        #expect(UnitConversion.combine([.init(quantity: 1, unit: "cups"), .init(quantity: 1, unit: "cup")]) == .init(quantity: 2, unit: "cups"))
    }

    @Test func addsVolumesInDifferentUnitsInTheFirstUnit() throws {
        let total = try #require(UnitConversion.combine([.init(quantity: 1, unit: "cup"), .init(quantity: 100, unit: "ml")]))
        #expect(total.unit == "cup")
        #expect(abs(try #require(total.quantity) - (1 + 100 / 236.5882365)) < 0.005)
        #expect(UnitConversion.amountText(in: .metric, quantity: total.quantity, unit: total.unit) == "335 ml")
    }

    @Test func addsWeightsInDifferentUnitsInTheFirstUnit() throws {
        let total = try #require(UnitConversion.combine([.init(quantity: 500, unit: "g"), .init(quantity: 1, unit: "lb")]))
        #expect(total.unit == "g")
        #expect(abs(try #require(total.quantity) - 953.59237) < 0.005)
    }

    @Test func readsAQuantityWrittenAsText() {
        #expect(UnitConversion.combine([.init(quantityText: "1.5", unit: "cup"), .init(quantity: 1, unit: "cup")]) == .init(quantity: 2.5, unit: "cup"))
    }

    @Test(arguments: [
        ("a volume and a weight", [UnitAmount(quantity: 1, unit: "cup"), UnitAmount(quantity: 100, unit: "g")]),
        ("a counted amount and a measured one", [UnitAmount(quantity: 2, unit: nil), UnitAmount(quantity: 100, unit: "g")]),
        ("two different unknown units", [UnitAmount(quantity: 1, unit: "clove"), UnitAmount(quantity: 1, unit: "head")]),
        ("an amount with no quantity", [UnitAmount(quantity: nil, unit: "cup"), UnitAmount(quantity: 1, unit: "cup")]),
        ("a quantity that is not a number", [UnitAmount(quantityText: "some", unit: "cup"), UnitAmount(quantity: 1, unit: "cup")]),
        ("nothing", []),
    ])
    func leavesApart(_ name: String, amounts: [UnitAmount]) {
        #expect(UnitConversion.combine(amounts) == nil, "leaves \(name) apart")
    }

    // MARK: Native's own

    /// Web's `shopping-list-units.test.tsx`: an item's amount in a unit system, counted things rounded up.
    @Test func writesAShoppingItemInTheCooksUnitsRoundingCountedThingsUp() {
        func item(_ quantity: Double?, _ unit: String?) -> ShoppingListItem {
            ShoppingListItem(id: "item", name: "item", quantity: quantity, unit: unit, checked: false, checkedAt: nil, deletedAt: nil, categoryKey: nil, iconKey: nil, sortIndex: 0, updatedAt: "2026-11-24T00:00:00.000Z")
        }
        #expect(item(2, "lbs").displayQuantity(in: .metric) == "905 g")
        #expect(item(1.25, "whole").displayQuantity(in: .metric) == "2")
        #expect(item(2, "lbs").displayQuantity == "2 lbs", "Spotlight, sharing and Reminders keep the list as written")
    }

    @Test func roundsHalvesUpAsJavaScriptDoes() {
        #expect(UnitConversion.jsRound(2.5) == 3)
        #expect(UnitConversion.jsRound(-2.5) == -2)
        #expect(UnitConversion.jsRound(0.49999999999999994) == 0)
    }

    @Test func readsTheNumberAQuantityStartsWithAsParseFloatDoes() {
        #expect(UnitConversion.parseFloat("2 cups") == 2)
        #expect(UnitConversion.parseFloat(" .5") == 0.5)
        #expect(UnitConversion.parseFloat("1e2") == 100)
        #expect(UnitConversion.parseFloat("lots") == nil)
    }
}
