import Foundation

public struct PaginationCursor: RawRepresentable, Codable, Equatable {
    public let rawValue: String

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        self.rawValue = trimmed
    }
}
