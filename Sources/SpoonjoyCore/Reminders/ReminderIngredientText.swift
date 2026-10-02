import Foundation

/// A quantity with a normalized unit, such as 2 cups or 12 (no unit).
public struct ReminderQuantity: Equatable, Sendable {
    public let value: Double?
    public let unit: String?

    public init(value: Double?, unit: String?) {
        self.value = value
        self.unit = ReminderIngredientText.normalizedUnit(unit)
    }

    /// The text shown in a reminder title and in notes, for example "1 1/2 cups". Empty when there is no number.
    public var displayText: String {
        guard let value else {
            return ""
        }
        let number = ReminderIngredientText.formatNumber(value)
        guard let unit else {
            return number
        }
        return "\(number) \(ReminderIngredientText.displayUnit(unit, value: value))"
    }

    /// Reads text such as "2 cups", "1/2 tsp" or "12". Any words after the number are kept as the unit.
    static func parse(_ text: String) -> ReminderQuantity? {
        guard let match = ReminderIngredientText.firstMatch(
            #"^\s*(\#(ReminderIngredientText.numberPattern))\s*(.*?)\s*$"#,
            in: text
        ) else {
            return nil
        }
        return ReminderQuantity(
            value: ReminderIngredientText.number(from: match[1]),
            unit: match[2]
        )
    }
}

/// Name and quantity extracted from free text such as "2 cups flour" or "Eggs (12)".
public struct ReminderParsedText: Equatable, Sendable {
    public let quantity: ReminderQuantity
    public let name: String
}

/// Pure text rules for matching ingredient names against reminder titles.
public enum ReminderIngredientText {
    // MARK: Name keys

    /// The comparison key for an ingredient name: lowercase, folded accents, no prep notes, singular last word.
    public static func key(for raw: String) -> String {
        var text = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        text = replacing(#"\([^)]*\)"#, in: text, with: " ")
        if let cut = text.firstIndex(where: { $0 == "," || $0 == ";" }) {
            text = String(text[..<cut])
        }
        text = text.replacingOccurrences(of: "&", with: " and ")
        text = replacing(#"[^a-z0-9]+"#, in: text, with: " ")
        var words = text.split(separator: " ").map(String.init)
        while words.count > 1, let first = words.first, leadingDescriptors.contains(first) {
            words.removeFirst()
        }
        guard let last = words.last else {
            return ""
        }
        words[words.count - 1] = singularized(last)
        let phrase = words.joined(separator: " ")
        return synonyms[phrase] ?? phrase
    }

    private static let leadingDescriptors: Set<String> = [
        "large", "medium", "small", "big", "fresh", "ripe", "chopped", "diced", "minced", "sliced", "grated"
    ]

    private static let synonyms: [String: String] = [
        "scallion": "green onion",
        "spring onion": "green onion",
        "aubergine": "eggplant",
        "courgette": "zucchini",
        "garbanzo bean": "chickpea",
        "garbanzo": "chickpea"
    ]

    private static let uncountable: Set<String> = ["molasses", "hummus", "couscous", "asparagus", "swiss", "citrus", "bass"]

    private static let irregularSingulars: [String: String] = [
        "leaves": "leaf", "loaves": "loaf", "halves": "half", "knives": "knife", "shelves": "shelf",
        "wolves": "wolf", "calves": "calf", "chilies": "chili", "chillies": "chili"
    ]

    private static let simplePlurals: Set<String> = ["cookies", "pies", "brownies", "smoothies", "veggies"]

    static func singularized(_ word: String) -> String {
        if let irregular = irregularSingulars[word] {
            return irregular
        }
        guard word.count > 3, word.hasSuffix("s"), !uncountable.contains(word),
              !word.hasSuffix("ss"), !word.hasSuffix("us"), !word.hasSuffix("is")
        else {
            return word
        }
        if simplePlurals.contains(word) {
            return String(word.dropLast())
        }
        if word.hasSuffix("ies") {
            return String(word.dropLast(3)) + "y"
        }
        if ["oes", "ches", "shes", "xes", "sses"].contains(where: word.hasSuffix) {
            return String(word.dropLast(2))
        }
        return String(word.dropLast())
    }

    // MARK: Units

    private static let unitTable: [String: String] = {
        let groups: [String: [String]] = [
            "cup": ["cup", "cups"],
            "tbsp": ["tbsp", "tbsps", "tbs", "tablespoon", "tablespoons"],
            "tsp": ["tsp", "tsps", "teaspoon", "teaspoons"],
            "oz": ["oz", "ounce", "ounces"],
            "lb": ["lb", "lbs", "pound", "pounds"],
            "g": ["g", "gram", "grams", "gm"],
            "kg": ["kg", "kgs", "kilogram", "kilograms"],
            "ml": ["ml", "milliliter", "milliliters", "millilitre", "millilitres"],
            "l": ["l", "liter", "liters", "litre", "litres"],
            "gal": ["gal", "gallon", "gallons"],
            "qt": ["qt", "quart", "quarts"],
            "pt": ["pt", "pint", "pints"],
            "clove": ["clove", "cloves"],
            "can": ["can", "cans", "tin", "tins"],
            "bunch": ["bunch", "bunches"],
            "pinch": ["pinch", "pinches"],
            "dash": ["dash", "dashes"],
            "handful": ["handful", "handfuls"],
            "stick": ["stick", "sticks"],
            "slice": ["slice", "slices"],
            "package": ["package", "packages", "pkg", "pkgs"],
            "head": ["head", "heads"],
            "sprig": ["sprig", "sprigs"],
            "jar": ["jar", "jars"],
            "bottle": ["bottle", "bottles"],
            "bag": ["bag", "bags"],
            "box": ["box", "boxes"],
            "stalk": ["stalk", "stalks"],
            "fillet": ["fillet", "fillets"]
        ]
        var table: [String: String] = [:]
        for (canonical, spellings) in groups {
            for spelling in spellings {
                table[spelling] = canonical
            }
        }
        return table
    }()

    private static let abbreviatedUnits: Set<String> = ["tbsp", "tsp", "oz", "lb", "g", "kg", "ml", "l", "gal", "qt", "pt"]

    static func normalizedUnit(_ raw: String?) -> String? {
        guard var unit = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return nil
        }
        unit = unit.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !unit.isEmpty else {
            return nil
        }
        return unitTable[unit] ?? singularized(unit)
    }

    static func displayUnit(_ unit: String, value: Double) -> String {
        guard value > 1, !abbreviatedUnits.contains(unit) else {
            return unit
        }
        if ["ch", "sh", "s", "x"].contains(where: unit.hasSuffix) {
            return unit + "es"
        }
        return unit + "s"
    }

    // MARK: Numbers

    static let numberPattern = #"(?:\d+\s+\d+/\d+|\d+/\d+|\d*[½¼¾⅓⅔⅛⅜⅝⅞]|\d+(?:\.\d+)?)"#

    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3.0, "⅔": 2.0 / 3.0,
        "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
    ]

    static func number(from text: String) -> Double {
        var total = 0.0
        for part in text.split(whereSeparator: { $0 == " " }) {
            var digits = ""
            for character in part {
                if let fraction = unicodeFractions[character] {
                    total += fraction
                } else {
                    digits.append(character)
                }
            }
            if digits.contains("/") {
                let pieces = digits.split(separator: "/").compactMap { Double($0) }
                total += pieces[0] / pieces[1]
            } else if let whole = Double(digits) {
                total += whole
            }
        }
        return total
    }

    private static let fractionGlyphs: [(Double, String)] = [
        (1.0 / 8.0, "1/8"), (1.0 / 4.0, "1/4"), (1.0 / 3.0, "1/3"), (3.0 / 8.0, "3/8"), (1.0 / 2.0, "1/2"),
        (5.0 / 8.0, "5/8"), (2.0 / 3.0, "2/3"), (3.0 / 4.0, "3/4"), (7.0 / 8.0, "7/8")
    ]

    static func formatNumber(_ value: Double) -> String {
        let whole = value.rounded(.down)
        let remainder = value - whole
        if remainder < 0.01 {
            return String(Int(whole))
        }
        if let fraction = fractionGlyphs.first(where: { abs($0.0 - remainder) < 0.01 }) {
            return whole == 0 ? fraction.1 : "\(Int(whole)) \(fraction.1)"
        }
        let rounded = (value * 100).rounded() / 100
        return String(rounded)
    }

    // MARK: Parsing

    /// Splits "2 cups flour", "Flour (2 cups)", "Eggs x2" or "Flour - 2 cups" into a quantity and a name.
    public static func parse(_ text: String) -> ReminderParsedText {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let leading = firstMatch(
            #"^(\#(numberPattern))(?:\s*(?:-|–|to)\s*(\#(numberPattern)))?\s*(?:x\b)?\s*(.*)$"#,
            in: trimmed
        ) {
            let value = number(from: leading[2].isEmpty ? leading[1] : leading[2])
            var rest = leading[3]
            var unit: String?
            if let word = firstMatch(#"^([A-Za-z]+)\.?(?:\s+(.*))?$"#, in: rest), unitTable[word[1].lowercased()] != nil {
                unit = word[1]
                rest = word[2]
            }
            if let ofMatch = firstMatch(#"^of\s+(.*)$"#, in: rest) {
                rest = ofMatch[1]
            }
            return ReminderParsedText(quantity: ReminderQuantity(value: value, unit: unit), name: rest)
        }
        let trailingPatterns = [
            #"^(.*?)\s*\(\s*(\#(numberPattern))\s*([A-Za-z. ]*?)\s*\)$"#,
            #"^(.*?)\s+x\s*(\#(numberPattern))()$"#,
            #"^(.*?)\s+[-–—]\s+(\#(numberPattern))\s*([A-Za-z. ]*)$"#
        ]
        for pattern in trailingPatterns {
            if let trailing = firstMatch(pattern, in: trimmed) {
                return ReminderParsedText(
                    quantity: ReminderQuantity(value: number(from: trailing[2]), unit: trailing[3]),
                    name: trailing[1]
                )
            }
        }
        return ReminderParsedText(quantity: ReminderQuantity(value: nil, unit: nil), name: trimmed)
    }

    // MARK: Regex helpers

    /// Returns the whole match and each capture group; groups that did not take part are empty strings.
    static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else {
            return nil
        }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }

    private static func replacing(_ pattern: String, in text: String, with template: String) -> String {
        text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
    }
}
