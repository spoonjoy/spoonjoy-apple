import CoreGraphics
import CryptoKit
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
    let screenshotSHA256: String?

    init(
        width: Int,
        height: Int,
        pixels: [ObservedRGBPixel],
        pointSize: CGSize,
        screenshotSHA256: String? = nil
    ) {
        self.width = width
        self.height = height
        self.pixels = pixels
        self.pointSize = pointSize
        self.screenshotSHA256 = screenshotSHA256
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
        self.init(
            width: width,
            height: height,
            pixels: pixels,
            pointSize: pointSize,
            screenshotSHA256: SHA256.hash(data: pngData)
                .map { String(format: "%02x", $0) }
                .joined()
        )
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
    private static let defaultRequiredContrastRatio = 4.5
    private static let minimumBackgroundCoverage = 0.6
    private static let maximumForegroundCoverage = 0.4

    static func analyze(
        pixels: [ObservedRGBPixel],
        width: Int,
        height: Int,
        screenshotSHA256: String = String(repeating: "0", count: 64),
        requiredContrastRatio: Double = defaultRequiredContrastRatio
    ) -> ObservedContrastPixelEvidence? {
        guard requiredContrastRatio.isFinite,
              requiredContrastRatio > 0,
              width > 0,
              height > 0,
              pixels.count == width * height,
              pixels.count >= 64 else {
            return nil
        }

        let buckets = Dictionary(grouping: pixels, by: quantizedKey)
        guard let dominantBucket = buckets.sorted(by: { left, right in
            left.value.count == right.value.count
                ? left.key < right.key
                : left.value.count > right.value.count
        }).first?.value else {
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
        let foregroundCandidates = indexedForegroundCandidates.filter { candidate in
            !ignoredEdgeRuleRows.contains(candidate.offset / width)
        }
        let minimumForegroundPixels = max(8, pixels.count / 200)
        let candidateCoverage = Double(foregroundCandidates.count) / Double(pixels.count)
        guard foregroundCandidates.count >= minimumForegroundPixels,
              candidateCoverage <= maximumForegroundCoverage else {
            return nil
        }

        let substantialForegroundClusters = spatialComponents(
            in: foregroundCandidates,
            width: width
        )
            .filter { $0.count >= minimumForegroundPixels }
            .sorted { left, right in
                (left.map(\.offset).min() ?? .max) < (right.map(\.offset).min() ?? .max)
            }
        guard !substantialForegroundClusters.isEmpty else { return nil }

        let evaluatedClusters = substantialForegroundClusters.compactMap { cluster -> (ObservedRGBPixel, Double)? in
            let coreCandidates = cluster.filter { candidate in
                let pixel = candidate.element
                let ratio = (max(background.luminance, pixel.luminance) + 0.05)
                    / (min(background.luminance, pixel.luminance) + 0.05)
                return ratio >= requiredContrastRatio
            }
            guard coreCandidates.count >= minimumForegroundPixels else { return nil }
            let coreOffsets = Set(coreCandidates.map(\.offset))
            guard cluster.allSatisfy({ candidate in
                coreOffsets.contains(candidate.offset)
                    || isWithinPixelRadius(
                        candidate.offset,
                        of: coreOffsets,
                        width: width,
                        radius: 2
                    )
            }) else {
                return nil
            }
            let corePixels = coreCandidates.map(\.element)
            let color = average(corePixels)
            let ratio = (max(background.luminance, color.luminance) + 0.05)
                / (min(background.luminance, color.luminance) + 0.05)
            return (color, ratio)
        }
        guard evaluatedClusters.count == substantialForegroundClusters.count else { return nil }
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

    private static func spatialComponents(
        in candidates: [(offset: Int, element: ObservedRGBPixel)],
        width: Int
    ) -> [[(offset: Int, element: ObservedRGBPixel)]] {
        let pixelsByOffset = Dictionary(uniqueKeysWithValues: candidates.map { ($0.offset, $0.element) })
        var unvisitedOffsets = Set(pixelsByOffset.keys)
        var components: [[(offset: Int, element: ObservedRGBPixel)]] = []

        while let startOffset = unvisitedOffsets.first {
            var pendingOffsets = [startOffset]
            var component: [(offset: Int, element: ObservedRGBPixel)] = []
            unvisitedOffsets.remove(startOffset)

            while let offset = pendingOffsets.popLast() {
                guard let pixel = pixelsByOffset[offset] else { continue }
                component.append((offset: offset, element: pixel))
                let row = offset / width
                let column = offset % width

                for rowDelta in -1...1 {
                    for columnDelta in -1...1 where rowDelta != 0 || columnDelta != 0 {
                        let neighborRow = row + rowDelta
                        let neighborColumn = column + columnDelta
                        guard neighborRow >= 0,
                              neighborColumn >= 0,
                              neighborColumn < width else {
                            continue
                        }
                        let neighborOffset = neighborRow * width + neighborColumn
                        if unvisitedOffsets.remove(neighborOffset) != nil {
                            pendingOffsets.append(neighborOffset)
                        }
                    }
                }
            }
            components.append(component)
        }

        return components
    }

    private static func isWithinPixelRadius(
        _ offset: Int,
        of targetOffsets: Set<Int>,
        width: Int,
        radius: Int
    ) -> Bool {
        let row = offset / width
        let column = offset % width
        for rowDelta in -radius...radius {
            for columnDelta in -radius...radius {
                let targetRow = row + rowDelta
                let targetColumn = column + columnDelta
                guard targetRow >= 0,
                      targetColumn >= 0,
                      targetColumn < width else {
                    continue
                }
                if targetOffsets.contains(targetRow * width + targetColumn) {
                    return true
                }
            }
        }
        return false
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
