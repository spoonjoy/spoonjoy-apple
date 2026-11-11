import Foundation

/// The shopping list's aisles set in columns on a wide iPad page, read down each column and then across, the way a
/// printed list is laid out on a wide sheet, instead of one narrow column with the rest of the screen empty.
public enum ShoppingAisleColumns {
    /// The narrowest an aisle column may be: a check, an item name and its amount on one line.
    public static let minimumColumnWidth: Double = 280
    /// The space between two columns.
    public static let columnSpacing: Double = 32
    /// More columns than this make a list read like a spreadsheet.
    public static let maximumColumns = 3
    /// The iPad shopping page's widest content: three columns of 300 pt and their gaps, plus the page's 20 pt sides.
    /// A phone's page keeps its 760 pt cap.
    public static let widePageWidth: Double = 3 * 300 + 2 * columnSpacing + 2 * 20

    /// How many columns fit `width` points of list. One below two columns' worth, so a phone, and any list narrower
    /// than two comfortable columns, keeps its single list.
    public static func count(width: Double, aisles: Int) -> Int {
        guard width > 0, aisles > 1 else { return 1 }
        let fit = Int((width + columnSpacing) / (minimumColumnWidth + columnSpacing))
        return max(1, min(fit, maximumColumns, aisles))
    }

    /// Splits aisles, in their order, into at most `columns` runs whose tallest is as short as it can be. `heights`
    /// is each aisle's height in rows (its header counts as one). Every aisle stays whole and in order, so the list
    /// still reads Produce, then Dairy, then Pantry, down and across.
    public static func split(heights: [Int], columns: Int) -> [Range<Int>] {
        let count = heights.count
        guard count > 0 else { return [] }
        let columns = max(1, min(columns, count))
        guard columns > 1 else { return [0..<count] }

        var prefix = [0]
        for height in heights {
            prefix.append(prefix[prefix.count - 1] + height)
        }
        func height(_ range: Range<Int>) -> Int { prefix[range.upperBound] - prefix[range.lowerBound] }

        // best[k][i]: the shortest tallest column when the first i aisles fill k columns; cut[k][i] where the last starts.
        var best = Array(repeating: Array(repeating: Int.max, count: count + 1), count: columns + 1)
        var cut = Array(repeating: Array(repeating: 0, count: count + 1), count: columns + 1)
        best[0][0] = 0
        for k in 1...columns {
            for i in k...count {
                for start in (k - 1)..<i where best[k - 1][start] != Int.max {
                    let tallest = max(best[k - 1][start], height(start..<i))
                    // Ties go to the later cut, so earlier columns tend to run longer than later ones.
                    if tallest <= best[k][i] {
                        best[k][i] = tallest
                        cut[k][i] = start
                    }
                }
            }
        }

        var ranges: [Range<Int>] = []
        var end = count
        for k in stride(from: columns, through: 1, by: -1) {
            let start = cut[k][end]
            ranges.append(start..<end)
            end = start
        }
        return ranges.reversed()
    }
}
