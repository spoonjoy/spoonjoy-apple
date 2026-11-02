import Foundation
import Testing
@testable import SpoonjoyCore

/// Cook mode in two windows (#192 release review I1, I2, Minor 1), and a screen rebuilt by a fold, rotation or resize
/// (1.1 final review I3). Entries stand in for each screen's registration.
@Suite("Cook session registry")
struct CookSessionRegistryTests {
    typealias Registry = CookSessionRegistry<String>
    let a = UUID(), b = UUID(), rebuilt = UUID()

    private func twoWindows() -> Registry {
        var registry = Registry()
        _ = registry.register(a, recipeID: "pasta", entry: "A", at: 0)
        _ = registry.register(b, recipeID: "soup", entry: "B", at: 10)
        return registry
    }

    @Test func theNewestScreenOwnsTheSession() {
        let registry = twoWindows()
        #expect(registry.owner == b)
        #expect(registry.ownerEntry == "B")
        #expect(registry.count == 2)
        #expect(registry.entry(for: a) == "A")
        #expect(registry.entry(for: UUID()) == nil)
    }

    @Test func theWindowTheCookUsesTakesTheSession() {
        var registry = twoWindows()
        let moved = registry.use(a)
        #expect(moved)
        #expect(registry.ownerEntry == "A")
        let again = registry.use(a)
        #expect(!again)
        let unknown = registry.use(UUID())
        #expect(!unknown)
    }

    @Test func closingTheOwnerPassesTheSessionToTheOtherWindow() {
        var registry = twoWindows()
        let left = registry.unregister(b, voiceOn: false, at: 20)
        #expect(left.ownerChanged)
        #expect(!left.sessionEnded)
        #expect(registry.ownerEntry == "A")
    }

    @Test func closingTheOtherWindowKeepsTheOwner() {
        var registry = twoWindows()
        let left = registry.unregister(a, voiceOn: false, at: 20)
        #expect(!left.ownerChanged)
        #expect(!left.sessionEnded)
        #expect(registry.ownerEntry == "B")
    }

    @Test func closingTheLastScreenEndsTheSession() {
        var registry = Registry()
        _ = registry.register(a, recipeID: "pasta", entry: "A", at: 0)
        let left = registry.unregister(a, voiceOn: false, at: 5)
        #expect(left.sessionEnded)
        #expect(!left.ownerChanged)
        #expect(registry.owner == nil)
        let again = registry.unregister(a, voiceOn: true, at: 6)
        #expect(!again.sessionEnded && !again.ownerChanged && again.resumeVoiceIn == nil)
    }

    @Test func eachMicTurnsTheOthersOff() {
        let registry = twoWindows()
        #expect(registry.entries(except: a) == ["B"])
        #expect(registry.entries(except: b) == ["A"])
    }

    @Test func reregisteringForANewRecipeKeepsItsPlace() {
        var registry = twoWindows()
        let registered = registry.register(b, recipeID: "stew", entry: "B2", at: 30)
        #expect(!registered.ownerChanged)
        #expect(registry.ownerEntry == "B2")
        #expect(registry.count == 2)
    }

    // Rebuilds (1.1 final review I3), now with another window open.

    @Test func rebuildWhereTheNewScreenAppearsFirstHandsItTheMic() {
        var registry = twoWindows()
        _ = registry.register(rebuilt, recipeID: "soup", entry: "B'", at: 30)
        let left = registry.unregister(b, voiceOn: true, at: 30.1)
        #expect(left.resumeVoiceIn == "B'")
        #expect(!left.ownerChanged)
        #expect(registry.ownerEntry == "B'")
    }

    @Test func rebuildWhereTheOldScreenLeavesFirstResumesTheMicOnTheNewOne() {
        var registry = twoWindows()
        let left = registry.unregister(b, voiceOn: true, at: 30)
        #expect(left.resumeVoiceIn == nil)
        let registered = registry.register(rebuilt, recipeID: "soup", entry: "B'", at: 30.2)
        #expect(registered.resumesVoice)
        #expect(registered.ownerChanged)
    }

    @Test func micDoesNotResumeWhenItWasOffOrTooLateOrAnotherRecipe() {
        var registry = twoWindows()
        _ = registry.unregister(b, voiceOn: false, at: 30)
        #expect(!registry.register(rebuilt, recipeID: "soup", entry: "B'", at: 30.1).resumesVoice)

        registry = twoWindows()
        _ = registry.unregister(b, voiceOn: true, at: 30)
        #expect(!registry.register(rebuilt, recipeID: "soup", entry: "B'", at: 30 + Registry.rebuildWindow + 0.1).resumesVoice)

        registry = twoWindows()
        _ = registry.unregister(b, voiceOn: true, at: 30)
        #expect(!registry.register(rebuilt, recipeID: "stew", entry: "B'", at: 30.1).resumesVoice)
        // Used once.
        #expect(!registry.register(UUID(), recipeID: "soup", entry: "C", at: 30.2).resumesVoice)
    }

    /// #192 review Minor 1: the same recipe in two windows. Closing one window's screen with its mic on must not
    /// turn on the mic in the other, older window.
    @Test func closingOneOfTwoWindowsOnTheSameRecipeLeavesTheOtherMicAlone() {
        var registry = Registry()
        _ = registry.register(a, recipeID: "pasta", entry: "A", at: 0)
        _ = registry.register(b, recipeID: "pasta", entry: "B", at: 10)
        let left = registry.unregister(b, voiceOn: true, at: 60)
        #expect(left.resumeVoiceIn == nil)
        #expect(registry.ownerEntry == "A")
        let leftA = registry.unregister(a, voiceOn: true, at: 60.1)
        #expect(leftA.resumeVoiceIn == nil)
    }
}
