import Foundation

public enum JSONFileStoreSource: String, Codable, Equatable {
    case file
    case fallback
    case fallbackAfterCorruption
}

public enum JSONFileStoreError: Error, Equatable {
    case corruptJSON(String)
}

public struct JSONFileStoreRecord<Value: Equatable>: Equatable {
    public let value: Value
    public let source: JSONFileStoreSource

    public init(value: Value, source: JSONFileStoreSource) {
        self.value = value
        self.source = source
    }
}

public struct JSONFileStore<Value: Codable & Equatable> {
    private let fileURL: URL
    private let fallbackData: Data?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL,
        fallbackData: Data? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        encoder.outputFormatting = [.sortedKeys]

        self.fileURL = fileURL
        self.fallbackData = fallbackData
        self.encoder = encoder
        self.decoder = decoder
    }

    public func load() throws -> JSONFileStoreRecord<Value>? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            guard let fallbackData else {
                return nil
            }

            return JSONFileStoreRecord(value: try decoder.decode(Value.self, from: fallbackData), source: .fallback)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return JSONFileStoreRecord(value: try decoder.decode(Value.self, from: data), source: .file)
        } catch {
            guard let fallbackData else {
                throw JSONFileStoreError.corruptJSON(fileURL.path)
            }

            return JSONFileStoreRecord(
                value: try decoder.decode(Value.self, from: fallbackData),
                source: .fallbackAfterCorruption
            )
        }
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(value).write(to: fileURL, options: .atomic)
    }

    public func delete() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: fileURL)
    }
}
