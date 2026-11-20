import Foundation
import OuroHX
import SwiftUI
import Testing
@testable import SpoonjoyCore

@Suite("Kitchen contrast")
struct KitchenContrastTests {
    @Test("ink on the page meets AAA in both appearances")
    func inkOnPageMeetsAAInBothAppearances() {
        #expect(KitchenContrast.ratio(foreground: 0x28231D, background: 0xFBFAF4) >= 7)
        #expect(KitchenContrast.ratio(foreground: 0xF2EEE6, background: 0x1E1C19) >= 7)
    }

    @Test("brass text meets AA on both pages")
    func brassTextMeetsAAOnBothPages() {
        #expect(KitchenContrast.ratio(foreground: 0x9B6834, background: 0xFBFAF4) >= 4.5)
        #expect(KitchenContrast.ratio(foreground: 0xC4945C, background: 0x1E1C19) >= 4.5)
    }

    @Test("black on white is the 21:1 maximum, and order doesn't matter")
    func extremesAndSymmetry() {
        #expect(abs(KitchenContrast.ratio(foreground: 0x000000, background: 0xFFFFFF) - 21) < 0.01)
        #expect(KitchenContrast.ratio(foreground: 0xFFFFFF, background: 0x000000) == KitchenContrast.ratio(foreground: 0x000000, background: 0xFFFFFF))
        #expect(KitchenContrast.ratio(foreground: 0x777777, background: 0x777777) == 1)
    }

    /// Every text role on every surface it sits on, in both appearances, read from the theme's own day and night
    /// tokens so the check moves with the palette. Body text needs 4.5:1 (WCAG AA).
    @Test("every text role meets AA on the page and raised surfaces in both appearances")
    func everyRolePairMeetsAAInBothAppearances() throws {
        let tokens = try themeTokens()
        let surfaces = [("bone", "pageNight"), ("paper", "paperNight")]
        let texts = [("charcoal", "boneNight"), ("inkMuted", "inkMutedNight"), ("brass", "brassNight"), ("tomato", "tomatoNight"), ("herb", "herbNight")]
        for (dayText, nightText) in texts {
            for (daySurface, nightSurface) in surfaces {
                let day = KitchenContrast.ratio(foreground: try #require(tokens[dayText]), background: try #require(tokens[daySurface]))
                let night = KitchenContrast.ratio(foreground: try #require(tokens[nightText]), background: try #require(tokens[nightSurface]))
                #expect(day >= 4.5, "\(dayText) on \(daySurface) is \(day):1 by day")
                #expect(night >= 4.5, "\(nightText) on \(nightSurface) is \(night):1 at night")
            }
        }
        // Labels on the one filled action: bone on charcoal by day, the night charcoal on the amber action at night.
        let fills = [("action", "actionNight"), ("brass", "brassNight"), ("tomato", "tomatoNight")]
        for (dayFill, nightFill) in fills {
            #expect(KitchenContrast.ratio(foreground: try #require(tokens["bone"]), background: try #require(tokens[dayFill])) >= 4.5)
            #expect(KitchenContrast.ratio(foreground: try #require(tokens["charcoalNight"]), background: try #require(tokens[nightFill])) >= 4.5)
        }
    }

    /// Vellum is a panel and chip surface. Ink, secondary ink, herb and tomato sit on it as text; brass only marks
    /// icons on it (the no-photo badge), so brass is held to the 3:1 non-text bar there.
    @Test("text on vellum meets AA, and brass icons on vellum meet the 3:1 non-text bar, in both appearances")
    func vellumPairsMeetTheirBars() throws {
        let tokens = try themeTokens()
        let texts = [("charcoal", "boneNight"), ("inkMuted", "inkMutedNight"), ("tomato", "tomatoNight"), ("herb", "herbNight")]
        for (dayText, nightText) in texts {
            let day = KitchenContrast.ratio(foreground: try #require(tokens[dayText]), background: try #require(tokens["vellum"]))
            let night = KitchenContrast.ratio(foreground: try #require(tokens[nightText]), background: try #require(tokens["vellumNight"]))
            #expect(day >= 4.5, "\(dayText) on vellum is \(day):1 by day")
            #expect(night >= 4.5, "\(nightText) on vellum is \(night):1 at night")
        }
        #expect(KitchenContrast.ratio(foreground: try #require(tokens["brass"]), background: try #require(tokens["vellum"])) >= 3)
        #expect(KitchenContrast.ratio(foreground: try #require(tokens["brassNight"]), background: try #require(tokens["vellumNight"])) >= 3)
    }

    @Test("text on photographs meets AA on the photo charcoal in both appearances")
    func onPhotoMeetsAAOnPhotoCharcoal() throws {
        let tokens = try themeTokens()
        #expect(KitchenContrast.ratio(foreground: try #require(tokens["bone"]), background: try #require(tokens["photoCharcoal"])) >= 4.5)
        #expect(KitchenContrast.ratio(foreground: try #require(tokens["onPhotoNight"]), background: try #require(tokens["photoCharcoalNight"])) >= 4.5)
    }

    /// A recipe cover without a photo sets its letter in brass mixed 40% toward the text colour, as web's Ouro UI Cover
    /// does (`color-mix(in oklab, var(--primary) 60%, var(--foreground))`, spoonjoy-v2#806). The letter is small on a
    /// row's thumbnail, so it needs 4.5:1 on both ends of the wash: vellum, and brass at 32% over the page or panel.
    @Test("the cover letter matches web's OKLab mix and meets AA across the cover's wash in both appearances")
    func coverLetterMatchesWebAndMeetsAAOnTheWash() throws {
        let tokens = try themeTokens()
        let modes: [(scheme: ColorScheme, text: OuroExtraColor, vellum: String, surfaces: [String], web: UInt32)] = [
            (.light, .sjCharcoal, "vellum", ["bone", "paper"], 0x6A4B2C),
            (.dark, .sjBone, "vellumNight", ["pageNight", "paperNight"], 0xD7B894)
        ]
        for mode in modes {
            let brass = try #require(OuroTokens.cookbook.extras.color(.sjBrass, mode.scheme))
            let text = try #require(OuroTokens.cookbook.extras.color(mode.text, mode.scheme))
            let ink = KitchenPaletteOuroTests.hex(brass.mix(with: text, by: 0.4, in: .perceptual).resolve(in: EnvironmentValues()))
            let brassHex = KitchenPaletteOuroTests.hex(brass.resolve(in: EnvironmentValues()))
            // Within 2 of 255 per channel of web's value: the two sides round OKLab differently.
            #expect([16, 8, 0].allSatisfy { abs(Int(ink >> $0 & 0xFF) - Int(mode.web >> $0 & 0xFF)) <= 2 },
                    "\(mode.scheme) cover ink #\(String(format: "%06X", ink)), web #\(String(format: "%06X", mode.web))")
            let onVellum = KitchenContrast.ratio(foreground: ink, background: try #require(tokens[mode.vellum]))
            #expect(onVellum >= 4.5, "\(mode.scheme) cover ink on vellum is \(onVellum):1")
            for surface in mode.surfaces {
                let washEnd = Self.composite(brassHex, opacity: 0.32, over: try #require(tokens[surface]))
                let onBrass = KitchenContrast.ratio(foreground: ink, background: washEnd)
                #expect(onBrass >= 4.5, "\(mode.scheme) cover ink on the brass end over \(surface) is \(onBrass):1")
            }
        }
        let theme = try KitchenPaletteOuroTests.themeSource()
        #expect(theme.contains("static let coverInk = dynamic(coverInkMix(Day.brass, Day.charcoal), coverInkMix(Night.brassNight, Night.boneNight))"))
        #expect(theme.contains("brass.mix(with: text, by: 0.4, in: .perceptual)"))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let tile = try String(contentsOf: root.appendingPathComponent("Apps/Spoonjoy/Shared/Components/RecipeIndexRow.swift"), encoding: .utf8)
        #expect(tile.contains(".foregroundStyle(KitchenTableTheme.coverInk)"))
    }

    /// `color` at `opacity` over `background`, as sRGB bytes blend on screen.
    private static func composite(_ color: UInt32, opacity: Double, over background: UInt32) -> UInt32 {
        [16, 8, 0].reduce(UInt32(0)) { result, shift in
            let top = Double(color >> UInt32(shift) & 0xFF)
            let bottom = Double(background >> UInt32(shift) & 0xFF)
            return result | UInt32((top * opacity + bottom * (1 - opacity)).rounded()) << UInt32(shift)
        }
    }

    /// The theme's colours as the app resolves them: each name's cookbook token, read live from OuroHX.
    private func themeTokens() throws -> [String: UInt32] {
        var tokens: [String: UInt32] = [:]
        for colour in KitchenPaletteOuroTests.colours {
            let value = try #require(OuroTokens.cookbook.extras.color(colour.token, colour.scheme), "\(colour)")
            tokens[colour.name] = KitchenPaletteOuroTests.hex(value.resolve(in: EnvironmentValues()))
        }
        return tokens
    }
}
