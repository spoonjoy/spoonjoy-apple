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
