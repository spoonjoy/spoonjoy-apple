/// A chef's handle as a page title, or inside a byline.
///
/// A handle is one long word, so a phone can't fit a long one on a line, and native text would hyphenate it, adding
/// a "-" the handle doesn't have. A zero-width space gives native text break points without changing what shows.
public enum ChefHandle {
    /// The handle as a small label: "@" and the handle, breakable between any two characters.
    public static func breakingAnywhere(_ username: String) -> String {
        "@" + wrapping(username)
    }

    /// The handle as a page title: "@" and the handle, breakable only after its separators ("_", ".", "-"), so a
    /// line ends between the handle's own words and never inside one. The title truncates in the middle past two lines.
    public static func breakingAtWords(_ username: String) -> String {
        "@" + username.map { "_.-".contains($0) ? "\($0)\u{200B}" : String($0) }.joined()
    }

    /// The handle as a page title's words at the accessibility text sizes: "@" and the handle, cut after its
    /// separators ("_", ".", "-"). A piece of one or two characters stays with the piece before it, so no line holds
    /// a lone "1". A word too wide for its line is scaled down whole rather than broken.
    public static func words(_ username: String) -> [String] {
        var pieces: [String] = []
        var current = "@"
        for character in username {
            current.append(character)
            if "_.-".contains(character) {
                pieces.append(current)
                current = ""
            }
        }
        if !current.isEmpty || pieces.isEmpty {
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

    /// The handle as it reads in a byline ("by maya"): no "@", breakable between any two characters.
    /// VoiceOver should be given the plain handle, not this text.
    public static func wrapping(_ username: String) -> String {
        username.map(String.init).joined(separator: "\u{200B}")
    }
}
