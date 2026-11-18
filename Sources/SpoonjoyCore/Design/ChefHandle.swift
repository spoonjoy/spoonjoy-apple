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

    /// The handle as it reads in a byline ("by maya"): no "@", breakable between any two characters.
    /// VoiceOver should be given the plain handle, not this text.
    public static func wrapping(_ username: String) -> String {
        username.map(String.init).joined(separator: "\u{200B}")
    }
}
