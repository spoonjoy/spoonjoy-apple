import Foundation

/// The cook-mode screens open right now, one per window, each named by a token. Siri, the Live Activity buttons and
/// the session activity follow the owner: the screen the cook used last (its progress changed there, it was spoken
/// to, or its window came to the front on its own). When the owner leaves, the session passes to the screen used
/// before it, so a window still cooking never loses it.
///
/// A fold, a rotation or a Split View resize rebuilds a screen under a new token, in either disappear/appear order.
/// The rebuilt screen takes the place of the one it replaces (its turn in the use order, and its mic) instead of
/// taking the session, so rotating with two windows leaves the session where it was.
public struct CookSessionRegistry<Entry> {
    /// How long after a screen leaves (or appears) a screen for the same recipe counts as its replacement, in seconds.
    public static var rebuildWindow: TimeInterval { 1 }

    private struct Screen {
        let token: UUID
        var recipeID: String
        var entry: Entry
        let registeredAt: TimeInterval
        /// Higher was used more recently; the highest owns the session.
        var rank: Double
        var isActive = true
        /// The screen this one appeared to replace, before that one left (new screen first).
        var replaces: UUID?
    }

    /// A screen that left before its replacement appeared (old screen first).
    private struct Vacancy {
        let recipeID: String
        let rank: Double
        let at: TimeInterval
        let voiceOn: Bool
    }

    private var screens: [Screen] = []
    private var vacancies: [Vacancy] = []
    private var lastRank: Double = 0

    public init() {}

    private var ownerScreen: Screen? { screens.max { $0.rank < $1.rank } }
    public var owner: UUID? { ownerScreen?.token }
    public var ownerEntry: Entry? { ownerScreen?.entry }
    public var count: Int { screens.count }

    public func entry(for token: UUID) -> Entry? {
        screens.first { $0.token == token }?.entry
    }

    /// Every screen but `token`'s, so turning one mic on can turn the others off.
    public func entries(except token: UUID) -> [Entry] {
        screens.filter { $0.token != token }.map(\.entry)
    }

    private mutating func nextRank() -> Double {
        lastRank += 1
        return lastRank
    }

    public struct Registered: Equatable {
        /// The owner changed, so the session activity shows a different screen.
        public let ownerChanged: Bool
        /// This screen replaced one that left with its mic on: turn its mic on.
        public let resumesVoice: Bool
    }

    /// Adds `token`'s screen, or updates it in place for a recipe change. A new screen takes the place of the screen
    /// it replaces, and otherwise owns the session.
    public mutating func register(_ token: UUID, recipeID: String, entry: Entry, at now: TimeInterval) -> Registered {
        let previousOwner = owner
        vacancies.removeAll { now - $0.at > Self.rebuildWindow }
        if let index = screens.firstIndex(where: { $0.token == token }) {
            screens[index].recipeID = recipeID
            screens[index].entry = entry
            return Registered(ownerChanged: false, resumesVoice: false)
        }
        var screen = Screen(token: token, recipeID: recipeID, entry: entry, registeredAt: now, rank: 0)
        var resumes = false
        if let vacancy = vacancies.lastIndex(where: { $0.recipeID == recipeID }) {
            screen.rank = vacancies[vacancy].rank
            resumes = vacancies[vacancy].voiceOn
            vacancies.remove(at: vacancy)
        } else if let replaced = screens
            .filter({ old in old.recipeID == recipeID && !screens.contains { $0.replaces == old.token } })
            .max(by: { $0.rank < $1.rank }) {
            // Just below the screen it may replace: it takes that screen's place if that one leaves.
            screen.rank = replaced.rank - 0.5
            screen.replaces = replaced.token
        } else {
            screen.rank = nextRank()
        }
        screens.append(screen)
        return Registered(ownerChanged: previousOwner != owner, resumesVoice: resumes)
    }

    /// The cook used `token`'s screen. Returns true when that moved the session to it.
    public mutating func use(_ token: UUID) -> Bool {
        guard owner != token, let index = screens.firstIndex(where: { $0.token == token }) else {
            return false
        }
        screens[index].rank = nextRank()
        return true
    }

    /// The window of `token`'s screen became active or stopped being active.
    public mutating func sceneActive(_ token: UUID, _ isActive: Bool) {
        if let index = screens.firstIndex(where: { $0.token == token }) {
            screens[index].isActive = isActive
        }
    }

    /// Coming to the front takes the session only when no other cook window is active: in Split View both windows
    /// come back together (unlock, Control Center, an alert), and which one reports last says nothing about use.
    public mutating func claimIfOnlyActive(_ token: UUID) -> Bool {
        guard screens.contains(where: { $0.token == token && $0.isActive }),
              !screens.contains(where: { $0.token != token && $0.isActive }) else {
            return false
        }
        return use(token)
    }

    public struct Left {
        /// The session moved to another screen.
        public let ownerChanged: Bool
        /// The owner left and its replacement may still appear, so the move may undo itself within `rebuildWindow`.
        public let awaitsReplacement: Bool
        /// No cook-mode screen is left: the session ends.
        public let sessionEnded: Bool
        /// The screen that replaces the one that left, when it already appeared and the mic was on: turn its mic on.
        public let resumeVoiceIn: Entry?
    }

    /// Removes `token`'s screen. A screen that never registered, or already left, changes nothing.
    public mutating func unregister(_ token: UUID, voiceOn: Bool, at now: TimeInterval) -> Left {
        guard let index = screens.firstIndex(where: { $0.token == token }) else {
            return Left(ownerChanged: false, awaitsReplacement: false, sessionEnded: false, resumeVoiceIn: nil)
        }
        let previousOwner = owner
        let leaving = screens.remove(at: index)
        var resume: Entry?
        var vacated = false
        if let replacement = screens.firstIndex(where: { $0.replaces == token && now - $0.registeredAt <= Self.rebuildWindow }) {
            screens[replacement].rank = leaving.rank
            screens[replacement].replaces = nil
            resume = voiceOn ? screens[replacement].entry : nil
        } else {
            vacancies.append(Vacancy(recipeID: leaving.recipeID, rank: leaving.rank, at: now, voiceOn: voiceOn))
            vacated = true
        }
        for other in screens.indices where screens[other].replaces == token {
            screens[other].replaces = nil
        }
        let ownerChanged = !screens.isEmpty && previousOwner != owner
        return Left(
            ownerChanged: ownerChanged,
            awaitsReplacement: ownerChanged && vacated && previousOwner == token,
            sessionEnded: screens.isEmpty,
            resumeVoiceIn: resume
        )
    }
}
