import Foundation
import OuroHX
import SwiftUI
import Testing

/// The app's `KitchenTableTheme` takes every colour, radius and shadow from OuroHX's cookbook theme, which ouro-ui-core
/// generates from the same tokens as web's stylesheet. These tests hold each colour to web's hex, so the theme
/// matches web exactly and no value is copied by hand.
@Suite("Kitchen palette from OuroHX")
struct KitchenPaletteOuroTests {
    struct Colour: Sendable, CustomStringConvertible {
        let name: String
        let mode: String
        let token: OuroExtraColor
        let hex: UInt32

        var scheme: ColorScheme { mode == "Day" ? .light : .dark }
        var description: String { "\(mode).\(name) = cookbook\(mode)(.\(token)) #\(String(format: "%06X", hex))" }
    }

    /// Every colour in the theme, with web's value (spoonjoy-v2 `app/styles/tailwind.css`, `:root` and `.dark`).
    static let colours: [Colour] = [
        Colour(name: "bone", mode: "Day", token: .sjBone, hex: 0xFBFAF4),
        Colour(name: "paper", mode: "Day", token: .sjBoneLift, hex: 0xFFFEFA),
        Colour(name: "vellum", mode: "Day", token: .sjVellum, hex: 0xE8E9DF),
        Colour(name: "charcoal", mode: "Day", token: .sjCharcoal, hex: 0x28231D),
        Colour(name: "inkMuted", mode: "Day", token: .sjCharcoalSoft, hex: 0x635D54),
        Colour(name: "brass", mode: "Day", token: .sjBrass, hex: 0x9B6834),
        Colour(name: "action", mode: "Day", token: .sjAction, hex: 0x28231D),
        Colour(name: "actionDeep", mode: "Day", token: .sjActionDeep, hex: 0x1F1B17),
        Colour(name: "tomato", mode: "Day", token: .sjTomato, hex: 0xA24A38),
        Colour(name: "herb", mode: "Day", token: .sjHerb, hex: 0x596A4F),
        Colour(name: "photoCharcoal", mode: "Day", token: .sjPhotoCharcoal, hex: 0x211F1B),
        Colour(name: "boneNight", mode: "Night", token: .sjBone, hex: 0xF2EEE6),
        Colour(name: "paperNight", mode: "Night", token: .sjBoneLift, hex: 0x282522),
        Colour(name: "vellumNight", mode: "Night", token: .sjVellum, hex: 0x34302B),
        Colour(name: "charcoalNight", mode: "Night", token: .sjCharcoal, hex: 0x1F1D1A),
        Colour(name: "inkMutedNight", mode: "Night", token: .sjCharcoalSoft, hex: 0xC8C0B4),
        Colour(name: "brassNight", mode: "Night", token: .sjBrass, hex: 0xC4945C),
        Colour(name: "actionNight", mode: "Night", token: .sjAction, hex: 0xB9854B),
        Colour(name: "actionDeepNight", mode: "Night", token: .sjActionDeep, hex: 0x95683A),
        Colour(name: "tomatoNight", mode: "Night", token: .sjTomato, hex: 0xE58263),
        Colour(name: "herbNight", mode: "Night", token: .sjHerb, hex: 0xA4B578),
        Colour(name: "photoCharcoalNight", mode: "Night", token: .sjPhotoCharcoal, hex: 0x1D1915),
        Colour(name: "pageNight", mode: "Night", token: .sjPage, hex: 0x1E1C19),
        Colour(name: "onPhotoNight", mode: "Night", token: .sjOnPhoto, hex: 0xF1E6D3)
    ]

    @Test("every kitchen colour comes from the cookbook tokens and equals web's hex", arguments: colours)
    func everyKitchenColourComesFromCookbookTokens(_ colour: Colour) throws {
        let value = try #require(OuroTokens.cookbook.extras.color(colour.token, colour.scheme), "\(colour)")
        let resolved = value.resolve(in: EnvironmentValues())
        #expect(Self.hex(resolved) == colour.hex, "\(colour)")
        #expect(resolved.opacity == 1, "\(colour)")
    }

    @Test("the theme declares exactly these colours, each from a cookbook token")
    func themeDeclaresExactlyTheseColours() throws {
        let theme = try Self.themeSource()
        let pattern = try NSRegularExpression(pattern: #"static let (\w+) = cookbook(Day|Night)\(\.(\w+)\)"#)
        let found = pattern.matches(in: theme, range: NSRange(theme.startIndex..., in: theme)).map { match in
            let group = { (index: Int) in String(theme[Range(match.range(at: index), in: theme)!]) }
            return "\(group(2)).\(group(1)) = cookbook\(group(2))(.\(group(3)))"
        }
        #expect(found == Self.colours.map { "\($0.mode).\($0.name) = cookbook\($0.mode)(.\($0.token))" })
        #expect(!theme.contains("webColor"))
    }

    @Test("radii, margins and the lift shadow are web's")
    func lengthsAndShadowAreWebs() throws {
        let extras = OuroTokens.cookbook.extras
        #expect(extras.lengths[.sjRadiusSmall] == 4)
        #expect(extras.lengths[.sjRadiusPhoto] == 8)
        #expect(extras.lengths[.sjRadiusSurface] == 8)
        #expect(extras.lengths[.sjSpaceUnit] == 4)
        #expect(extras.lengths[.sjMarginCompact] == 24)
        #expect(extras.lengths[.sjMarginRegular] == 32)
        #expect(extras.lengths[.sjMarginFold] == 40)
        // Web's `--sj-shadow-soft`: 0 12px 36px at 8% charcoal by day, 0 16px 44px at 42% photo charcoal at night.
        // SwiftUI's shadow radius is half the CSS blur.
        let soft = try #require(extras.shadows[.sjShadowSoft])
        #expect(soft.light.radius == 18 && soft.light.y == 12)
        #expect(soft.dark.radius == 22 && soft.dark.y == 16)
        let theme = try Self.themeSource()
        for usage in ["cookbookLength(.sjRadiusSmall)", "cookbookLength(.sjRadiusPhoto)", "cookbookLength(.sjRadiusSurface)",
                      "cookbookLength(.sjMarginFold)", "cookbookShadow(.sjShadowSoft)"] {
            #expect(theme.contains(usage), "\(usage)")
        }
    }

    @Test("Spoonjoy's night page is not OuroHX's cookbook dark background")
    func nightPageDiffersFromOuroHX() throws {
        // Upstream question: https://github.com/ourostack/ouro-ui-apple/issues/15
        #expect(Self.hex(OuroTokens.cookbook.dark.background.resolve(in: EnvironmentValues())) == 0x1F1D1A)
        let page = try #require(OuroTokens.cookbook.extras.color(.sjPage, .dark))
        #expect(Self.hex(page.resolve(in: EnvironmentValues())) == 0x1E1C19)
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
