import Foundation

/// The recipe page's one scale control, the "Serves 4" in its meta row. When the recipe states a number of
/// servings, the stepper moves a whole serving at a time; otherwise it scales the recipe in quarters below 1×
/// and halves above it. It reads and writes the per-recipe scale factor the page saves and cook mode opens at.
public struct RecipeServes: Equatable, Sendable {
    public static let minimumScale = 0.25
    public static let maximumScale = 50.0

    /// The servings as the recipe states them ("4", "4-6", "2 loaves"), or nil.
    public let statedServings: String?
    /// The count when the stated servings are a number, optionally followed by words ("4", "6 people").
    public let baseCount: Double?
    /// The words after the count, such as "people"; empty when there are none.
    public let countUnit: String

    public init(servings: String?) {
        let trimmed = servings?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        statedServings = trimmed.isEmpty ? nil : trimmed
        let parsed = Self.parseCount(trimmed)
        baseCount = parsed?.count
        countUnit = parsed?.unit ?? ""
    }

    /// A finite scale, rounded to hundredths and kept between `minimumScale` and `maximumScale`.
    public static func normalizedScale(_ value: Double) -> Double {
        guard value.isFinite else {
            return 1
        }
        return min(maximumScale, max(minimumScale, (value * 100).rounded() / 100))
    }

    /// The whole number of servings at this scale, or nil when the recipe states no count.
    public func servings(atScale scale: Double) -> Int? {
        guard let baseCount else {
            return nil
        }
        return max(1, Int((baseCount * scale).rounded()))
    }

    /// "Serves 6", "Serves 6 people", "Serves 4-6 ×1.5" or "Scale 1.5×".
    public func label(scale: Double) -> String {
        if let servings = servings(atScale: scale) {
            return countUnit.isEmpty ? "Serves \(servings)" : "Serves \(servings) \(countUnit)"
        }
        guard let statedServings else {
            return "Scale \(Self.formatted(scale))×"
        }
        return scale == 1 ? "Serves \(statedServings)" : "Serves \(statedServings) ×\(Self.formatted(scale))"
    }

    /// One serving more, or the next half (a quarter below 1×).
    public func incremented(_ scale: Double) -> Double {
        if let baseCount, let servings = servings(atScale: scale) {
            return Self.normalizedScale(Double(servings + 1) / baseCount)
        }
        let next = scale < 1 ? (floor(scale * 4) + 1) / 4 : (floor(scale * 2) + 1) / 2
        return Self.normalizedScale(next)
    }

    /// One serving fewer, never below one, or the previous half (a quarter at or below 1×).
    public func decremented(_ scale: Double) -> Double {
        if let baseCount, let servings = servings(atScale: scale) {
            return Self.normalizedScale(Double(max(1, servings - 1)) / baseCount)
        }
        let previous = scale <= 1 ? (ceil(scale * 4) - 1) / 4 : (ceil(scale * 2) - 1) / 2
        return Self.normalizedScale(previous)
    }

    public func canIncrement(_ scale: Double) -> Bool {
        incremented(scale) > scale
    }

    public func canDecrement(_ scale: Double) -> Bool {
        decremented(scale) < scale
    }

    private static func formatted(_ scale: Double) -> String {
        scale.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US_POSIX")))
    }

    /// "4" or "6 people": a positive number, then nothing or words that start with a letter. "4-6" is not a count.
    private static func parseCount(_ text: String) -> (count: Double, unit: String)? {
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first, let count = Double(first.replacingOccurrences(of: ",", with: ".")), count > 0,
              count.isFinite else {
            return nil
        }
        let unit = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        guard unit.isEmpty || unit.first?.isLetter == true else {
            return nil
        }
        return (count, unit)
    }
}

/// The recipe's cook time for its meta row: the timed steps added up.
public enum RecipeCookTime {
    /// "23 min", "1 hr" or "1 hr 5 min"; nil when no step is timed, so the meta row leaves the clause out.
    public static func label(stepDurations: [Int?]) -> String? {
        let minutes = stepDurations.compactMap { $0 }.filter { $0 > 0 }.reduce(0, +)
        guard minutes > 0 else {
            return nil
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, _):
            return "\(remainder) min"
        case (_, 0):
            return "\(hours) hr"
        default:
            return "\(hours) hr \(remainder) min"
        }
    }
}
