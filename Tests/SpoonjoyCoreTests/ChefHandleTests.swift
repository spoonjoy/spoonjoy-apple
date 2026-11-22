import Testing
@testable import SpoonjoyCore

@Suite("Chef handles break like web's")
struct ChefHandleTests {
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

    @Test("a line with a handle in it wraps between words and after the handle's separators, never inside a word")
    func lineWordsSplitAtSpacesAndSeparators() {
        let words = ChefHandle.lineWords("By codex_native_r44976376606a1x1aebf1_1 · 3 recipes")
        #expect(words.map(\.text) == ["By", "codex_", "native_", "r44976376606a1x1aebf1_1", "·", "3", "recipes"])
        #expect(words.map(\.joinsPrevious) == [false, false, true, true, false, false, false])
        // Pieces of one word joined back with no space give the word again.
        #expect(ChefHandle.lineWords("maya_k.r4-2").map(\.text).joined() == "maya_k.r4-2")
        #expect(ChefHandle.lineWords("maya") == [LineWord(text: "maya", joinsPrevious: false)])
        #expect(ChefHandle.lineWords("  ").isEmpty)
    }

    @Test("a line's plain text breaks only after a handle's separators, with nothing visible added")
    func lineBreaksAtSeparators() {
        let line = ChefHandle.breakingAtSeparators("by codex_native.r4-2")
        #expect(line == "by codex_\u{200B}native.\u{200B}r4-\u{200B}2")
        #expect(line.replacingOccurrences(of: "\u{200B}", with: "") == "by codex_native.r4-2")
        #expect(ChefHandle.breakingAtSeparators("") == "")
    }
}
