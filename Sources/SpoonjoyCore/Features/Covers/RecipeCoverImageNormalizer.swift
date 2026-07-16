import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum RecipeCoverImageNormalizationError: Error, Equatable, Sendable {
    case unsupportedContentType(String)
    case unreadableImage
    case jpegEncodingFailed
    case byteLimitExceeded(limitBytes: Int)
}

public struct RecipeCoverImageNormalizer: Equatable, Sendable {
    public static let serverUpload = RecipeCoverImageNormalizer()

    public let maxPixelDimension: Int
    public let maxOutputBytes: Int
    public let jpegQualityCandidates: [Double]

    public init(
        maxPixelDimension: Int = 2048,
        maxOutputBytes: Int = 5 * 1_024 * 1_024,
        jpegQualityCandidates: [Double] = [0.92, 0.84, 0.76, 0.68, 0.60, 0.52, 0.44, 0.36]
    ) {
        self.maxPixelDimension = maxPixelDimension
        self.maxOutputBytes = maxOutputBytes
        self.jpegQualityCandidates = jpegQualityCandidates
    }

    public func normalize(upload: NativeStagedMediaUpload) throws -> NativeStagedMediaUpload {
        try normalize(
            data: upload.data,
            contentType: upload.contentType,
            localStageID: upload.localStageID
        )
    }

    public func normalize(
        data: Data,
        contentType: String,
        localStageID: String
    ) throws -> NativeStagedMediaUpload {
        guard Self.supportedContentTypes.contains(contentType.lowercased()) else {
            throw RecipeCoverImageNormalizationError.unsupportedContentType(contentType)
        }
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, [
                  kCGImageSourceShouldCache: false
              ] as CFDictionary) else {
            throw RecipeCoverImageNormalizationError.unreadableImage
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw RecipeCoverImageNormalizationError.unreadableImage
        }

        for quality in jpegQualityCandidates {
            let jpeg = try Self.jpegData(from: image, quality: quality)
            if jpeg.count <= maxOutputBytes {
                return NativeStagedMediaUpload(
                    localStageID: localStageID,
                    fileName: "cover.jpg",
                    contentType: "image/jpeg",
                    data: jpeg
                )
            }
        }

        throw RecipeCoverImageNormalizationError.byteLimitExceeded(limitBytes: maxOutputBytes)
    }

    public static let supportedContentTypes: Set<String> = [
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp",
        "image/heic",
        "image/heif"
    ]

    private static func jpegData(from image: CGImage, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw RecipeCoverImageNormalizationError.jpegEncodingFailed
        }

        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw RecipeCoverImageNormalizationError.jpegEncodingFailed
        }

        return data as Data
    }
}
