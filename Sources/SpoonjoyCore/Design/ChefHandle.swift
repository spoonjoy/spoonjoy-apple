/// A chef's handle as a page title.
///
/// A handle is one long word, so a phone can't fit a long one on a line. Web lets it break anywhere
/// (`overflow-wrap: anywhere`); native text would hyphenate it instead, adding a "-" the handle doesn't have.
/// A zero-width space between characters gives native text web's break points without changing what shows.
public enum ChefHandle {
    public static func breakingAnywhere(_ username: String) -> String {
        "@" + username.map(String.init).joined(separator: "\u{200B}")
    }
}
