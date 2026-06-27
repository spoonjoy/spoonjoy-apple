import Foundation

public enum CaptureDraftSource: String, Codable, Equatable, Sendable {
    case text
    case url
    case image
    case cameraImage = "camera-image"
    case photoLibraryImage = "photo-library-image"
    case shareSheetURL = "share-sheet-url"
    case jsonLD = "json-ld"
    case videoURL = "video-url"
}

public enum CaptureDraftStatus: String, Codable, Equatable, Sendable {
    case localOnly
}

public enum CaptureDraftImportReadiness: String, Codable, Equatable, Sendable {
    case ready
    case needsTextRecognition
}

public enum CaptureDraftValidationError: Error, Equatable, CustomStringConvertible {
    case emptyDraft(String)

    public var description: String {
        switch self {
        case .emptyDraft(let id):
            "Capture draft \(id) must include text or an image reference."
        }
    }
}

public enum CaptureDraftImportError: Error, Equatable, Sendable {
    case needsTextRecognition
    case missingImportSource(String)
}

public struct CaptureDraft: Codable, Equatable, Sendable {
    public let id: String
    public let source: CaptureDraftSource
    public let rawText: String
    public let imageAssetIdentifier: String?
    public let sourceURL: URL?
    public let capturedURL: URL?
    public let jsonLD: JSONValue?
    public let createdAt: String
    public let status: CaptureDraftStatus

    public var previewLines: [String] {
        let text = rawText.isEmpty ? capturedURL?.absoluteString ?? "" : rawText
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public var importReadiness: CaptureDraftImportReadiness {
        switch source {
        case .cameraImage, .photoLibraryImage, .image:
            return rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .needsTextRecognition : .ready
        case .text, .url, .shareSheetURL, .jsonLD, .videoURL:
            return .ready
        }
    }

    public var canCreateServerRecipe: Bool {
        importReadiness == .ready
    }

    public init(
        id: String,
        source: CaptureDraftSource,
        rawText: String,
        imageAssetIdentifier: String?,
        sourceURL: URL? = nil,
        capturedURL: URL? = nil,
        jsonLD: JSONValue? = nil,
        createdAt: String,
        status: CaptureDraftStatus = .localOnly
    ) {
        self.id = id
        self.source = source
        self.rawText = rawText
        self.imageAssetIdentifier = imageAssetIdentifier
        self.sourceURL = sourceURL
        self.capturedURL = capturedURL
        self.jsonLD = jsonLD
        self.createdAt = createdAt
        self.status = status
    }

    public static func localText(id: String, rawText: String, createdAt: String) throws -> CaptureDraft {
        try localText(id: id, rawText: rawText, sourceURL: nil, createdAt: createdAt)
    }

    public static func localText(id: String, rawText: String, sourceURL: URL?, createdAt: String) throws -> CaptureDraft {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CaptureDraftValidationError.emptyDraft(id)
        }

        return CaptureDraft(
            id: id,
            source: .text,
            rawText: trimmed,
            imageAssetIdentifier: nil,
            sourceURL: sourceURL,
            createdAt: createdAt,
            status: .localOnly
        )
    }

    public static func localText(id: String, text: String, createdAt: String) throws -> CaptureDraft {
        try localText(id: id, rawText: text, createdAt: createdAt)
    }

    public static func importURL(id: String, url: URL, createdAt: String) throws -> CaptureDraft {
        try urlDraft(id: id, source: .url, url: url, createdAt: createdAt)
    }

    public static func shareSheetURL(id: String, url: URL, createdAt: String) throws -> CaptureDraft {
        try urlDraft(id: id, source: .shareSheetURL, url: url, createdAt: createdAt)
    }

    public static func videoURL(id: String, url: URL, createdAt: String) throws -> CaptureDraft {
        try urlDraft(id: id, source: .videoURL, url: url, createdAt: createdAt)
    }

    public static func cameraImage(
        id: String,
        assetIdentifier: String,
        recognizedText: String?,
        createdAt: String
    ) throws -> CaptureDraft {
        imageDraft(
            id: id,
            source: .cameraImage,
            assetIdentifier: assetIdentifier,
            recognizedText: recognizedText,
            createdAt: createdAt
        )
    }

    public static func photoLibraryImage(
        id: String,
        assetIdentifier: String,
        recognizedText: String?,
        createdAt: String
    ) throws -> CaptureDraft {
        imageDraft(
            id: id,
            source: .photoLibraryImage,
            assetIdentifier: assetIdentifier,
            recognizedText: recognizedText,
            createdAt: createdAt
        )
    }

    public static func jsonLD(id: String, jsonLD: JSONValue, sourceURL: URL?, createdAt: String) throws -> CaptureDraft {
        CaptureDraft(
            id: id,
            source: .jsonLD,
            rawText: "",
            imageAssetIdentifier: nil,
            sourceURL: sourceURL,
            jsonLD: jsonLD,
            createdAt: createdAt
        )
    }

    public func importSource() throws -> NativeMutationSource {
        switch source {
        case .url, .shareSheetURL:
            guard let capturedURL else {
                throw CaptureDraftImportError.missingImportSource(id)
            }
            return .url(capturedURL)
        case .videoURL:
            guard let capturedURL else {
                throw CaptureDraftImportError.missingImportSource(id)
            }
            return .videoURL(capturedURL)
        case .text:
            return .textWithMetadata(rawText, sourceURL: sourceURL, capture: nil)
        case .cameraImage, .photoLibraryImage, .image:
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw CaptureDraftImportError.needsTextRecognition
            }
            return .textWithMetadata(
                trimmed,
                sourceURL: nil,
                capture: NativeCaptureTextMetadata(
                    source: source == .photoLibraryImage ? .photoLibrary : .camera,
                    assetIdentifier: imageAssetIdentifier
                )
            )
        case .jsonLD:
            guard let jsonLD else {
                throw CaptureDraftImportError.missingImportSource(id)
            }
            return .jsonLD(jsonLD, sourceURL: sourceURL)
        }
    }

    private static func urlDraft(id: String, source: CaptureDraftSource, url: URL, createdAt: String) throws -> CaptureDraft {
        guard let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            throw CaptureDraftValidationError.emptyDraft(id)
        }
        let safeURL = url
        return CaptureDraft(
            id: id,
            source: source,
            rawText: safeURL.absoluteString,
            imageAssetIdentifier: nil,
            capturedURL: safeURL,
            createdAt: createdAt
        )
    }

    private static func imageDraft(
        id: String,
        source: CaptureDraftSource,
        assetIdentifier: String,
        recognizedText: String?,
        createdAt: String
    ) -> CaptureDraft {
        CaptureDraft(
            id: id,
            source: source,
            rawText: recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            imageAssetIdentifier: assetIdentifier,
            createdAt: createdAt
        )
    }
}
