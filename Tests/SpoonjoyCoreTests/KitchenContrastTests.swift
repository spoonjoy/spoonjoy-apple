import Foundation
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

    private func themeTokens() throws -> [String: UInt32] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let theme = try String(contentsOf: root.appendingPathComponent("Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"), encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: #"static let (\w+) = webColor\(0x([0-9A-Fa-f]{6})\)"#)
        var tokens: [String: UInt32] = [:]
        for match in pattern.matches(in: theme, range: NSRange(theme.startIndex..., in: theme)) {
            let name = String(theme[Range(match.range(at: 1), in: theme)!])
            tokens[name] = UInt32(theme[Range(match.range(at: 2), in: theme)!], radix: 16)
        }
        return tokens
    }
}
