import AppKit
import CoreGraphics
import OuroHX
@testable import SpoonjoyCore
import SwiftUI
import Testing

/// Each native text role sets web's face: Fraunces for titles, Source Serif 4 for reading and IBM Plex Sans Condensed
/// for labels, at the weights web's cookbook tokens give them, in the size and Dynamic Type style of the system role
/// it replaces.
@Suite("Kitchen type roles", .serialized)
struct KitchenTypeRoleTests {
    static let extras = OuroTokens.cookbook.extras

    @Test("every role is its cookbook type token")
    func testTypeRolesUseCookbookFaces() throws {
        let expected: [KitchenTypeRole: OuroExtraType] = [
            .largeTitle: .sjTypeDisplay, .displayTitle: .sjTypeDisplay, .cookStep: .sjTypeDisplay,
            .recipeTitle: .sjTypeTitle, .stepNumeral: .sjTypeTitle,
            .sectionTitle: .sjTypeSection, .indexTitle: .sjTypeSection, .stepTitle: .sjTypeStep,
            .cookInstruction: .sjTypeInstruction, .spreadInstruction: .sjTypeInstruction,
            .story: .sjTypeBody, .instructionBody: .sjTypeBody, .bodyNote: .sjTypeBody,
            .control: .sjTypeUi, .objectTitle: .sjTypeUi, .uiLabel: .sjTypeMeta, .meta: .sjTypeMeta,
            .runningHead: .sjTypeEyebrow, .eyebrow: .sjTypeEyebrow,
        ]
        #expect(Set(expected.keys) == Set(KitchenTypeRole.allCases))
        for role in KitchenTypeRole.allCases {
            #expect(role.type == expected[role], "\(role)")
            // Weight, size, text style and tracking are the token's own, not copies.
            let token = try #require(Self.extras.type[role.type])
            #expect(role.token == token, "\(role)")
            #expect(role.font == .ouro(token, in: Self.extras), "\(role)")
        }
        // The values the ruling names: display is 48 pt relative to large title, step is title2, ui is subheadline.
        #expect(KitchenTypeRole.displayTitle.token.size == 48 && KitchenTypeRole.displayTitle.token.textStyle == .largeTitle)
        #expect(KitchenTypeRole.stepTitle.token.textStyle == .title2)
        #expect(KitchenTypeRole.control.token.textStyle == .subheadline)
        #expect(KitchenTypeRole.eyebrow.token.tracking == 0.18 * KitchenTypeRole.eyebrow.token.size)
    }

    @Test("default sizes match the system font's on this platform")
    func defaultSizesMatchTheSystem() {
        let styles: [Font.TextStyle: NSFont.TextStyle] = [
            .largeTitle: .largeTitle, .title: .title1, .title2: .title2, .title3: .title3, .headline: .headline,
            .body: .body, .callout: .callout, .subheadline: .subheadline, .footnote: .footnote, .caption: .caption1,
            .caption2: .caption2,
        ]
        for (style, nsStyle) in styles {
            #expect(KitchenTypeRole.defaultSize(of: style) == Double(NSFont.preferredFont(forTextStyle: nsStyle).pointSize), "\(style)")
        }
    }

    @Test("the real bundled fonts carry every weight the roles use")
    func bundledFacesCoverEveryRole() throws {
        #expect(KitchenFontFiles.register(KitchenFontFilesTests.bundledURLs).isEmpty)
        let required = KitchenTypeRole.requiredFaces
        #expect(required == ["Fraunces": [400, 600], "Source Serif 4": [400], "IBM Plex Sans Condensed": [600, 700]])
        for (family, weights) in required {
            #expect(OuroFont.isAvailable(family: family, weights: weights), "\(family) \(weights)")
        }
        // Plex ships static faces; every one the app bundles is a real weight, not a synthesised one.
        #expect(OuroFont.isAvailable(family: "IBM Plex Sans Condensed", weights: [400, 500, 600, 700]))
        for role in KitchenTypeRole.allCases {
            let family = try #require(Self.extras.fonts[role.token.family]?.first)
            #expect(OuroFont.resolve(role.token, in: Self.extras) == .custom(family), "\(role)")
            #expect(OuroFont.face(family: family, weight: role.token.weight)?.isExactWeight == true, "\(role)")
        }
    }

    @MainActor
    @Test("600 and 700 render bolder than 400 in the variable families")
    func variableWeightsRenderBolder() throws {
        #expect(KitchenFontFiles.register(KitchenFontFilesTests.bundledURLs).isEmpty)
        for family in [OuroExtraFont.sjDisplay, .sjBody] {
            let ink = try [400, 600, 700].map { weight in
                let token = OuroTypeToken(family: family, weight: weight, size: 40, textStyle: .body, tracking: 0, lineHeight: 1)
                return try Self.ink(Text("Hamburgefonstiv").font(.ouro(token, in: Self.extras)))
            }
            #expect(ink[0] < ink[1] && ink[1] < ink[2], "\(family): \(ink)")
            // A visibly heavier stroke, not rounding noise.
            #expect(Double(ink[2]) > Double(ink[0]) * 1.2, "\(family): \(ink)")
        }
    }

    @MainActor
    @Test("a role at another style or a fixed size keeps its face and weight")
    func rolesAtOtherSizes() throws {
        #expect(KitchenFontFiles.register(KitchenFontFilesTests.bundledURLs).isEmpty)
        let title = KitchenTypeRole.recipeTitle
        let token = title.token
        let scale = KitchenTypeRole.defaultSize(of: .subheadline) / KitchenTypeRole.defaultSize(of: token.textStyle)
        let small = OuroTypeToken(family: .sjDisplay, weight: 600, size: token.size * scale, textStyle: .subheadline,
                                  tracking: 0, lineHeight: token.lineHeight)
        #expect(title.font(relativeTo: .subheadline) == .ouro(small, in: Self.extras))

        // Fraunces is variable, so its face takes the weight; Plex's bold is its own static face.
        let fraunces = try #require(OuroFont.face(family: "Fraunces", weight: 600))
        #expect(title.fixedFont(size: 60) == Font.custom(fraunces.postScriptName, fixedSize: 60).weight(.semibold))
        let plexBold = try #require(OuroFont.face(family: "IBM Plex Sans Condensed", weight: 700))
        #expect(KitchenTypeRole.runningHead.fixedFont(size: 20) == Font.custom(plexBold.postScriptName, fixedSize: 20))
        #expect(try Self.ink(Text("Ab").font(title.fixedFont(size: 60))) > Self.ink(Text("Ab").font(.custom(fraunces.postScriptName, fixedSize: 60))))

        // Without the faces, the system serif or sans at the same size and weight.
        #expect(title.fixedFont(size: 60, registered: { _ in false }) == .system(size: 60, weight: .semibold, design: .serif))
        #expect(KitchenTypeRole.runningHead.fixedFont(size: 20, registered: { _ in false })
            == .system(size: 20, weight: .bold, design: .default))
    }

    @Test("a theme without the tokens falls back to a plain body token and needs no faces")
    func emptyThemeFallsBack() {
        #expect(KitchenTypeRole.displayTitle.token(in: .empty)
            == OuroTypeToken(family: .sjBody, weight: 400, size: 17, textStyle: .body, tracking: 0, lineHeight: 1))
        #expect(KitchenTypeRole.requiredFaces(in: .empty).isEmpty)
        #expect(KitchenTypeRole.defaultSize(of: .title, in: [:]) == 17)
    }

    @MainActor
    static func ink(_ text: Text) throws -> Int {
        let renderer = ImageRenderer(content: text.foregroundStyle(.black).fixedSize())
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: pixels.count, by: 4).reduce(0) { $0 + Int(pixels[$1]) } / 255
    }
}
