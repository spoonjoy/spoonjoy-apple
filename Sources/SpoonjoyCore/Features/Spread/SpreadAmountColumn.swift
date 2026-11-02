import Foundation

/// The amount column on a recipe spread's ingredient list. Text wraps an amount between words, and splits a word
/// only when that word alone is wider than the column, so the amount leaves the column for a line above the
/// ingredient name whenever its longest word would not fit.
public enum SpreadAmountColumn {
    public enum Placement: Equatable, Sendable {
        case column
        case aboveName
    }

    public static func words(in amount: String) -> [String] {
        amount.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }

    public static func placement(longestWordWidth: Double, columnWidth: Double, isAccessibilitySize: Bool) -> Placement {
        guard !isAccessibilitySize, longestWordWidth <= columnWidth else {
            return .aboveName
        }
        return .column
    }
}
