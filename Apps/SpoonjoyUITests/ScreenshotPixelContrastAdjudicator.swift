import CoreGraphics
import Foundation
import ImageIO

struct ObservedRGBPixel: Codable, Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    fileprivate var luminance: Double {
        0.2126 * Self.linearized(red)
            + 0.7152 * Self.linearized(green)
            + 0.0722 * Self.linearized(blue)
    }

    fileprivate func distance(to other: Self) -> Double {
        let redDelta = Double(red) - Double(other.red)
        let greenDelta = Double(green) - Double(other.green)
        let blueDelta = Double(blue) - Double(other.blue)
        return (redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta).squareRoot()
    }

    private static func linearized(_ component: UInt8) -> Double {
        let value = Double(component) / 255
        return value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}

struct ObservedContrastPixelEvidence: Codable, Equatable, Sendable {
    let method: String
    let screenshotSHA256: String
    let contrastRatio: Double
    let requiredContrastRatio: Double
    let evaluatedForegroundClusterCount: Int
    let backgroundCoverage: Double
    let foregroundCoverage: Double
    let analyzedPixelCount: Int
    let backgroundPixelCount: Int
    let foregroundPixelCount: Int
    let ignoredEdgeRulePixelCount: Int
    let ignoredEdgeRuleRowCount: Int
    let background: ObservedRGBPixel
    let foreground: ObservedRGBPixel
}

struct ScreenshotPixelCrop: Sendable {
    let pixels: [ObservedRGBPixel]
    let width: Int
    let height: Int
}

struct ScreenshotPixelBuffer: Sendable {
    let width: Int
    let height: Int
    let pixels: [ObservedRGBPixel]
    let pointSize: CGSize

    init(width: Int, height: Int, pixels: [ObservedRGBPixel], pointSize: CGSize) {
        self.width = width
        self.height = height
        self.pixels = pixels
        self.pointSize = pointSize
    }

    init?(pngData: Data, pointSize: CGSize) {
        guard pointSize.width > 0,
              pointSize.height > 0,
              let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [ObservedRGBPixel] = []
        pixels.reserveCapacity(width * height)
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Double(bytes[offset + 3]) / 255
            let red = UInt8(clamping: Int((Double(bytes[offset]) * alpha + 255 * (1 - alpha)).rounded()))
            let green = UInt8(clamping: Int((Double(bytes[offset + 1]) * alpha + 255 * (1 - alpha)).rounded()))
            let blue = UInt8(clamping: Int((Double(bytes[offset + 2]) * alpha + 255 * (1 - alpha)).rounded()))
            pixels.append(ObservedRGBPixel(red: red, green: green, blue: blue))
        }
        self.init(width: width, height: height, pixels: pixels, pointSize: pointSize)
    }

    func pixels(in frame: ObservedRect) -> [ObservedRGBPixel]? {
        crop(in: frame)?.pixels
    }

    func crop(in frame: ObservedRect) -> ScreenshotPixelCrop? {
        guard width > 0,
              height > 0,
              pixels.count == width * height,
              pointSize.width > 0,
              pointSize.height > 0,
              frame.x.isFinite,
              frame.y.isFinite,
              frame.width.isFinite,
              frame.height.isFinite,
              !frame.isEmpty,
              frame.minX >= 0,
              frame.minY >= 0,
              frame.maxX <= pointSize.width,
              frame.maxY <= pointSize.height else {
            return nil
        }

        let scaleX = Double(width) / pointSize.width
        let scaleY = Double(height) / pointSize.height
        let minX = Int(floor(frame.minX * scaleX))
        let minY = Int(floor(frame.minY * scaleY))
        let maxX = Int(ceil(frame.maxX * scaleX))
        let maxY = Int(ceil(frame.maxY * scaleY))
        guard minX >= 0,
              minY >= 0,
              maxX <= width,
              maxY <= height,
              maxX > minX,
              maxY > minY else {
            return nil
        }

        var cropPixels: [ObservedRGBPixel] = []
        cropPixels.reserveCapacity((maxX - minX) * (maxY - minY))
        for row in minY..<maxY {
            let start = row * width + minX
            cropPixels.append(contentsOf: pixels[start..<(start + maxX - minX)])
        }
        return ScreenshotPixelCrop(
            pixels: cropPixels,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}

enum ScreenshotPixelContrastAdjudicator {
    private static let requiredContrastRatio = 4.5
    private static let minimumBackgroundCoverage = 0.6
    private static let maximumForegroundCoverage = 0.4
    private static let minimumForegroundClusterShare = 0.2

    static func analyze(
        pixels: [ObservedRGBPixel],
        width: Int,
        height: Int,
        screenshotSHA256: String = String(repeating: "0", count: 64)
    ) -> ObservedContrastPixelEvidence? {
        guard width > 0,
              height > 0,
              pixels.count == width * height,
              pixels.count >= 64 else {
            return nil
        }

        let buckets = Dictionary(grouping: pixels, by: quantizedKey)
        guard let dominantBucket = buckets.values.max(by: { $0.count < $1.count }) else {
            return nil
        }
        let dominantColor = average(dominantBucket)
        let backgroundPixels = pixels.filter { $0.distance(to: dominantColor) <= 12 }
        let backgroundCoverage = Double(backgroundPixels.count) / Double(pixels.count)
        guard backgroundCoverage >= minimumBackgroundCoverage else { return nil }

        let background = average(backgroundPixels)
        let backgroundLuminance = background.luminance
        let indexedForegroundCandidates = pixels.enumerated().filter {
            $0.element.distance(to: background) >= 16
                && abs($0.element.luminance - backgroundLuminance) >= 0.03
        }
        let edgeBandHeight = max(1, Int(ceil(Double(height) * 0.1)))
        let minimumRuleWidth = max(1, Int(ceil(Double(width) * 0.6)))
        let foregroundCountByRow = Dictionary(
            grouping: indexedForegroundCandidates,
            by: { $0.offset / width }
        ).mapValues(\.count)
        let ignoredEdgeRuleRows = Set(foregroundCountByRow.compactMap { row, count in
            let isAtEdge = row < edgeBandHeight || row >= height - edgeBandHeight
            return isAtEdge && count >= minimumRuleWidth ? row : nil
        })
        let ignoredEdgeRulePixelCount = indexedForegroundCandidates.reduce(into: 0) { count, candidate in
            if ignoredEdgeRuleRows.contains(candidate.offset / width) {
                count += 1
            }
        }
        let foregroundCandidates = indexedForegroundCandidates.compactMap { candidate in
            ignoredEdgeRuleRows.contains(candidate.offset / width) ? nil : candidate.element
        }
        let minimumForegroundPixels = max(8, pixels.count / 200)
        let candidateCoverage = Double(foregroundCandidates.count) / Double(pixels.count)
        guard foregroundCandidates.count >= minimumForegroundPixels,
              candidateCoverage <= maximumForegroundCoverage else {
            return nil
        }

        let foregroundBuckets = Dictionary(grouping: foregroundCandidates, by: quantizedKey)
        let substantialClusterMinimum = max(
            minimumForegroundPixels,
            Int(ceil(Double(foregroundCandidates.count) * minimumForegroundClusterShare))
        )
        let substantialForegroundClusters = foregroundBuckets.values.filter {
            $0.count >= substantialClusterMinimum
        }
        guard !substantialForegroundClusters.isEmpty else { return nil }

        let evaluatedClusters = substantialForegroundClusters.map { cluster -> (ObservedRGBPixel, Double) in
            let color = average(cluster)
            let ratio = (max(background.luminance, color.luminance) + 0.05)
                / (min(background.luminance, color.luminance) + 0.05)
            return (color, ratio)
        }
        guard let weakestCluster = evaluatedClusters.min(by: { $0.1 < $1.1 }) else { return nil }
        let foreground = weakestCluster.0
        let contrastRatio = weakestCluster.1
        guard contrastRatio >= requiredContrastRatio else { return nil }
        let foregroundPixelCount = substantialForegroundClusters.reduce(0) { $0 + $1.count }
        let foregroundCoverage = Double(foregroundPixelCount) / Double(pixels.count)

        return ObservedContrastPixelEvidence(
            method: "screenshotPixelContrastV2",
            screenshotSHA256: screenshotSHA256,
            contrastRatio: contrastRatio,
            requiredContrastRatio: requiredContrastRatio,
            evaluatedForegroundClusterCount: substantialForegroundClusters.count,
            backgroundCoverage: backgroundCoverage,
            foregroundCoverage: foregroundCoverage,
            analyzedPixelCount: pixels.count,
            backgroundPixelCount: backgroundPixels.count,
            foregroundPixelCount: foregroundPixelCount,
            ignoredEdgeRulePixelCount: ignoredEdgeRulePixelCount,
            ignoredEdgeRuleRowCount: ignoredEdgeRuleRows.count,
            background: background,
            foreground: foreground
        )
    }

    private static func quantizedKey(_ pixel: ObservedRGBPixel) -> Int {
        (Int(pixel.red) / 8) << 10
            | (Int(pixel.green) / 8) << 5
            | Int(pixel.blue) / 8
    }

    private static func average(_ pixels: [ObservedRGBPixel]) -> ObservedRGBPixel {
        let totals = pixels.reduce(into: (red: 0, green: 0, blue: 0)) { result, pixel in
            result.red += Int(pixel.red)
            result.green += Int(pixel.green)
            result.blue += Int(pixel.blue)
        }
        let count = max(1, pixels.count)
        return ObservedRGBPixel(
            red: UInt8(clamping: totals.red / count),
            green: UInt8(clamping: totals.green / count),
            blue: UInt8(clamping: totals.blue / count)
        )
    }
}
