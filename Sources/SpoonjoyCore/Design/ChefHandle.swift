/// A chef's handle as a page title, or inside a byline.
///
/// A handle is one long word, so a phone can't fit a long one on a line. Web lets it break anywhere
/// (`overflow-wrap: anywhere`); native text would hyphenate it instead, adding a "-" the handle doesn't have.
/// A zero-width space between characters gives native text web's break points without changing what shows.
public enum ChefHandle {
    /// The handle as a title: "@" and the handle, breakable between any two characters.
    public static func breakingAnywhere(_ username: String) -> String {
        "@" + wrapping(username)
    }

    /// The handle as it reads in a byline ("by maya"): no "@", breakable between any two characters.
    /// VoiceOver should be given the plain handle, not this text.
    public static func wrapping(_ username: String) -> String {
        username.map(String.init).joined(separator: "\u{200B}")
    }
}
