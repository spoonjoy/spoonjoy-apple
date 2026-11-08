import OuroHX
import SwiftUI

/// The app's text roles, each one of ouro-ui-core's cookbook type tokens (`sj-type-*`): Fraunces for titles and the
/// cook-step instruction, Source Serif 4 for reading and IBM Plex Sans Condensed for labels, at the token's weight
/// and size, scaled with Dynamic Type relative to the token's text style. System chrome and the timer's digits stay
/// San Francisco, so the timer is not a role here.
public enum KitchenTypeRole: String, CaseIterable, Sendable {
    case largeTitle, recipeTitle, displayTitle, sectionTitle, indexTitle, stepTitle, stepNumeral
    case cookStep, cookInstruction, spreadInstruction
    case story, instructionBody, bodyNote
    case control, objectTitle, uiLabel, meta, runningHead, eyebrow

    /// The cookbook type token the role sets.
    public var type: OuroExtraType {
        switch self {
        // The cook step is read from arm's length, so its instruction is display-size Fraunces, as web sets it.
        case .largeTitle, .displayTitle, .cookStep: .sjTypeDisplay
        case .recipeTitle, .stepNumeral: .sjTypeTitle
        case .sectionTitle, .indexTitle: .sjTypeSection
        case .stepTitle: .sjTypeStep
        case .cookInstruction, .spreadInstruction: .sjTypeInstruction
        case .story, .instructionBody, .bodyNote: .sjTypeBody
        case .control, .objectTitle: .sjTypeUi
        case .uiLabel, .meta: .sjTypeMeta
        case .runningHead, .eyebrow: .sjTypeEyebrow
        }
    }

    /// The role's token in the cookbook theme.
    public var token: OuroTypeToken { token(in: OuroTokens.cookbook.extras) }

    /// The role's token in a theme, or a plain body token when the theme doesn't define it.
    func token(in extras: OuroThemeExtras) -> OuroTypeToken {
        extras.type[type] ?? OuroTypeToken(family: .sjBody, weight: 400, size: 17, textStyle: .body, tracking: 0, lineHeight: 1)
    }

    /// The role's font: its face at the token's size, scaled with Dynamic Type relative to the token's text style, or
    /// the system serif or sans when the face isn't registered.
    public var font: Font { .ouro(token, in: OuroTokens.cookbook.extras) }

    /// The role's face and weight scaled relative to another text style, keeping the token's proportion to its own
    /// style: a compact bar's title or an avatar's initial that keeps the room its layout was built for.
    public func font(relativeTo style: Font.TextStyle) -> Font {
        let token = token
        let scale = Self.defaultSize(of: style) / Self.defaultSize(of: token.textStyle)
        return .ouro(
            OuroTypeToken(family: token.family, weight: token.weight, size: token.size * scale, textStyle: style,
                          tracking: token.tracking * scale, lineHeight: token.lineHeight),
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

    /// The faces the roles use, as family name to CSS weights: what the app must bundle.
    public static var requiredFaces: [String: [Int]] { requiredFaces(in: OuroTokens.cookbook.extras) }

    /// The faces the roles use in a theme; a role whose font token the theme doesn't name needs no face.
    static func requiredFaces(in extras: OuroThemeExtras) -> [String: [Int]] {
        var faces: [String: Set<Int>] = [:]
        for role in allCases {
            let token = role.token(in: extras)
            guard let family = extras.fonts[token.family]?.first else { continue }
            faces[family, default: []].insert(token.weight)
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
