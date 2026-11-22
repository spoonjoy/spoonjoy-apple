/// A chef's handle as a page title, or inside a byline.
///
/// A handle is one long word, so a phone can't fit a long one on a line, and native text would hyphenate it, adding
/// a "-" the handle doesn't have. A zero-width space after each of its separators ("_", ".", "-") gives native text
/// break points between the handle's own words without changing what shows, so a line never ends inside one.
public enum ChefHandle {
    /// The handle as a page title: "@" and the handle, breakable only after its separators ("_", ".", "-"), so a
    /// line ends between the handle's own words and never inside one. The title truncates in the middle past two lines.
    public static func breakingAtWords(_ username: String) -> String {
        "@" + username.map { "_.-".contains($0) ? "\($0)\u{200B}" : String($0) }.joined()
    }

    /// The handle as a page title's words at the accessibility text sizes: "@" and the handle, cut after its
    /// separators ("_", ".", "-"). A piece of one or two characters stays with the piece before it, so no line holds
    /// a lone "1". A word too wide for its line is scaled down whole rather than broken.
    public static func words(_ username: String) -> [String] {
        pieces("@" + username)
    }

    /// A line of text that may hold a handle ("By codex_native_r42 · 3 recipes") as its words for whole-word
    /// wrapping: split at spaces, and each word also after its separators ("_", ".", "-"), as ``words(_:)`` does for a
    /// handle. A piece cut from the word before it `joinsPrevious`, so it sits flush against that piece, with no space.
    public static func lineWords(_ text: String) -> [LineWord] {
        text.split(separator: " ").flatMap { word in
            pieces(String(word)).enumerated().map { LineWord(text: $1, joinsPrevious: $0 > 0) }
        }
    }

    /// A line of text that may hold a handle, breakable at its spaces and after a handle's separators, never inside a
    /// word: the plain-text form of ``lineWords(_:)``, for text below the accessibility sizes.
    public static func breakingAtSeparators(_ text: String) -> String {
        text.map { "_.-".contains($0) ? "\($0)\u{200B}" : String($0) }.joined()
    }

    /// A word cut after its separators, with a piece of one or two characters kept with the piece before it.
    private static func pieces(_ word: String) -> [String] {
        var pieces: [String] = []
        var current = ""
        for character in word {
            current.append(character)
            if "_.-".contains(character) {
                pieces.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            pieces.append(current)
        }
        var words: [String] = []
        for piece in pieces {
            if let last = words.last, piece.count < 3 {
                words[words.count - 1] = last + piece
            } else {
                words.append(piece)
            }
        }
        return words
    }

}

/// One word of a line for whole-word wrapping (``ChefHandle/lineWords(_:)``).
public struct LineWord: Equatable, Sendable {
    public let text: String
    /// A piece cut from the word before it (after a handle's "_", "." or "-"), set flush against it with no space.
    public let joinsPrevious: Bool

    public init(text: String, joinsPrevious: Bool) {
        self.text = text
        self.joinsPrevious = joinsPrevious
    }
}
