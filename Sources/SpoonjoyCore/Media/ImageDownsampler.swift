import CoreGraphics
import Foundation
import ImageIO

/// Decodes image bytes straight to a display-sized bitmap, never holding the full-size picture in memory.
public enum ImageDownsampler {
    public static func downsample(_ data: Data, maxPixelSize: Int) -> CGImage? {
        let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        return source.flatMap {
            CGImageSourceCreateThumbnailAtIndex($0, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ] as CFDictionary)
        }
    }
}
