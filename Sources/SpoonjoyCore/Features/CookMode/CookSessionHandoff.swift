import Foundation

/// Which cook-mode screen holds the open session. A fold, a rotation or a Split View resize rebuilds cook mode, and
/// the new screen can register before the old one leaves, so leaving clears the session only for its owner.
public struct CookSessionOwnership: Equatable, Sendable {
    public private(set) var owner: UUID?

    public init() {}

    public mutating func claim(_ token: UUID) {
        owner = token
    }

    /// True when `token` held the session, which is now free.
    public mutating func release(_ token: UUID) -> Bool {
        guard owner == token else {
            return false
        }
        owner = nil
        return true
    }
}

/// Carries the cook's mic choice across a rebuilt cook-mode screen when the old screen leaves first. A screen for the
/// same recipe that appears within `window` seconds turns the mic back on; after that, cook mode really closed.
public struct CookVoiceHandoff: Equatable, Sendable {
    public static let window: TimeInterval = 1

    private var recipeID: String?
    private var leftAt: TimeInterval = 0

    public init() {}

    public mutating func leave(recipeID: String, voiceOn: Bool, at now: TimeInterval) {
        self.recipeID = voiceOn ? recipeID : nil
        leftAt = now
    }

    /// Whether the screen appearing now for `recipeID` should turn the mic back on. It is used once.
    public mutating func resumes(recipeID: String, at now: TimeInterval) -> Bool {
        defer { self.recipeID = nil }
        return self.recipeID == recipeID && now - leftAt <= Self.window
    }
}
