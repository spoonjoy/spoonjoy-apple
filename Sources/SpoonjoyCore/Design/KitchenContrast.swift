import Foundation

/// WCAG 2 contrast between two sRGB colours written as 0xRRGGBB.
public enum KitchenContrast {
    public static func ratio(foreground: UInt32, background: UInt32) -> Double {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ hex: UInt32) -> Double {
        let red = channel((hex >> 16) & 0xFF)
        let green = channel((hex >> 8) & 0xFF)
        let blue = channel(hex & 0xFF)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private static func channel(_ value: UInt32) -> Double {
        let srgb = Double(value) / 255
        return srgb <= 0.04045 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4)
    }
}
