import Foundation

/// What a report points at. App Review guideline 1.2 asks apps that show other people's content to let a person
/// report it and block its author.
public enum ContentReportTargetType: String, Codable, CaseIterable, Sendable {
    case recipe
    case chef
    case spoon
    case cookbook
}

public enum ContentReportReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case spam
    case offensive
    case harassment
    case copyright
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .spam: "Spam or misleading"
        case .offensive: "Offensive or inappropriate"
        case .harassment: "Harassment or hate"
        case .copyright: "Copied without permission"
        case .other: "Something else"
        }
    }
}

public struct ContentReportTarget: Codable, Hashable, Sendable {
    public let type: ContentReportTargetType
    public let id: String

    public init(type: ContentReportTargetType, id: String) {
        self.type = type
        self.id = id
    }
}

public struct ContentReportReceipt: Codable, Equatable, Sendable {
    public let id: String
    public let status: String
}

public struct ContentReportResponse: Codable, Equatable, Sendable {
    public let report: ContentReportReceipt
}

public struct BlockedChef: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let username: String
    public let displayName: String?
    public let photoURL: URL?

    public init(id: String, username: String, displayName: String? = nil, photoURL: URL? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.photoURL = photoURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case photoURL = "photoUrl"
    }

    /// The name a person recognises: the display name when the chef set one, otherwise the handle.
    public var name: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        return "@\(username)"
    }
}

public struct ChefBlock: Codable, Equatable, Sendable {
    public let chef: BlockedChef
    public let createdAt: String

    public init(chef: BlockedChef, createdAt: String) {
        self.chef = chef
        self.createdAt = createdAt
    }
}

public struct ChefBlockListResponse: Codable, Equatable, Sendable {
    public let blocks: [ChefBlock]
}

public struct ChefBlockResponse: Codable, Equatable, Sendable {
    public let block: ChefBlock
}

public struct ChefUnblockResponse: Codable, Equatable, Sendable {
    public let unblocked: Bool
}

public enum ModerationRequests {
    /// POST /api/v1/reports.
    public static func report(target: ContentReportTarget, reason: ContentReportReason, details: String?) throws -> APIRequestBuilder {
        var body: [String: Any] = [
            "targetType": target.type.rawValue,
            "targetId": target.id,
            "reason": reason.rawValue
        ]
        if let details = details?.trimmingCharacters(in: .whitespacesAndNewlines), !details.isEmpty {
            body["details"] = details
        }
        return try APIRequestSupport.privateJSON(method: .post, pathComponents: ["api", "v1", "reports"], body: body)
    }

    /// GET /api/v1/blocks: the chefs this account blocked.
    public static func blocks() -> APIRequestBuilder {
        APIRequestSupport.privateRead(pathComponents: ["api", "v1", "blocks"])
    }

    /// POST /api/v1/blocks.
    public static func block(chefID: String) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(method: .post, pathComponents: ["api", "v1", "blocks"], body: ["chefId": chefID])
    }

    /// DELETE /api/v1/blocks/:chefId.
    public static func unblock(chefID: String) -> APIRequestBuilder {
        APIRequestSupport.privateRead(method: .delete, pathComponents: ["api", "v1", "blocks", chefID])
    }
}

/// The chefs this person blocked and the things they reported, kept on the device so blocked and reported content
/// disappears at once and stays gone after a relaunch, before the server's own filtering catches up.
public struct ChefModerationLedger: Codable, Equatable, Sendable {
    public private(set) var blockedChefs: [BlockedChef]
    public private(set) var hiddenTargets: Set<ContentReportTarget>

    public init(blockedChefs: [BlockedChef] = [], hiddenTargets: Set<ContentReportTarget> = []) {
        self.blockedChefs = blockedChefs
        self.hiddenTargets = hiddenTargets
    }

    public func isBlocked(chefID: String) -> Bool {
        blockedChefs.contains { $0.id == chefID }
    }

    public func isHidden(_ target: ContentReportTarget) -> Bool {
        hiddenTargets.contains(target)
    }

    /// Whether a recipe should be left out: it was reported, or its chef is blocked.
    public func hidesRecipe(id: String, chefID: String) -> Bool {
        isBlocked(chefID: chefID) || isHidden(ContentReportTarget(type: .recipe, id: id))
    }

    /// Whether a search result should be left out: it was reported, it is a blocked chef, or a blocked chef owns it.
    public func hidesSearchResult(_ result: SearchSurfaceResult) -> Bool {
        if let ownerID = result.ownerID, isBlocked(chefID: ownerID) {
            return true
        }
        switch result.type {
        case .chef:
            return isBlocked(chefID: result.id) || isHidden(ContentReportTarget(type: .chef, id: result.id))
        case .recipe:
            return isHidden(ContentReportTarget(type: .recipe, id: result.id))
        case .cookbook:
            return isHidden(ContentReportTarget(type: .cookbook, id: result.id))
        case .shoppingListItem:
            return false
        }
    }

    public mutating func block(_ chef: BlockedChef) {
        blockedChefs.removeAll { $0.id == chef.id }
        blockedChefs.append(chef)
    }

    public mutating func unblock(chefID: String) {
        blockedChefs.removeAll { $0.id == chefID }
    }

    public mutating func hide(_ target: ContentReportTarget) {
        hiddenTargets.insert(target)
    }

    /// The server's list is the truth for blocks; reports stay hidden on this device.
    public mutating func replaceBlocks(with blocks: [ChefBlock]) {
        blockedChefs = blocks.map(\.chef)
    }
}

/// Keeps one ledger per account in the app's directory, so a second account on the device starts clean and the
/// journey reset, which empties that directory, clears it too.
public struct ChefModerationLedgerStore: Sendable {
    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public func fileURL(accountID: String) -> URL {
        let safeID = accountID.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? String($0) : "_" }
            .joined()
        return directoryURL.appendingPathComponent("moderation-\(safeID).json")
    }

    /// The saved ledger, or an empty one when there is none or it cannot be read.
    public func load(accountID: String) -> ChefModerationLedger {
        guard let data = try? Data(contentsOf: fileURL(accountID: accountID)),
              let ledger = try? JSONDecoder().decode(ChefModerationLedger.self, from: data) else {
            return ChefModerationLedger()
        }
        return ledger
    }

    public func save(_ ledger: ChefModerationLedger, accountID: String) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(ledger).write(to: fileURL(accountID: accountID), options: .atomic)
    }
}
