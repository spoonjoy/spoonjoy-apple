import Foundation

/// The cook-mode screens open right now, one per window, each named by a token. The owner is the screen the cook
/// used last (it appeared, its window became active, or its progress changed); Siri, the Live Activity buttons and the
/// session activity follow the owner. When the owner leaves, the session passes to the screen used before it, so a
/// window still cooking never loses it. A fold, a rotation or a Split View resize rebuilds a screen; the mic follows
/// it to its replacement in either disappear/appear order, and never to another window's screen.
public struct CookSessionRegistry<Entry> {
    /// How long after a screen leaves a new screen for the same recipe counts as its replacement, in seconds.
    public static var rebuildWindow: TimeInterval { 1 }

    private struct Screen {
        let token: UUID
        var recipeID: String
        var entry: Entry
        let registeredAt: TimeInterval
    }

    /// Least recently used first; the owner is last.
    private var screens: [Screen] = []
    /// A screen that left with its mic on and no replacement yet.
    private var micLeft: (recipeID: String, at: TimeInterval)?

    public init() {}

    public var owner: UUID? { screens.last?.token }
    public var ownerEntry: Entry? { screens.last?.entry }
    public var count: Int { screens.count }

    public func entry(for token: UUID) -> Entry? {
        screens.first { $0.token == token }?.entry
    }

    /// Every screen but `token`'s, so turning one mic on can turn the others off.
    public func entries(except token: UUID) -> [Entry] {
        screens.filter { $0.token != token }.map(\.entry)
    }

    public struct Registered: Equatable {
        /// The owner changed, so the session activity shows a different screen.
        public let ownerChanged: Bool
        /// This screen replaced one that left with its mic on: turn its mic on.
        public let resumesVoice: Bool
    }

    /// Adds `token`'s screen, or updates it for a new recipe, and makes it the owner.
    public mutating func register(_ token: UUID, recipeID: String, entry: Entry, at now: TimeInterval) -> Registered {
        let previousOwner = owner
        let registeredAt = screens.first { $0.token == token }?.registeredAt ?? now
        screens.removeAll { $0.token == token }
        screens.append(Screen(token: token, recipeID: recipeID, entry: entry, registeredAt: registeredAt))
        var resumes = false
        if let left = micLeft {
            micLeft = nil
            resumes = left.recipeID == recipeID && now - left.at <= Self.rebuildWindow
        }
        return Registered(ownerChanged: previousOwner != token, resumesVoice: resumes)
    }

    /// The cook used `token`'s screen. Returns true when that moved the session to it.
    public mutating func use(_ token: UUID) -> Bool {
        guard owner != token, let index = screens.firstIndex(where: { $0.token == token }) else {
            return false
        }
        screens.append(screens.remove(at: index))
        return true
    }

    public struct Left {
        /// The session moved to another screen.
        public let ownerChanged: Bool
        /// No cook-mode screen is left: the session ends.
        public let sessionEnded: Bool
        /// The screen that replaces the one that left, when it already appeared and the mic was on: turn its mic on.
        public let resumeVoiceIn: Entry?
    }

    /// Removes `token`'s screen. A screen that never registered, or already left, changes nothing.
    public mutating func unregister(_ token: UUID, voiceOn: Bool, at now: TimeInterval) -> Left {
        guard let index = screens.firstIndex(where: { $0.token == token }) else {
            return Left(ownerChanged: false, sessionEnded: false, resumeVoiceIn: nil)
        }
        let wasOwner = owner == token
        let leaving = screens.remove(at: index)
        var resume: Entry?
        if voiceOn {
            let replacement = screens.last {
                $0.recipeID == leaving.recipeID && now - $0.registeredAt <= Self.rebuildWindow && $0.registeredAt >= leaving.registeredAt
            }
            if let replacement {
                resume = replacement.entry
            } else {
                micLeft = (leaving.recipeID, now)
            }
        }
        return Left(ownerChanged: wasOwner && !screens.isEmpty, sessionEnded: screens.isEmpty, resumeVoiceIn: resume)
    }
}
