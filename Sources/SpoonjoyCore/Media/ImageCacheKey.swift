import CryptoKit
import Foundation

/// Derives stable cache identifiers for remote images. Cover URLs change whenever the cover changes
/// (`/photos/covers/<timestamp>-<uuid>.jpg`), so the URL alone is a safe cache key.
public enum ImageCacheKey {
    /// A fixed-length, filename-safe key for `url`. The fragment never reaches the server, so it is ignored.
    public static func key(for url: URL) -> String {
        let identity = url.absoluteString.prefix { $0 != "#" }
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The in-memory key: one URL can be held at several downsampled sizes.
    public static func memoryKey(key: String, maxPixelSize: Int) -> String {
        "\(key)@\(maxPixelSize)"
    }
}

/// Maps a display size to a small set of decode sizes, so the memory cache holds a few variants per image.
public enum ImageDownsampleBucket {
    public static let pixelSizes = [128, 256, 512, 768, 1_024, 1_536, 2_048]

    /// The smallest bucket that covers `points` at `scale`, or 0 when the size is not known yet.
    public static func pixelSize(points: Double, scale: Double) -> Int {
        let pixels = points * scale
        guard pixels.isFinite, pixels > 0 else {
            return 0
        }
        return pixelSizes.first { Double($0) >= pixels } ?? pixelSizes[pixelSizes.count - 1]
    }
}
