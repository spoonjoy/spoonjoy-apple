import Foundation

// Units and conversion between the recipe as written, metric, US customary and imperial.
//
// A port of web's `app/domains/food-knowledge/model/units.ts` as of spoonjoy-v2 commit 71701356 (introduced in
// 62bd9f42, tiny amounts and "c" in 9e910509, adding amounts up in 9c0f0cd9). `UnitConversionTests` carries web's
// `test/domains/food-knowledge/units.test.ts` and `combine-amounts.test.ts` case for case, so the two can't drift
// silently: change both together.
//
// Volume converts to volume and mass to mass, exactly, through each unit's size in millilitres or grams. Nothing
// converts between volume and mass (that needs a food's density), and counted or loose units (clove, pinch, can) stay
// as written. Teaspoons and tablespoons are 5 ml and 15 ml everywhere: the US spoons differ by under 1.5%, well inside
// kitchen rounding, and cooks in every system keep measuring with spoons.

/// How a cook wants amounts written. `original` is the recipe as its author wrote it.
public enum UnitSystem: String, CaseIterable, Identifiable, Sendable {
    case original
    case metric
    case us
    case imperial

    public var id: String { rawValue }

    /// The name a picker shows. `allCases` is the order a picker shows them: as written first, then metric, US and
    /// imperial.
    public var label: String {
        switch self {
        case .original: "Original"
        case .metric: "Metric"
        case .us: "US"
        case .imperial: "Imperial"
        }
    }

    /// A stored or submitted system, or `original` for anything else.
    public init(parsing value: String?) {
        self = value.flatMap(UnitSystem.init(rawValue:)) ?? .original
    }

    /// Where the device keeps the cook's choice, for every recipe, cook mode and the shopping list. Web keeps it in
    /// its `sj_units` cookie; the app keeps it in its defaults under the same name (`@AppStorage` in the views).
    public static let storageKey = "sj_units"

    /// The cook's system as `defaults` keeps it, or `original`.
    public static func stored(in defaults: UserDefaults = .standard) -> UnitSystem {
        UnitSystem(parsing: defaults.string(forKey: storageKey))
    }

    /// Keeps `self` as the cook's system in `defaults`.
    public func store(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

/// A unit Spoonjoy can convert: its size in millilitres (volume) or grams (mass).
public struct KnownUnit: Equatable, Sendable {
    public enum Dimension: Sendable {
        case volume
        case mass
    }

    public let slug: String
    public let dimension: Dimension
    public let toBase: Double
}

/// An amount as a list or recipe stores it: a quantity and the unit it is written in.
public struct UnitAmount: Equatable, Sendable {
    public let quantity: Double?
    public let unit: String?

    public init(quantity: Double?, unit: String?) {
        self.quantity = quantity
        self.unit = unit
    }

    /// A quantity written as text, read as web's `Number.parseFloat` reads it.
    public init(quantityText: String, unit: String?) {
        self.init(quantity: UnitConversion.parseFloat(quantityText), unit: unit)
    }
}

public enum UnitConversion {
    static let usCupML = 236.5882365
    static let usFlOzML = 29.5735295625
    static let imperialFlOzML = 28.4130625
    static let imperialPintML = 568.26125
    static let ounceG = 28.349523125
    static let poundG = 453.59237

    private struct NamedUnit: Sendable {
        let unit: KnownUnit
        let names: [String]

        init(_ slug: String, _ dimension: KnownUnit.Dimension, _ toBase: Double, _ names: [String]) {
            unit = KnownUnit(slug: slug, dimension: dimension, toBase: toBase)
            self.names = names
        }
    }

    // Each unit with the ways recipes write it, already lower-cased and without dots. A cup, pint, quart, gallon or
    // fluid ounce is read as US unless the recipe says imperial or UK.
    private static let units: [NamedUnit] = [
        NamedUnit("teaspoon", .volume, 5, ["teaspoon", "teaspoons", "tsp", "tsps"]),
        NamedUnit("tablespoon", .volume, 15, ["tablespoon", "tablespoons", "tbsp", "tbsps", "tbs", "tbl"]),
        NamedUnit("us-fluid-ounce", .volume, usFlOzML, ["fl oz", "floz", "fluid ounce", "fluid ounces"]),
        NamedUnit("cup", .volume, usCupML, ["cup", "cups", "c"]),
        NamedUnit("us-pint", .volume, usCupML * 2, ["pint", "pints", "pt", "pts", "us pint", "us pints"]),
        NamedUnit("us-quart", .volume, usCupML * 4, ["quart", "quarts", "qt", "qts"]),
        NamedUnit("us-gallon", .volume, usCupML * 16, ["gallon", "gallons", "gal"]),
        NamedUnit("imperial-fluid-ounce", .volume, imperialFlOzML, ["imperial fl oz", "uk fl oz", "imperial fluid ounce", "imperial fluid ounces"]),
        NamedUnit("imperial-pint", .volume, imperialPintML, ["imperial pint", "imperial pints", "uk pint", "uk pints"]),
        NamedUnit("milliliter", .volume, 1, ["ml", "milliliter", "milliliters", "millilitre", "millilitres"]),
        NamedUnit("centiliter", .volume, 10, ["cl", "centiliter", "centiliters", "centilitre", "centilitres"]),
        NamedUnit("deciliter", .volume, 100, ["dl", "deciliter", "deciliters", "decilitre", "decilitres"]),
        NamedUnit("liter", .volume, 1000, ["l", "liter", "liters", "litre", "litres"]),
        NamedUnit("milligram", .mass, 0.001, ["mg", "milligram", "milligrams"]),
        NamedUnit("gram", .mass, 1, ["g", "gram", "grams", "gramme", "grammes"]),
        NamedUnit("kilogram", .mass, 1000, ["kg", "kilogram", "kilograms", "kilo", "kilos"]),
        NamedUnit("ounce", .mass, ounceG, ["oz", "ounce", "ounces"]),
        NamedUnit("pound", .mass, poundG, ["lb", "lbs", "pound", "pounds"]),
    ]

    private static let unitsByName: [String: KnownUnit] = Dictionary(
        units.flatMap { named in named.names.map { ($0, named.unit) } },
        uniquingKeysWith: { first, _ in first }
    )

    /// The convertible unit a recipe's unit text names, or nil for a unit that is counted, loose or unknown.
    public static func resolveUnit(_ text: String?) -> KnownUnit? {
        let trimmed = text?.trimmingCharacters(in: javaScriptWhitespace) ?? ""
        // A capital T is the tablespoon of handwritten cards; a lower-case t could be either spoon.
        if trimmed == "T" {
            return unitsByName["tbsp"]
        }
        let name = trimmed.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: javaScriptWhitespace)
        return unitsByName[name]
    }

    /// One rung of a system's ladder: the unit amounts are written in from `from` base units up.
    private struct Rung: Sendable {
        let slug: String
        let from: Double
        let toBase: Double
        let singular: String
        var plural: String? = nil
        /// Written as a decimal ("1.5 g"); otherwise as a cook's fraction ("1 ½ cups").
        var decimal = false
        var round: (@Sendable (Double) -> Double)? = nil
    }

    // A larger unit takes over a little before a whole one of it, within 2.5%, so 59 ml is "¼ cup", not "4 tbsp".
    private static let takeOver = 0.975

    // The furthest a converted amount may be rounded from the exact one before it is not worth showing.
    private static let maxRoundingError = 0.25

    /// JavaScript's `Math.round`: the nearest whole number, halves toward +∞. `value - floor` is exact in binary
    /// floating point, so this matches web bit for bit.
    static func jsRound(_ value: Double) -> Double {
        let floor = value.rounded(.down)
        return value - floor >= 0.5 ? floor + 1 : floor
    }

    private static func roundSmallMetric(_ value: Double) -> Double {
        if value < 10 { return jsRound(value * 2) / 2 }
        if value < 50 { return jsRound(value) }
        return jsRound(value / 5) * 5
    }

    private static func roundLargeMetric(_ value: Double) -> Double { jsRound(value * 100) / 100 }
    private static func roundHalf(_ value: Double) -> Double { jsRound(value * 2) / 2 }

    private static let teaspoon = Rung(slug: "teaspoon", from: 0, toBase: 5, singular: "tsp")
    private static let tablespoon = Rung(slug: "tablespoon", from: 15 * takeOver, toBase: 15, singular: "tbsp")
    private static let ounce = Rung(slug: "ounce", from: 0, toBase: ounceG, singular: "oz")
    private static let pound = Rung(slug: "pound", from: poundG * takeOver, toBase: poundG, singular: "lb")

    private static func ladder(_ system: UnitSystem, _ dimension: KnownUnit.Dimension) -> [Rung] {
        switch (system, dimension) {
        case (.original, _):
            return []
        case (.metric, .volume):
            return [
                teaspoon,
                tablespoon,
                Rung(slug: "milliliter", from: 60 * takeOver, toBase: 1, singular: "ml", decimal: true, round: roundSmallMetric),
                Rung(slug: "liter", from: 1000 * takeOver, toBase: 1000, singular: "l", decimal: true, round: roundLargeMetric),
            ]
        case (.metric, .mass):
            return [
                Rung(slug: "gram", from: 0, toBase: 1, singular: "g", decimal: true, round: roundSmallMetric),
                Rung(slug: "kilogram", from: 1000 * takeOver, toBase: 1000, singular: "kg", decimal: true, round: roundLargeMetric),
            ]
        case (.us, .volume):
            return [
                teaspoon,
                tablespoon,
                Rung(slug: "cup", from: (usCupML / 4) * takeOver, toBase: usCupML, singular: "cup", plural: "cups"),
                Rung(slug: "us-gallon", from: usCupML * 16 * takeOver, toBase: usCupML * 16, singular: "gallon", plural: "gallons"),
            ]
        case (.imperial, .volume):
            return [
                teaspoon,
                tablespoon,
                Rung(slug: "imperial-fluid-ounce", from: imperialFlOzML * 2 * takeOver, toBase: imperialFlOzML, singular: "fl oz", round: roundHalf),
                Rung(slug: "imperial-pint", from: imperialPintML * takeOver, toBase: imperialPintML, singular: "pint", plural: "pints"),
            ]
        case (.us, .mass), (.imperial, .mass):
            return [ounce, pound]
        }
    }

    /// The largest rung `base` reaches, or the first rung below them all (web's `rungFor`).
    private static func rung(in rungs: [Rung], for base: Double) -> Rung {
        rungs.dropFirst().reduce(rungs[0]) { chosen, rung in base >= rung.from ? rung : chosen }
    }

    /// An amount written in a cook's unit system: "1 cup" in metric is "235 ml". `RecipeQuantityFormatter.amountText`
    /// (web's `formatAmount`) does the rest, and anything that cannot convert is written as the recipe has it.
    /// `roundCountsUp` is the shopping list's rounding of counted things, which never convert.
    ///
    ///     amountText(in: .metric, quantity: 1, unit: "cup")   // "235 ml"
    ///     amountText(in: .us, quantity: 1, unit: "kg")        // "2 ¼ lb"
    ///     amountText(in: .metric, quantity: 2, unit: "clove") // "2 cloves"
    public static func amountText(in system: UnitSystem, quantity: Double?, unit: String?, roundCountsUp: Bool = false) -> String {
        let asWritten = { RecipeQuantityFormatter.amountText(quantity: quantity, unit: unit, roundCountsUp: roundCountsUp) }
        guard system != .original, let known = resolveUnit(unit), let numeric = quantity, numeric.isFinite, numeric > 0 else {
            return asWritten()
        }

        let base = numeric * known.toBase
        let rung = rung(in: ladder(system, known.dimension), for: base)
        if rung.slug == known.slug {
            return asWritten()
        }

        let exact = base / rung.toBase
        let value = rung.round?(exact) ?? exact
        // A tiny amount that would show as 0, or as a fraction far from it (2 g is not "⅛ oz"), stays as written.
        let shown = rung.decimal ? value : jsRound(value * 8) / 8
        if shown == 0 || abs(shown - exact) / exact > maxRoundingError {
            return asWritten()
        }
        let text = rung.decimal ? javaScriptString(value) : RecipeQuantityFormatter.formattedQuantity(value)
        let unitText = rung.plural.flatMap { value > 1 && text != "1" ? $0 : nil } ?? rung.singular
        return "\(text) \(unitText)"
    }

    /// `amountText(in:quantity:unit:)` for a quantity written as text, read as web's `Number.parseFloat` reads it.
    public static func amountText(in system: UnitSystem, quantityText: String, unit: String?, roundCountsUp: Bool = false) -> String {
        amountText(in: system, quantity: parseFloat(quantityText), unit: unit, roundCountsUp: roundCountsUp)
    }

    /// Amounts of one food added up, in the first amount's unit: 1 cup and 100 ml make 1.42 cups. Nil when they cannot
    /// be added (a volume and a weight, two units nobody can convert, an amount with no number), so a list keeps them
    /// apart. Web's `combineAmounts`.
    public static func combine(_ amounts: [UnitAmount]) -> UnitAmount? {
        guard let first = amounts.first else {
            return nil
        }
        let quantities = amounts.compactMap { $0.quantity.flatMap { $0.isFinite ? $0 : nil } }
        guard quantities.count == amounts.count else {
            return nil
        }
        let unit = first.unit
        if let known = resolveUnit(unit) {
            let resolved = amounts.map { resolveUnit($0.unit) }
            guard resolved.allSatisfy({ $0?.dimension == known.dimension }) else {
                return nil
            }
            var base = 0.0
            for (quantity, other) in zip(quantities, resolved) {
                base += quantity * other!.toBase
            }
            return UnitAmount(quantity: base / known.toBase, unit: unit)
        }
        let sameUnitText = { (unit: String?) in unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "" }
        guard amounts.allSatisfy({ sameUnitText($0.unit) == sameUnitText(unit) }) else {
            return nil
        }
        return UnitAmount(quantity: quantities.reduce(0, +), unit: unit)
    }

    /// JavaScript's `Number.parseFloat`: the number a string starts with, ignoring what follows, or nil (NaN).
    static func parseFloat(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: javaScriptWhitespace)
        if let range = trimmed.range(of: #"^[+-]?Infinity"#, options: .regularExpression) {
            return trimmed[range].hasPrefix("-") ? -.infinity : .infinity
        }
        // ASCII digits only, as JavaScript reads them; ICU's \d would also take "٣".
        guard let range = trimmed.range(of: #"^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?"#, options: .regularExpression) else {
            return nil
        }
        return Double(trimmed[range])
    }

    /// A decimal as JavaScript's `String(number)` writes it: "235", "1.13", "1.5". Past any kitchen amount (2^53 and
    /// up) the digits may differ from JavaScript's.
    static func javaScriptString(_ value: Double) -> String {
        if value.isInfinite {
            return value < 0 ? "-Infinity" : "Infinity"
        }
        if value == value.rounded(), abs(value) < 9_007_199_254_740_992 {
            return String(Int64(value))
        }
        return "\(value)"
    }

    /// The characters JavaScript's `trim()` strips: Unicode white space and line terminators and the byte-order mark,
    /// but not U+0085 (next line), which Foundation counts as a newline and JavaScript doesn't.
    static let javaScriptWhitespace = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "\u{FEFF}"))
        .subtracting(CharacterSet(charactersIn: "\u{0085}"))
}
