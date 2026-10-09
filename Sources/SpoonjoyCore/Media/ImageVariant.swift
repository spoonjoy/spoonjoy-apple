import Foundation

/// Spoonjoy stores each photo at a few widths and serves them from the photo's own URL:
/// `/photos/<key>?w=<pixels>` returns the smallest stored WebP at least that wide (capped at the largest),
/// and the original until a new photo's variants exist. Asking for the width an image is shown at turns a
/// multi-megabyte original into a download of tens of kilobytes.
public enum ImageVariant {
    /// The widths the server stores, in pixels. It rounds any other width up to one of these.
    public static let widths = [256, 512, 1_024, 1_536]

    /// The stored width that covers a decode of `maxPixelSize`, capped at the largest.
    public static func width(forPixelSize maxPixelSize: Int) -> Int {
        widths.first { $0 >= maxPixelSize } ?? widths[widths.count - 1]
    }

    /// The URL to download for a decode of at most `maxPixelSize` pixels: the sized variant for a photo
    /// under `/photos/`, and `url` itself for anything else (another path, a URL that already carries a
    /// query or fragment, a variant, or an unknown size). Only Spoonjoy hands the app `/photos/` URLs; a
    /// server that does not know `w` ignores it and returns the same image.
    public static func url(for url: URL, maxPixelSize: Int) -> URL {
        guard
            maxPixelSize > 0,
            url.scheme == "https" || url.scheme == "http",
            url.path.hasPrefix("/photos/"),
            url.path.count > "/photos/".count,
            !url.path.hasPrefix("/photos/variants/"),
            url.query == nil,
            url.fragment == nil
        else {
            return url
        }
        return url.appending(queryItems: [URLQueryItem(name: "w", value: String(width(forPixelSize: maxPixelSize)))])
    }
}
