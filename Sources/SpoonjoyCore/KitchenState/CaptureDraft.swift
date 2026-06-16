import Foundation

public enum CaptureDraftSource: String, Codable, Equatable {
    case text
    case image
}

public enum CaptureDraftStatus: String, Codable, Equatable {
    case localOnly
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

public struct CaptureDraft: Codable, Equatable {
    public let id: String
    public let source: CaptureDraftSource
    public let rawText: String
    public let imageAssetIdentifier: String?
    public let createdAt: String
    public let status: CaptureDraftStatus

    public var previewLines: [String] {
        rawText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public var canCreateServerRecipe: Bool {
        false
    }

    public static func localText(id: String, rawText: String, createdAt: String) throws -> CaptureDraft {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CaptureDraftValidationError.emptyDraft(id)
        }

        return CaptureDraft(
            id: id,
            source: .text,
            rawText: trimmed,
            imageAssetIdentifier: nil,
            createdAt: createdAt,
            status: .localOnly
        )
    }
}
