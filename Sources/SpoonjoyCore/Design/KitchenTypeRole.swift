import OuroHX
import SwiftUI

/// The app's text roles in web's typefaces: Fraunces for titles, Source Serif 4 for reading and IBM Plex Sans
/// Condensed for labels, at the weights ouro-ui-core's cookbook tokens give them. Each role keeps the Dynamic Type
/// style and default size of the system role it replaces, so a layout keeps its room up to the largest accessibility
/// size. System chrome and the timer's digits stay San Francisco, so the timer is not a role here.
public enum KitchenTypeRole: String, CaseIterable, Sendable {
    case largeTitle, recipeTitle, displayTitle, sectionTitle, indexTitle, stepTitle, stepNumeral
    case cookStep, cookInstruction, spreadInstruction
    case story, instructionBody, bodyNote
    case control, objectTitle, uiLabel, meta, runningHead, eyebrow

    /// The role as a cookbook type token, at its text style's default size. Line height is the font's own.
    public var token: OuroTypeToken {
        let (family, weight, style) = spec
        let size = Self.defaultSize(of: style)
        return OuroTypeToken(family: family, weight: weight, size: size, textStyle: style, tracking: trackingEm * size, lineHeight: 0)
    }

    /// The role's font: its face, scaled with Dynamic Type, or the system serif or sans when the face isn't registered.
    public var font: Font { .ouro(token, in: OuroTokens.cookbook.extras) }

    /// The role's face and weight at another text style's size, scaling with that style: a compact bar's title or an
    /// avatar's initial that keeps the size its layout was built for.
    public func font(relativeTo style: Font.TextStyle) -> Font {
        let token = token
        let size = Self.defaultSize(of: style)
        return .ouro(
            OuroTypeToken(family: token.family, weight: token.weight, size: size, textStyle: style,
                          tracking: trackingEm * size, lineHeight: 0),
            in: OuroTokens.cookbook.extras)
    }

    /// The role's face and weight at a fixed size that doesn't follow Dynamic Type, for a letter drawn as decoration
    /// at a size its view already scales. Without the face, the system serif or sans.
    public func fixedFont(size: Double, registered: (String) -> Bool = OuroFont.isRegistered) -> Font {
        let token = token
        let weight = OuroFont.weight(token.weight)
        if case .custom(let family) = OuroFont.resolve(token, in: OuroTokens.cookbook.extras, registered: registered),
           let face = OuroFont.face(family: family, weight: token.weight) {
            let font = Font.custom(face.postScriptName, fixedSize: size)
            return face.isVariable ? font.weight(weight) : font
        }
        return .system(size: size, weight: weight, design: token.family == .sjUi ? .default : .serif)
    }

    /// Letter spacing in em: web's eyebrow tracking for eyebrows, none for every other role.
    public var trackingEm: Double {
        self == .eyebrow ? Self.eyebrowTracking(in: OuroTokens.cookbook.extras) : 0
    }

    /// A theme's eyebrow tracking in em, or none when the theme doesn't define one.
    static func eyebrowTracking(in extras: OuroThemeExtras) -> Double {
        extras.numbers[.sjTrackingEyebrow] ?? 0
    }

    /// Whether the role sets its text in capitals, as web's eyebrows do.
    public var isUppercase: Bool { self == .eyebrow }

    private var spec: (OuroExtraFont, Int, Font.TextStyle) {
        switch self {
        case .largeTitle, .displayTitle: (.sjDisplay, 600, .largeTitle)
        case .recipeTitle, .stepNumeral: (.sjDisplay, 600, .title)
        case .sectionTitle: (.sjDisplay, 600, .title2)
        // Web sets step titles upright, so the old italic subhead goes.
        case .indexTitle, .stepTitle: (.sjDisplay, 600, .title3)
        // The cook step is read from arm's length, so it starts at the large-title size and scales from there.
        case .cookStep: (.sjDisplay, 400, .largeTitle)
        case .cookInstruction: (.sjDisplay, 400, .title)
        case .spreadInstruction: (.sjDisplay, 400, .title3)
        case .story, .instructionBody, .bodyNote: (.sjBody, 400, .body)
        case .control: (.sjUi, 600, .body)
        case .objectTitle: (.sjUi, 600, .headline)
        case .uiLabel: (.sjUi, 600, .caption)
        case .meta: (.sjUi, 600, .footnote)
        case .runningHead: (.sjUi, 700, .caption2)
        case .eyebrow: (.sjUi, 700, .caption)
        }
    }

    /// The faces the roles use, as family name to CSS weights: what the app must bundle.
    public static var requiredFaces: [String: [Int]] { requiredFaces(in: OuroTokens.cookbook.extras) }

    /// The faces the roles use in a theme; a role whose font token the theme doesn't name needs no face.
    static func requiredFaces(in extras: OuroThemeExtras) -> [String: [Int]] {
        var faces: [String: Set<Int>] = [:]
        for role in allCases {
            guard let family = extras.fonts[role.token.family]?.first else { continue }
            faces[family, default: []].insert(role.token.weight)
        }
        return faces.mapValues { $0.sorted() }
    }

    /// A text style's size at the default Dynamic Type setting, as the system font sets it on this platform.
    public static func defaultSize(of style: Font.TextStyle) -> Double {
        defaultSize(of: style, in: defaultSizes)
    }

    /// A style's size in a table, or the body size of a 17 pt system when the table has no entry for it.
    static func defaultSize(of style: Font.TextStyle, in sizes: [Font.TextStyle: Double]) -> Double {
        sizes[style] ?? 17
    }

    #if os(macOS)
    private static let defaultSizes: [Font.TextStyle: Double] = [
        .largeTitle: 26, .title: 22, .title2: 17, .title3: 15, .headline: 13, .body: 13, .callout: 12,
        .subheadline: 11, .footnote: 10, .caption: 10, .caption2: 10,
    ]
    #else
    private static let defaultSizes: [Font.TextStyle: Double] = [
        .largeTitle: 34, .title: 28, .title2: 22, .title3: 20, .headline: 17, .body: 17, .callout: 16,
        .subheadline: 15, .footnote: 13, .caption: 12, .caption2: 11,
    ]
    #endif
}
