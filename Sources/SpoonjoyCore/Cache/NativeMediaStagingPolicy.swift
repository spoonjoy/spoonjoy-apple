import Foundation

public enum NativeMediaStagingError: Error, Equatable, Sendable {
    case individualFileTooLarge(limitBytes: Int)
    case accountByteCapReached(limitBytes: Int, silentEvictionAllowed: Bool)
    case accountFileCapReached(limitFiles: Int, silentEvictionAllowed: Bool)
    case generatedPreviewCapReached(limitBytes: Int)
}

public enum NativeMediaStagingDecision: Equatable, Sendable {
    case accepted
    case rejected(NativeMediaStagingError)
}

public struct NativeMediaDurableMetadata: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment
    public let localStageID: String
    public let contentType: String
    public let byteCount: Int
    public let createdAt: Date
    public let privacySafeRelativePath: String
    public let originalFilename: String?
    public let rawLocalFileURL: URL?
}

public struct NativeMediaStagingMetadata: Equatable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment
    public let localStageID: String
    public let contentType: String
    public let byteCount: Int
    public let createdAt: Date
    public let privacySafeRelativePath: String
    public let durableMetadata: NativeMediaDurableMetadata

    public init(
        accountID: String,
        environment: NativeCacheEnvironment,
        localStageID: String,
        originalFilename: String,
        contentType: String,
        byteCount: Int,
        createdAt: Date
    ) throws {
        self.accountID = accountID
        self.environment = environment
        self.localStageID = localStageID
        self.contentType = contentType
        self.byteCount = byteCount
        self.createdAt = createdAt
        let privacySafeRelativePath = "\(accountID)/\(environment.rawValue)/v2/\(localStageID).\(Self.fileExtension(for: contentType, submittedFilename: originalFilename))"
        self.privacySafeRelativePath = privacySafeRelativePath
        self.durableMetadata = NativeMediaDurableMetadata(
            accountID: accountID,
            environment: environment,
            localStageID: localStageID,
            contentType: contentType,
            byteCount: byteCount,
            createdAt: createdAt,
            privacySafeRelativePath: privacySafeRelativePath,
            originalFilename: nil,
            rawLocalFileURL: nil
        )
    }

    private static func fileExtension(for contentType: String, submittedFilename: String) -> String {
        switch contentType.lowercased() {
        case "image/jpeg", "image/jpg":
            "jpeg"
        case "image/png":
            "png"
        case "image/heic":
            "heic"
        default:
            URL(fileURLWithPath: submittedFilename).pathExtension.lowercased().isEmpty
                ? "bin"
                : URL(fileURLWithPath: submittedFilename).pathExtension.lowercased()
        }
    }
}

public struct NativeMediaStagingPolicy: Equatable, Sendable {
    public static let offlineProductContract = NativeMediaStagingPolicy()

    public let maxIndividualUserSelectedBytes = 25 * 1_024 * 1_024
    public let maxGeneratedPreviewBytesPerAccount = 128 * 1_024 * 1_024
    public let maxUnsyncedUserSelectedBytesPerAccount = 512 * 1_024 * 1_024
    public let maxUnsyncedUserSelectedFilesPerAccount = 100
    public let allowsSilentEvictionOfUnsyncedUserMedia = false

    public init() {}

    public func evaluateNewUserSelectedMedia(
        byteCount: Int,
        existingUnsyncedBytes: Int,
        existingUnsyncedFileCount: Int
    ) -> NativeMediaStagingDecision {
        if byteCount > maxIndividualUserSelectedBytes {
            return .rejected(.individualFileTooLarge(limitBytes: maxIndividualUserSelectedBytes))
        }
        if existingUnsyncedBytes + byteCount > maxUnsyncedUserSelectedBytesPerAccount {
            return .rejected(.accountByteCapReached(
                limitBytes: maxUnsyncedUserSelectedBytesPerAccount,
                silentEvictionAllowed: false
            ))
        }
        if existingUnsyncedFileCount + 1 > maxUnsyncedUserSelectedFilesPerAccount {
            return .rejected(.accountFileCapReached(
                limitFiles: maxUnsyncedUserSelectedFilesPerAccount,
                silentEvictionAllowed: false
            ))
        }

        return .accepted
    }

    public func evaluateGeneratedPreview(bytesAfterWrite: Int) -> NativeMediaStagingDecision {
        if bytesAfterWrite > maxGeneratedPreviewBytesPerAccount {
            return .rejected(.generatedPreviewCapReached(limitBytes: maxGeneratedPreviewBytesPerAccount))
        }

        return .accepted
    }
}
