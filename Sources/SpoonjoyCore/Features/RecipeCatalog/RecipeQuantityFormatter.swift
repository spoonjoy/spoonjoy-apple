import Foundation

/// The one way Spoonjoy writes an amount, everywhere: the recipe page, cook mode and the shopping list. It is a port
/// of web's `app/lib/quantity.ts` (`formatQuantity`, `formatAmount`), so native and web write "¼ cup", "2 cups" and
/// "2" for two lemons the same way.
public enum RecipeQuantityFormatter {
    private static let unicodeFractions: [String: String] = [
        "1/2": "½", "1/3": "⅓", "2/3": "⅔", "1/4": "¼", "3/4": "¾",
        "1/5": "⅕", "2/5": "⅖", "3/5": "⅗", "4/5": "⅘", "1/6": "⅙", "5/6": "⅚",
        "1/8": "⅛", "3/8": "⅜", "5/8": "⅝", "7/8": "⅞"
    ]

    /// Unit words a cook reads in the plural past one ("2 cups", "3 cloves"). Abbreviations such as "tsp", "g" or
    /// "oz", and units already written in the plural, are shown as written.
    private static let pluralUnits: [String: String] = [
        "bag": "bags", "bottle": "bottles", "box": "boxes", "bunch": "bunches", "can": "cans", "clove": "cloves",
        "cup": "cups", "dash": "dashes", "drop": "drops", "ear": "ears", "fillet": "fillets", "gram": "grams",
        "handful": "handfuls", "head": "heads", "inch": "inches", "jar": "jars", "kilogram": "kilograms",
        "leaf": "leaves", "liter": "liters", "litre": "litres", "ounce": "ounces", "package": "packages",
        "piece": "pieces", "pinch": "pinches", "pint": "pints", "pound": "pounds", "quart": "quarts",
        "sheet": "sheets", "slice": "slices", "sprig": "sprigs", "stalk": "stalks", "stick": "sticks",
        "strip": "strips", "tablespoon": "tablespoons", "teaspoon": "teaspoons"
    ]

    /// Units counted in whole things. A shopper buys 2 lemons, not 1 ¼, so the shopping list rounds these up.
    private static let countUnits: Set<String> = [
        "bag", "bottle", "box", "bunch", "can", "clove", "ear", "fillet", "head", "jar", "package",
        "piece", "slice", "sprig", "stalk", "stick", "whole"
    ]

    /// An amount as web's `formatAmount` writes it: a rounded, Unicode-fraction quantity followed by its unit, with
    /// the unit in the plural past one. "whole" is how a counted ingredient is stored, not a word a cook writes, so
    /// it is left out. `roundCountsUp` rounds counted units up to a whole number, for the shopping list.
    public static func amountText(quantity: Double?, unit: String?, roundCountsUp: Bool = false) -> String {
        let hasQuantity = quantity.map(\.isFinite) ?? false
        let trimmedUnit = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var value = quantity ?? 0
        if hasQuantity, roundCountsUp, isCountUnit(trimmedUnit), value > 0 {
            value = (value - 1e-9).rounded(.up)
        }
        let quantityText = hasQuantity ? formattedQuantity(value) : ""

        if trimmedUnit.lowercased() == "whole" {
            return quantityText
        }

        var unitText = trimmedUnit
        if let plural = pluralUnits[trimmedUnit.lowercased()], hasQuantity, value > 1, quantityText != "1" {
            unitText = trimmedUnit == trimmedUnit.lowercased() ? plural : plural.prefix(1).uppercased() + plural.dropFirst()
        }

        return [quantityText, unitText].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The recipe page's and cook mode's amount: `amountText` for a quantity the recipe always has.
    public static func quantityText(quantity: Double, unit: String?) -> String {
        amountText(quantity: quantity, unit: unit)
    }

    /// Whether a unit counts whole things (whole, clove, can...), in either number.
    public static func isCountUnit(_ unit: String) -> Bool {
        let lower = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let singular = pluralUnits.first { $0.value == lower }?.key ?? lower
        return countUnits.contains(singular)
    }

    /// A number as web's `formatQuantity` writes it: "1 ½", "¼", "3".
    static func formattedQuantity(_ quantity: Double) -> String {
        guard quantity.isFinite else {
            return ""
        }
        // Past any real amount, eighths would overflow an Int; such a number is written whole.
        guard abs(quantity) < 1e15 else {
            return String(format: "%.0f", quantity)
        }
        let (numerator, denominator) = nearestCookingFraction(abs(quantity))
        let whole = numerator / denominator
        let remainder = numerator % denominator
        var text: String
        if remainder == 0 {
            text = "\(whole)"
        } else {
            let glyph = fractionText(remainder, denominator)
            text = whole == 0 ? glyph : "\(whole) \(glyph)"
        }
        if quantity < 0, text != "0" {
            text = "-\(text)"
        }
        return text
    }

    /// A fraction as its Unicode glyph ("¼"), or written out where Unicode has none ("1/7").
    static func fractionText(_ numerator: Int, _ denominator: Int) -> String {
        let fraction = "\(numerator)/\(denominator)"
        guard let glyph = unicodeFractions[fraction] else {
            return fraction
        }
        return glyph
    }

    /// The nearest common cooking fraction, in lowest terms: a clean eighth first, then thirds and sixths, then the
    /// nearest eighth, as web's `roundToNearestFraction` picks.
    private static func nearestCookingFraction(_ value: Double) -> (Int, Int) {
        let eighths = (value * 8).rounded()
        if abs(value - eighths / 8) < 0.02 {
            return reduced(Int(eighths), 8)
        }
        for numerator in [1, 2, 4, 5, 7, 8] where abs(value - Double(numerator) / 3) < 0.05 {
            return reduced(numerator, 3)
        }
        for numerator in [1, 5, 7, 11] where abs(value - Double(numerator) / 6) < 0.03 {
            return reduced(numerator, 6)
        }
        return reduced(Int(eighths), 8)
    }

    private static func reduced(_ numerator: Int, _ denominator: Int) -> (Int, Int) {
        var a = numerator, b = denominator
        while b != 0 { (a, b) = (b, a % b) }
        let divisor = max(a, 1)
        return (numerator / divisor, denominator / divisor)
    }
}

/// A recipe's servings for a static label, as web's `formatServingsLabel` writes it: "Serves 4" for a bare number
/// or range, and the author's own words when they already wrote a phrase ("Makes 12 cookies", "4 servings").
public enum RecipeServingsLabel {
    public static func label(_ servings: String?) -> String? {
        let trimmed = servings?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return nil
        }
        if trimmed.range(of: #"^(serves?|servings?|makes?|yields?|feeds?|for)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return trimmed
        }
        if trimmed.range(of: #"^\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?$"#, options: .regularExpression) != nil {
            return "Serves \(trimmed)"
        }
        return trimmed
    }
}
