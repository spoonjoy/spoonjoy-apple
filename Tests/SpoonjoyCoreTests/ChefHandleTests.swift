import Testing
@testable import SpoonjoyCore

@Suite("Chef handles break like web's")
struct ChefHandleTests {
    @Test("a handle can break between any two characters, with no hyphen and nothing visible added")
    func handleBreaksAnywhere() {
        let handle = ChefHandle.breakingAnywhere("codex_native_r42")

        #expect(handle.hasPrefix("@c\u{200B}o\u{200B}d"))
        #expect(handle.replacingOccurrences(of: "\u{200B}", with: "") == "@codex_native_r42")
        #expect(!handle.contains("-"))
        // One break point after "@" and between every pair of characters.
        #expect(handle.filter { $0 == "\u{200B}" }.count == "codex_native_r42".count - 1)
    }

    @Test("a title handle breaks only after its separators, so a line never ends inside a word")
    func titleHandleBreaksAtWords() {
        let handle = ChefHandle.breakingAtWords("codex_native.r4-2")

        #expect(handle == "@codex_\u{200B}native.\u{200B}r4-\u{200B}2")
        #expect(handle.replacingOccurrences(of: "\u{200B}", with: "") == "@codex_native.r4-2")
        #expect(ChefHandle.breakingAtWords("maya") == "@maya")
        #expect(ChefHandle.breakingAtWords("") == "@")
    }

    @Test("at the largest text sizes a title handle splits into whole words, keeping a short tail with its word")
    func titleHandleWords() {
        #expect(ChefHandle.words("codex_native.r4-2") == ["@codex_", "native.", "r4-2"])
        #expect(ChefHandle.words("codex_native_r44956404363a1x8e1958_1") == ["@codex_", "native_", "r44956404363a1x8e1958_1"])
        #expect(ChefHandle.words("maya") == ["@maya"])
        #expect(ChefHandle.words("") == ["@"])
        #expect(ChefHandle.words("a_b").joined() == "@a_b")
        #expect(ChefHandle.words("maya_") == ["@maya_"])
    }

    @Test("an empty handle is just the at sign")
    func emptyHandle() {
        #expect(ChefHandle.breakingAnywhere("") == "@")
    }

    @Test("a byline handle breaks anywhere too, with no at sign and nothing visible added")
    func bylineHandleBreaksAnywhere() {
        let handle = ChefHandle.wrapping("codex_native_r42")

        #expect(handle.hasPrefix("c\u{200B}o\u{200B}d"))
        #expect(handle.replacingOccurrences(of: "\u{200B}", with: "") == "codex_native_r42")
        #expect(!handle.contains("@"))
        #expect(ChefHandle.wrapping("") == "")
    }
}
