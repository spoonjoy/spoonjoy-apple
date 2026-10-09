import Foundation

/// One quantity formatter shared by recipe detail and cook mode, so both show the same glyph fractions.
public enum RecipeQuantityFormatter {
    private static let fractionGlyphs: [Int: [Int: String]] = [
        2: [1: "½"],
        3: [1: "⅓", 2: "⅔"],
        4: [1: "¼", 2: "½", 3: "¾"],
        6: [1: "⅙", 2: "⅓", 3: "½", 4: "⅔", 5: "⅚"],
        8: [1: "⅛", 2: "¼", 3: "⅜", 4: "½", 5: "⅝", 6: "¾", 7: "⅞"]
    ]

    public static func quantityText(quantity: Double, unit: String?) -> String {
        let quantityText = formattedQuantity(quantity)
        guard let unit, !unit.isEmpty else {
            return quantityText
        }

        return "\(quantityText) \(unit)"
    }

    private static func formattedQuantity(_ value: Double) -> String {
        guard value.isFinite else {
            return "1"
        }

        let sign = value < 0 ? "-" : ""
        let absoluteValue = abs(value)
        let whole = Int(absoluteValue.rounded(.down))
        let fraction = absoluteValue - Double(whole)

        if fraction < 0.005 {
            return "\(sign)\(whole)"
        }

        if let fractionText = formattedFraction(fraction) {
            if whole == 0 {
                return "\(sign)\(fractionText)"
            }
            return "\(sign)\(whole) \(fractionText)"
        }

        return trimmedDecimal(value)
    }

    private static func formattedFraction(_ value: Double) -> String? {
        let candidates = fractionGlyphs.flatMap { denominator, numerators in
            numerators.map { numerator, glyph in
                (distance: abs(value - (Double(numerator) / Double(denominator))), glyph: glyph)
            }
        }
        guard let best = candidates.min(by: { $0.distance < $1.distance }),
              best.distance <= 0.02 else {
            return nil
        }

        return best.glyph
    }

    private static func trimmedDecimal(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.last == "0" {
            text.removeLast()
        }
        return text
    }
}
