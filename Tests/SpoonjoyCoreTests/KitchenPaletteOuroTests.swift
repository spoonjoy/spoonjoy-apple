import Foundation
import OuroHX
import SwiftUI
import Testing

/// The app's `KitchenTableTheme` takes the colours whose meaning and value match OuroHX's cookbook theme from OuroHX,
/// and keeps its own where they differ. These tests hold every colour it takes to the hex it had before, so the swap
/// changes no pixel.
@Suite("Kitchen palette from OuroHX")
struct KitchenPaletteOuroTests {
    struct Swap: Sendable, CustomStringConvertible {
        let name: String
        let mode: String
        let token: String
        let hex: UInt32

        var description: String { "\(mode).\(name) = cookbook\(mode)(\\.\(token)) #\(String(format: "%06X", hex))" }
    }

    /// Every colour the theme takes from OuroHX, with the web hex it had before.
    static let swapped: [Swap] = [
        Swap(name: "bone", mode: "Day", token: "background", hex: 0xFBFAF4),
        Swap(name: "paper", mode: "Day", token: "card", hex: 0xFFFEFA),
        Swap(name: "vellum", mode: "Day", token: "muted", hex: 0xE8E9DF),
        Swap(name: "charcoal", mode: "Day", token: "foreground", hex: 0x28231D),
        Swap(name: "inkMuted", mode: "Day", token: "mutedForeground", hex: 0x635D54),
        Swap(name: "brass", mode: "Day", token: "primary", hex: 0x9B6834),
        Swap(name: "tomato", mode: "Day", token: "destructive", hex: 0xA24A38),
        Swap(name: "herb", mode: "Day", token: "success", hex: 0x596A4F),
        Swap(name: "boneNight", mode: "Night", token: "foreground", hex: 0xF2EEE6),
        Swap(name: "paperNight", mode: "Night", token: "card", hex: 0x282522),
        Swap(name: "vellumNight", mode: "Night", token: "muted", hex: 0x34302B),
        Swap(name: "inkMutedNight", mode: "Night", token: "mutedForeground", hex: 0xC8C0B4),
        Swap(name: "brassNight", mode: "Night", token: "primary", hex: 0xC4945C),
        Swap(name: "tomatoNight", mode: "Night", token: "destructive", hex: 0xE58263),
        Swap(name: "herbNight", mode: "Night", token: "success", hex: 0xA4B578)
    ]

    /// The colours Spoonjoy keeps as its own: OuroHX has a different value, a different meaning, or no token.
    static let kept: [String: UInt32] = [
        "action": 0x28231D,
        "actionDeep": 0x1F1B17,
        "photoCharcoal": 0x211F1B,
        "charcoalNight": 0x1F1D1A,
        "actionNight": 0xB9854B,
        "actionDeepNight": 0x95683A,
        "photoCharcoalNight": 0x1D1915,
        "pageNight": 0x1E1C19,
        "onPhotoNight": 0xF1E6D3
    ]

    static var tokens: [String: KeyPath<OuroColors, Color>] { [
        "background": \.background,
        "card": \.card,
        "muted": \.muted,
        "foreground": \.foreground,
        "mutedForeground": \.mutedForeground,
        "primary": \.primary,
        "destructive": \.destructive,
        "success": \.success
    ] }

    @Test("every colour taken from OuroHX resolves to the hex it had before", arguments: swapped)
    func swappedTokenKeepsItsHex(_ swap: Swap) throws {
        let palette = swap.mode == "Day" ? OuroTokens.cookbook.light : OuroTokens.cookbook.dark
        let token = try #require(Self.tokens[swap.token])
        let resolved = palette[keyPath: token].resolve(in: EnvironmentValues())
        #expect(Self.hex(resolved) == swap.hex, "\(swap)")
        #expect(resolved.opacity == 1, "\(swap)")
    }

    @Test("the theme takes exactly these colours from OuroHX, each written with its hex")
    func themeTakesExactlyTheSwappedColours() throws {
        let theme = try Self.themeSource()
        let pattern = try NSRegularExpression(pattern: #"static let (\w+) = cookbook(Day|Night)\(\\\.(\w+), 0x([0-9A-F]{6})\)"#)
        let found = pattern.matches(in: theme, range: NSRange(theme.startIndex..., in: theme)).map { match in
            let group = { (index: Int) in String(theme[Range(match.range(at: index), in: theme)!]) }
            return "\(group(2)).\(group(1)) = cookbook\(group(2))(\\.\(group(3))) #\(group(4))"
        }
        #expect(found == Self.swapped.map(\.description))
    }

    @Test("the colours Spoonjoy keeps stay its own web hex")
    func keptColoursStayWebColours() throws {
        let theme = try Self.themeSource()
        for (name, hex) in Self.kept {
            #expect(theme.contains("static let \(name) = webColor(0x\(String(format: "%06X", hex)))"), "\(name)")
        }
    }

    @Test("Spoonjoy's night page is not OuroHX's cookbook dark background")
    func nightPageDiffersFromOuroHX() {
        // Upstream question: https://github.com/ourostack/ouro-ui-apple/issues/15
        #expect(Self.hex(OuroTokens.cookbook.dark.background.resolve(in: EnvironmentValues())) == 0x1F1D1A)
        #expect(Self.kept["pageNight"] == 0x1E1C19)
    }

    static func hex(_ color: Color.Resolved) -> UInt32 {
        func byte(_ value: Float) -> UInt32 { UInt32((Double(value) * 255).rounded()) }
        return byte(color.red) << 16 | byte(color.green) << 8 | byte(color.blue)
    }

    static func themeSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"), encoding: .utf8)
    }
}
