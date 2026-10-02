import Foundation

/// One ingredient line parsed from free text. Mirrors the shape the web editor's parser returns
/// (quantity, unit, ingredient name), plus whether the text started with an explicit quantity.
public struct ParsedIngredientLine: Equatable, Sendable {
    public var quantity: Double
    public var unit: String
    public var name: String
    public var hadExplicitQuantity: Bool

    public init(quantity: Double, unit: String, name: String, hadExplicitQuantity: Bool) {
        self.quantity = quantity
        self.unit = unit
        self.name = name
        self.hadExplicitQuantity = hadExplicitQuantity
    }
}

/// Deterministic, offline port of the rules in the web app's ingredient parser prompt
/// (`app/lib/ingredient-parse.server.ts`), so native and web agree:
/// fractions and unicode fractions become decimals, ranges use the lower number, approximate words
/// are dropped, units are singular standard abbreviations, size words such as "large" are units, countable items with no unit word get "whole",
/// "pinch of X" and "dash of X" are quantity 1, and prep notes and modifiers stay in the name.
/// Each line is parsed independently; a comma inside a line stays in the name ("flour, sifted").
public enum IngredientTextParser {
    public static let wholeUnit = "whole"

    /// Parses a block of text, one ingredient per non-empty line.
    public static func parse(_ text: String) -> [ParsedIngredientLine] {
        text.components(separatedBy: .newlines).compactMap(parseLine)
    }

    /// Parses one line, or returns nil when it has no ingredient name.
    public static func parseLine(_ line: String) -> ParsedIngredientLine? {
        var rest = stripLeadingMarkers(line.trimmingCharacters(in: .whitespacesAndNewlines))
        rest = stripApproximateWords(rest)

        var quantity = 1.0
        var hadQuantity = false
        if let (value, remainder) = leadingQuantity(rest) {
            quantity = value
            hadQuantity = true
            rest = remainder
        }

        var unit = wholeUnit
        var tokens = rest.split(whereSeparator: \.isWhitespace).map(String.init)
        if let first = tokens.first, let canonical = canonicalUnit(first) {
            unit = canonical
            tokens.removeFirst()
            if tokens.first?.lowercased() == "of" {
                tokens.removeFirst()
            }
        }

        let name = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return nil
        }
        return ParsedIngredientLine(quantity: quantity, unit: unit, name: name, hadExplicitQuantity: hadQuantity)
    }

    // MARK: - Quantity

    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "⅓": 1.0 / 3.0, "⅔": 2.0 / 3.0, "¼": 0.25, "¾": 0.75,
        "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8, "⅙": 1.0 / 6.0, "⅚": 5.0 / 6.0,
        "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875,
    ]

    private static func stripLeadingMarkers(_ line: String) -> String {
        var result = Substring(line)
        while let first = result.first, "-*•–—".contains(first), result.dropFirst().first?.isWhitespace ?? true {
            result = result.dropFirst().drop(while: \.isWhitespace)
        }
        return String(result)
    }

    private static func stripApproximateWords(_ line: String) -> String {
        var result = line
        var changed = true
        while changed {
            changed = false
            for prefix in ["approximately ", "approx. ", "approx ", "about ", "around ", "~"] where result.lowercased().hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                changed = true
            }
        }
        return result
    }

    /// Reads a quantity ("2", "1.5", "1/2", "1 1/2", "1½", "½", "2-3", "2 to 3") from the start of `text`.
    /// A range keeps its lower number.
    private static func leadingQuantity(_ text: String) -> (Double, String)? {
        guard let (first, afterFirst) = readNumber(text) else {
            return nil
        }
        // Range: "2-3", "2 – 3", "2 to 3". The upper bound is consumed and ignored.
        let trimmed = afterFirst.drop(while: \.isWhitespace)
        for separator in ["to ", "-", "–"] where trimmed.lowercased().hasPrefix(separator) {
            let upper = trimmed.dropFirst(separator.count).drop(while: \.isWhitespace)
            if let (_, afterUpper) = readNumber(String(upper)) {
                return (first, afterUpper)
            }
        }
        return (first, afterFirst)
    }

    /// Reads one number, optionally followed by a fraction ("1 1/2" or "1½").
    private static func readNumber(_ text: String) -> (Double, String)? {
        guard let (whole, afterWhole) = readSimpleNumber(text) else {
            return nil
        }
        // Mixed number: a whole integer followed by a fraction.
        if !text.prefix(text.count - afterWhole.count).contains("/"), whole == whole.rounded() {
            let spaced = afterWhole.drop(while: { $0 == " " })
            if let (fraction, afterFraction) = readFraction(String(spaced)) {
                return (whole + fraction, afterFraction)
            }
        }
        return (whole, afterWhole)
    }

    private static func readFraction(_ text: String) -> (Double, String)? {
        if let first = text.first, let value = unicodeFractions[first] {
            return (value, String(text.dropFirst()))
        }
        guard let (value, rest) = readSimpleNumber(text), text.prefix(text.count - rest.count).contains("/") else {
            return nil
        }
        return (value, rest)
    }

    /// Reads "1.5", "1,5" is not supported, "3/4", ".5" or a lone unicode fraction.
    private static func readSimpleNumber(_ text: String) -> (Double, String)? {
        if let first = text.first, let value = unicodeFractions[first] {
            return (value, String(text.dropFirst()))
        }
        let numeric = text.prefix { $0.isASCII && ($0.isNumber || $0 == "." || $0 == "/") }
        guard !numeric.isEmpty else {
            return nil
        }
        let remainder = String(text.dropFirst(numeric.count))
        let parts = numeric.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 2, let numerator = Double(parts[0]), let denominator = Double(parts[1]), denominator != 0 {
            return (numerator / denominator, remainder)
        }
        if parts.count == 1, let value = Double(parts[0]) {
            return (value, remainder)
        }
        return nil
    }

    // MARK: - Units

    private static func canonicalUnit(_ token: String) -> String? {
        let key = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        return unitAliases[key]
    }

    private static let unitAliases: [String: String] = {
        var aliases: [String: String] = [:]
        let groups: [String: [String]] = [
            "cup": ["cup", "cups"],
            "tbsp": ["tbsp", "tbsps", "tbs", "tbl", "tablespoon", "tablespoons"],
            "tsp": ["tsp", "tsps", "teaspoon", "teaspoons"],
            "oz": ["oz", "ounce", "ounces"],
            "lb": ["lb", "lbs", "pound", "pounds"],
            "g": ["g", "gram", "grams"],
            "kg": ["kg", "kilogram", "kilograms"],
            "ml": ["ml", "milliliter", "milliliters", "millilitre", "millilitres"],
            "l": ["l", "liter", "liters", "litre", "litres"],
            "clove": ["clove", "cloves"],
            "pinch": ["pinch", "pinches"],
            "dash": ["dash", "dashes"],
            "can": ["can", "cans"],
            "slice": ["slice", "slices"],
            "piece": ["piece", "pieces"],
            "stick": ["stick", "sticks"],
            "bunch": ["bunch", "bunches"],
            "sprig": ["sprig", "sprigs"],
            "head": ["head", "heads"],
            "package": ["package", "packages", "pkg"],
            // Size words are stored as the unit ("3 large eggs" is 3 / large / eggs), as Spoonjoy recipes do.
            "small": ["small"],
            "medium": ["medium"],
            "large": ["large"],
        ]
        for (canonical, names) in groups {
            for name in names {
                aliases[name] = canonical
            }
        }
        return aliases
    }()
}
