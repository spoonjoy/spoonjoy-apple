import Foundation

/// The Recipes list set in two columns on a wide iPad page, so the index fills the page beside the sidebar instead of
/// one 720 pt column with wide empty margins. Rows read across, then down, like a contents page set in two columns.
public enum RecipeIndexColumns {
    /// The narrowest a column may be: a cover, a two-line title and its meta beside it.
    public static let minimumColumnWidth: Double = 380
    /// The space between the two columns.
    public static let columnSpacing: Double = 32
    /// An index row is a line of reading; past two columns it reads like a spreadsheet.
    public static let maximumColumns = 2
    /// The iPad Recipes page's widest content, the same as the Kitchen's wide spread. A phone's page keeps 720 pt.
    public static let widePageWidth: Double = 1120

    /// How many columns fit `width` points of list: one below two comfortable columns' worth, and never more columns
    /// than rows.
    public static func count(width: Double, rows: Int) -> Int {
        guard width > 0, rows > 1 else { return 1 }
        let fit = Int((width + columnSpacing) / (minimumColumnWidth + columnSpacing))
        return max(1, min(fit, maximumColumns, rows))
    }

    /// The page's side padding on each side: `KitchenTableTheme.pagePadding`, which `KitchenTablePage` sets. Keep the two equal.
    public static let pagePadding: Double = 20
    /// The page every other layout keeps.
    public static let narrowPageWidth: Double = 720

    /// How many columns the index takes in a container `containerWidth` wide, decided before the page is capped so
    /// the page widens only when two columns are drawn. One column whenever columns are off (`setsColumns`: not an
    /// iPad, or an accessibility text size).
    public static func count(containerWidth: Double, rows: Int, setsColumns: Bool) -> Int {
        guard setsColumns else { return 1 }
        return count(width: min(containerWidth, widePageWidth) - 2 * pagePadding, rows: rows)
    }

    /// The page's widest content for that many columns: the Kitchen's wide page for two, 720 pt for one.
    public static func pageWidth(columns: Int) -> Double {
        columns > 1 ? widePageWidth : narrowPageWidth
    }

    /// True when row `index` has a row above it in its column, and so a separator above it.
    public static func hasRowAbove(index: Int, columns: Int) -> Bool {
        index >= max(columns, 1)
    }
}
