import Foundation
import Testing
@testable import SpoonjoyCore

/// Cook mode in two windows (#192 release review I1, I2, Minor 1; #201 review), and a screen rebuilt by a fold,
/// rotation or resize (1.1 final review I3). Entries stand in for each screen's registration.
@Suite("Cook session registry")
struct CookSessionRegistryTests {
    typealias Registry = CookSessionRegistry<String>
    let a = UUID(), b = UUID(), a2 = UUID(), b2 = UUID()

    /// Window A on pasta, then window B on soup: B owns the session.
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

    @Test func turningOneMicOnTurnsTheOthersOff() {
        let registry = twoWindows()
        #expect(registry.entries(except: a) == ["B"])
        #expect(registry.entries(except: b) == ["A"])
    }

    @Test func reregisteringTheOwnerForANewRecipeKeepsItsPlace() {
        var registry = twoWindows()
        let registered = registry.register(b, recipeID: "stew", entry: "B2", at: 30)
        #expect(!registered.ownerChanged)
        #expect(registry.ownerEntry == "B2")
        #expect(registry.count == 2)
    }

    /// #201 review Low 2: a synced recipe edit re-registers the other window; the cook didn't use it.
    @Test func reregisteringTheOtherWindowLeavesTheOwnerAlone() {
        var registry = twoWindows()
        let registered = registry.register(a, recipeID: "pasta", entry: "A edited", at: 30)
        #expect(!registered.ownerChanged)
        #expect(registry.owner == b)
        #expect(registry.entry(for: a) == "A edited")
    }

    // Rebuilds in one window (1.1 final review I3).

    @Test func rebuildWhereTheNewScreenAppearsFirstHandsItTheMic() {
        var registry = twoWindows()
        _ = registry.register(b2, recipeID: "soup", entry: "B'", at: 30)
        let left = registry.unregister(b, voiceOn: true, at: 30.1)
        #expect(left.resumeVoiceIn == "B'")
        #expect(registry.ownerEntry == "B'")
    }

    @Test func rebuildWhereTheOldScreenLeavesFirstResumesTheMicOnTheNewOne() {
        var registry = twoWindows()
        let left = registry.unregister(b, voiceOn: true, at: 30)
        #expect(left.resumeVoiceIn == nil)
        #expect(left.awaitsReplacement)
        let registered = registry.register(b2, recipeID: "soup", entry: "B'", at: 30.2)
        #expect(registered.resumesVoice)
        #expect(registered.ownerChanged)
        #expect(registry.ownerEntry == "B'")
    }

    @Test func micDoesNotResumeWhenItWasOffOrTooLateOrAnotherRecipe() {
        var registry = twoWindows()
        _ = registry.unregister(b, voiceOn: false, at: 30)
        let micWasOff = registry.register(b2, recipeID: "soup", entry: "B'", at: 30.1)
        #expect(!micWasOff.resumesVoice)

        registry = twoWindows()
        _ = registry.unregister(b, voiceOn: true, at: 30)
        let tooLate = registry.register(b2, recipeID: "soup", entry: "B'", at: 30 + Registry.rebuildWindow + 0.1)
        #expect(!tooLate.resumesVoice)

        // Another recipe's screen leaves the vacancy for the right one (#201 review Minor 2).
        registry = twoWindows()
        _ = registry.unregister(b, voiceOn: true, at: 30)
        let otherRecipe = registry.register(b2, recipeID: "stew", entry: "B'", at: 30.1)
        #expect(!otherRecipe.resumesVoice)
        let soup = registry.register(UUID(), recipeID: "soup", entry: "C", at: 30.2)
        #expect(soup.resumesVoice)
        // Used once.
        let again = registry.register(UUID(), recipeID: "soup", entry: "D", at: 30.3)
        #expect(!again.resumesVoice)
    }

    /// A late replacement is a new screen: it takes the session like any newly opened one.
    @Test func aReplacementAfterTheWindowIsANewScreen() {
        var registry = twoWindows()
        _ = registry.use(a)
        _ = registry.unregister(b, voiceOn: false, at: 30)
        _ = registry.register(b2, recipeID: "soup", entry: "B'", at: 30 + Registry.rebuildWindow + 0.1)
        #expect(registry.owner == b2)
    }

    // Rotating with two windows (#201 review Important 1, Minor 2).

    @Test func rotatingBothWindowsNewScreensFirstKeepsTheOwner() {
        for order in [[a2, b2], [b2, a2]] {
            var registry = twoWindows()
            _ = registry.use(a) // A owns; B was opened after it.
            for token in order {
                let registered = registry.register(token, recipeID: token == a2 ? "pasta" : "soup", entry: token == a2 ? "A'" : "B'", at: 30)
                // The Live Activity doesn't flip while the old screens are still up.
                #expect(!registered.ownerChanged)
                #expect(registry.owner == a)
            }
            let leftB = registry.unregister(b, voiceOn: false, at: 30.1)
            let leftA = registry.unregister(a, voiceOn: true, at: 30.1)
            #expect(registry.owner == a2)
            #expect(leftA.resumeVoiceIn == "A'")
            #expect(leftB.resumeVoiceIn == nil)
        }
    }

    @Test func rotatingBothWindowsOldScreensFirstKeepsTheOwnerAndTheMic() {
        for order in [[a2, b2], [b2, a2]] {
            var registry = twoWindows()
            _ = registry.use(a)
            _ = registry.unregister(a, voiceOn: true, at: 30)
            _ = registry.unregister(b, voiceOn: false, at: 30)
            var resumed: [UUID] = []
            for token in order {
                let registered = registry.register(token, recipeID: token == a2 ? "pasta" : "soup", entry: "", at: 30.1)
                if registered.resumesVoice { resumed.append(token) }
            }
            #expect(registry.owner == a2)
            #expect(resumed == [a2])
        }
    }

    @Test func rotatingWithTheOwnerLeavingFirstWaitsForItsReplacement() {
        var registry = twoWindows()
        let left = registry.unregister(b, voiceOn: false, at: 30)
        // A holds the session only until B's replacement appears.
        #expect(left.ownerChanged && left.awaitsReplacement)
        _ = registry.register(b2, recipeID: "soup", entry: "B'", at: 30.1)
        #expect(registry.owner == b2)
        let closing = registry.unregister(a, voiceOn: false, at: 40)
        #expect(!closing.awaitsReplacement)
    }

    /// #192 review Minor 1: the same recipe in two windows. Closing the newer one with its mic on, within a second
    /// of opening it, must not turn on the mic in the older one.
    @Test func closingOneOfTwoWindowsOnTheSameRecipeLeavesTheOtherMicAlone() {
        var registry = Registry()
        _ = registry.register(a, recipeID: "pasta", entry: "A", at: 0)
        _ = registry.register(b, recipeID: "pasta", entry: "B", at: 0.4)
        let left = registry.unregister(b, voiceOn: true, at: 0.8)
        #expect(left.resumeVoiceIn == nil)
        #expect(registry.ownerEntry == "A")
    }

    /// Opening the same recipe in another window doesn't take the session; using it does. A pairing that outlived
    /// the rebuild window lapses, and a rebuild pairs with the most recently used window on its recipe.
    @Test func sameRecipeWindowsPairOnlyWithinTheRebuildWindow() {
        var registry = Registry()
        let c = UUID(), e = UUID()
        _ = registry.register(a, recipeID: "pasta", entry: "A", at: 0)
        _ = registry.register(b, recipeID: "pasta", entry: "B", at: 0)
        _ = registry.register(c, recipeID: "pasta", entry: "C", at: 0)
        #expect(registry.owner == a)
        // B leaves long after C appeared: C was a window of its own, not B's replacement.
        let leftB = registry.unregister(b, voiceOn: true, at: 10)
        #expect(leftB.resumeVoiceIn == nil)
        // A and C are both unpaired; a rebuild pairs with A, the one used last.
        _ = registry.register(e, recipeID: "pasta", entry: "E", at: 20)
        let leftA = registry.unregister(a, voiceOn: true, at: 20.1)
        #expect(leftA.resumeVoiceIn == "E")
        #expect(registry.owner == e)
        let moved = registry.use(c)
        #expect(moved)
    }

    // Coming to the front (#201 review Important 2).

    @Test func comingToTheFrontAloneTakesTheSession() {
        var registry = twoWindows()
        registry.sceneActive(b, false)
        registry.sceneActive(a, true)
        let claimed = registry.claimIfOnlyActive(a)
        #expect(claimed)
        #expect(registry.owner == a)
        let again = registry.claimIfOnlyActive(a)
        #expect(!again)
    }

    /// Unlocking, Control Center or an alert brings both Split View windows back together: nothing moves,
    /// whichever window's phase change runs last.
    @Test func bothWindowsComingBackTogetherMovesNothing() {
        for order in [[a, b], [b, a]] {
            var registry = twoWindows()
            registry.sceneActive(a, false)
            registry.sceneActive(b, false)
            for token in order { registry.sceneActive(token, true) }
            for token in order {
                let claimed = registry.claimIfOnlyActive(token)
                #expect(!claimed)
            }
            #expect(registry.owner == b)
        }
    }

    @Test func aScreenThatLeftOrWentInactiveClaimsNothing() {
        var registry = twoWindows()
        registry.sceneActive(b, false)
        registry.sceneActive(a, false)
        let inactive = registry.claimIfOnlyActive(a)
        #expect(!inactive)
        registry.sceneActive(UUID(), true)
        let unknown = registry.claimIfOnlyActive(UUID())
        #expect(!unknown)
    }
}
