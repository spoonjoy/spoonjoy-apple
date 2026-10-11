import Foundation

/// Searches the contents of one cookbook. Every word of the query must appear in a recipe's text,
/// ignoring case and accents, so "miso sal" finds "Miso Glazed Salmon".
public enum CookbookRecipeSearch {
    public static func filter<Item>(_ items: [Item], query: String, text: (Item) -> String) -> [Item] {
        let words = normalized(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else {
            return items
        }
        return items.filter { item in
            let haystack = normalized(text(item))
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
