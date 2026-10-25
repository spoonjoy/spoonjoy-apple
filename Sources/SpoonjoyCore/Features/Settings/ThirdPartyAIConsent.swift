import Foundation

/// Whether the person agreed to send their content to the AI services Spoonjoy uses. App Review guideline
/// 5.1.2(i) asks for clear consent before personal data goes to a third-party AI, naming who receives it.
public enum ThirdPartyAIConsent: String, Sendable {
    case undecided
    case granted
    case declined
}

/// What a feature sends to which AI service, as spoonjoy.app/privacy lists them.
public enum ThirdPartyAIUse: Equatable, Sendable {
    /// Importing a recipe from a link or captured text.
    case recipeImport
    /// Turning a photo of a cook into an editorial recipe cover.
    case coverFromPhoto
    /// Generating or regenerating a cover from the recipe's details.
    case coverFromRecipe

    public var title: String {
        switch self {
        case .recipeImport: "Import with AI"
        case .coverFromPhoto: "Restyle your photo with AI"
        case .coverFromRecipe: "Generate a cover with AI"
        }
    }

    public var disclosure: String {
        switch self {
        case .recipeImport:
            "Spoonjoy sends the text of the recipe you import to OpenAI, or to Google Gemini when OpenAI is unavailable, to read its ingredients and steps."
        case .coverFromPhoto:
            "Spoonjoy sends your photo and the recipe's title to Google Gemini, which restyles it into a cover."
        case .coverFromRecipe:
            "Spoonjoy sends the recipe's title, ingredients and your direction to OpenAI, or to Google Gemini when OpenAI is unavailable, to draw a cover."
        }
    }

    public static let sharedTerms = "They receive only what the request needs, never your email address or password. You can turn this off in Settings at any time."

    /// The Settings toggle's explanation.
    public static let settingsSummary = "Recipe import sends text to OpenAI, with Google Gemini as a backup. AI covers send your photo or recipe to Google Gemini or OpenAI. When this is off, Spoonjoy asks before sending anything."
}

public extension RecipeCoverControlsAction {
    /// The AI service this action calls, or nil when it stays on Spoonjoy's servers.
    var thirdPartyAIUse: ThirdPartyAIUse? {
        switch self {
        case .uploadPhoto(_, _, let generateEditorial, _, _, _, _, _), .createFromSpoon(_, _, let generateEditorial, _):
            generateEditorial ? .coverFromPhoto : nil
        case .generatePlaceholder, .regenerate:
            .coverFromRecipe
        case .setNoCover, .activate, .archive:
            nil
        }
    }
}

/// Keeps the answer in the app's defaults. App Intents run in the app's process, so Shortcuts and Siri read the same answer.
public struct ThirdPartyAIConsentStore: @unchecked Sendable {
    public static let key = "SpoonjoyThirdPartyAIConsent"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var consent: ThirdPartyAIConsent {
        defaults.string(forKey: Self.key).flatMap(ThirdPartyAIConsent.init(rawValue:)) ?? .undecided
    }

    public func record(_ consent: ThirdPartyAIConsent) {
        defaults.set(consent.rawValue, forKey: Self.key)
    }

    /// Shortcuts and Siri cannot show the consent sheet, so they stop with an explanation until the person allows
    /// AI features in the app.
    public func requireConsent(for use: ThirdPartyAIUse) throws {
        guard consent == .granted else {
            throw NativeIntentActionError.settingsActionUnavailable("\(use.disclosure) Open Spoonjoy and allow AI features first.")
        }
    }
}
