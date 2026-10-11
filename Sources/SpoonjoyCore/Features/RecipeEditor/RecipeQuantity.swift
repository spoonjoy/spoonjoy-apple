import Foundation

/// Shows ingredient quantities the way the web app does ("1 ½", "¼") and reads them back from typed text.
/// Display is exact where it can be: a value that is not within a hair of a common cooking fraction
/// stays a decimal, so opening and saving an ingredient never rewrites its stored quantity.
public enum RecipeQuantity {
    public static let minimum = 0.001
    public static let maximum = 99_999.0

    private static let glyphs: [(value: Double, glyph: String)] = [
        (1.0 / 8.0, "⅛"), (1.0 / 6.0, "⅙"), (1.0 / 5.0, "⅕"), (1.0 / 4.0, "¼"), (1.0 / 3.0, "⅓"),
        (3.0 / 8.0, "⅜"), (2.0 / 5.0, "⅖"), (1.0 / 2.0, "½"), (3.0 / 5.0, "⅗"), (5.0 / 8.0, "⅝"),
        (2.0 / 3.0, "⅔"), (3.0 / 4.0, "¾"), (4.0 / 5.0, "⅘"), (5.0 / 6.0, "⅚"), (7.0 / 8.0, "⅞"),
    ]

    private static let glyphValues: [Character: Double] = Dictionary(
        uniqueKeysWithValues: glyphs.map { (Character($0.glyph), $0.value) }
    )

    private static let tolerance = 0.002

    /// "1 ½", "¼", "2", or a decimal such as "0.3" when no common fraction matches.
    public static func format(_ value: Double) -> String {
        guard value.isFinite else {
            return ""
        }
        let magnitude = abs(value)
        let sign = value < 0 ? "-" : ""
        let whole = magnitude.rounded(.down)
        let remainder = magnitude - whole

        if remainder < tolerance {
            return sign + wholeText(whole)
        }
        if 1 - remainder < tolerance {
            return sign + wholeText(whole + 1)
        }
        if let match = glyphs.first(where: { abs($0.value - remainder) < tolerance }) {
            return sign + (whole == 0 ? match.glyph : "\(wholeText(whole)) \(match.glyph)")
        }
        return sign + magnitude.formatted(.number.precision(.fractionLength(0...3)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }

    /// Reads "1 1/2", "1½", "1 ½", "¾", "3/4", "0.25" or ".5". Returns nil for anything else.
    public static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let last = trimmed.last, let glyphValue = glyphValues[last] {
            let head = trimmed.dropLast().trimmingCharacters(in: .whitespaces)
            if head.isEmpty {
                return glyphValue
            }
            guard let headValue = plainNumber(head), headValue == headValue.rounded() else {
                return nil
            }
            return headValue + glyphValue
        }

        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        switch parts.count {
        case 1:
            return plainNumber(parts[0])
        case 2:
            guard let whole = plainNumber(parts[0]), whole == whole.rounded(), parts[1].contains("/"),
                  let fraction = plainNumber(parts[1]) else {
                return nil
            }
            return whole + fraction
        default:
            return nil
        }
    }

    /// The message to show beside a quantity field, or nil when the text is a usable quantity.
    public static func validationMessage(for text: String) -> String? {
        guard let value = parse(text) else {
            return "Use a number like 2, 1 1/2, ¾ or 0.25."
        }
        guard value >= minimum, value <= maximum else {
            return "Quantity must be between 0.001 and 99,999."
        }
        return nil
    }

    private static func wholeText(_ value: Double) -> String {
        String(Int(value))
    }

    /// "2", "0.25", ".5" or "3/4". No signs, no grouping, no exponent.
    private static func plainNumber(_ text: String) -> Double? {
        guard text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == "/") }) else {
            return nil
        }
        let slashParts = text.split(separator: "/", omittingEmptySubsequences: false)
        if slashParts.count == 2 {
            guard let numerator = decimal(String(slashParts[0])), let denominator = decimal(String(slashParts[1])), denominator != 0 else {
                return nil
            }
            return numerator / denominator
        }
        return slashParts.count == 1 ? decimal(text) : nil
    }

    private static func decimal(_ text: String) -> Double? {
        guard !text.isEmpty, text.filter({ $0 == "." }).count <= 1, text != "." else {
            return nil
        }
        return Double(text)
    }
}
