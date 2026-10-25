import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Third-party AI consent")
struct ThirdPartyAIConsentTests {
    private static func photo() -> NativeStagedMediaUpload {
        NativeStagedMediaUpload(localStageID: "upload_1", fileName: "cook.jpg", contentType: "image/jpeg", data: Data([1, 2, 3]))
    }

    @Test("only actions that call an AI service ask for consent, and each names what it sends")
    func coverActionsNameTheirAIUse() {
        #expect(RecipeCoverControlsAction.uploadPhoto(photo: Self.photo(), activateWhenReady: true, generateEditorial: true, postAsSpoon: false, note: nil, nextTime: nil, cookedAt: nil, clientMutationID: "c1").thirdPartyAIUse == .coverFromPhoto)
        #expect(RecipeCoverControlsAction.uploadPhoto(photo: Self.photo(), activateWhenReady: true, generateEditorial: false, postAsSpoon: false, note: nil, nextTime: nil, cookedAt: nil, clientMutationID: "c1").thirdPartyAIUse == nil)
        #expect(RecipeCoverControlsAction.createFromSpoon(spoonID: "s1", activate: true, generateEditorial: true, clientMutationID: "c2").thirdPartyAIUse == .coverFromPhoto)
        #expect(RecipeCoverControlsAction.createFromSpoon(spoonID: "s1", activate: true, generateEditorial: false, clientMutationID: "c2").thirdPartyAIUse == nil)
        #expect(RecipeCoverControlsAction.generatePlaceholder(promptAddition: nil, activateWhenReady: true, clientMutationID: "c3").thirdPartyAIUse == .coverFromRecipe)
        #expect(RecipeCoverControlsAction.regenerate(coverID: "cv1", activateWhenReady: false, clientMutationID: "c4").thirdPartyAIUse == .coverFromRecipe)
        #expect(RecipeCoverControlsAction.setNoCover(clientMutationID: "c5").thirdPartyAIUse == nil)
        #expect(RecipeCoverControlsAction.activate(coverID: "cv1", variant: .stylized, clientMutationID: "c6").thirdPartyAIUse == nil)
        #expect(RecipeCoverControlsAction.archive(coverID: "cv1", replacementCoverID: nil, replacementVariant: nil, confirmNoCover: true, deleteSafeObjects: false, clientMutationID: "c7").thirdPartyAIUse == nil)
    }

    @Test("every use names its provider")
    func disclosuresNameProviders() {
        #expect(ThirdPartyAIUse.recipeImport.title == "Import with AI")
        #expect(ThirdPartyAIUse.coverFromPhoto.title == "Restyle your photo with AI")
        #expect(ThirdPartyAIUse.coverFromRecipe.title == "Generate a cover with AI")
        #expect(ThirdPartyAIUse.recipeImport.disclosure.contains("OpenAI"))
        #expect(ThirdPartyAIUse.coverFromPhoto.disclosure.contains("Google Gemini"))
        #expect(ThirdPartyAIUse.coverFromRecipe.disclosure.contains("OpenAI"))
        #expect(ThirdPartyAIUse.sharedTerms.contains("Settings"))
        #expect(ThirdPartyAIUse.settingsSummary.contains("OpenAI"))
        #expect(ThirdPartyAIUse.settingsSummary.contains("Google Gemini"))
    }

    @Test("the answer starts undecided, is remembered, and can be revoked")
    func storeRemembersTheAnswer() throws {
        let suite = "spoonjoy-ai-consent-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ThirdPartyAIConsentStore(defaults: defaults)

        #expect(store.consent == .undecided)
        store.record(.granted)
        #expect(ThirdPartyAIConsentStore(defaults: defaults).consent == .granted)
        store.record(.declined)
        #expect(store.consent == .declined)
        defaults.set("garbage", forKey: ThirdPartyAIConsentStore.key)
        #expect(store.consent == .undecided)
    }

    @Test("Shortcuts stop with the disclosure until AI features are allowed")
    func intentsRequireConsent() throws {
        let suite = "spoonjoy-ai-consent-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ThirdPartyAIConsentStore(defaults: defaults)

        #expect(throws: NativeIntentActionError.settingsActionUnavailable("\(ThirdPartyAIUse.recipeImport.disclosure) Open Spoonjoy and allow AI features first.")) {
            try store.requireConsent(for: .recipeImport)
        }
        store.record(.declined)
        #expect(throws: NativeIntentActionError.self) { try store.requireConsent(for: .coverFromPhoto) }
        store.record(.granted)
        try store.requireConsent(for: .coverFromPhoto)
    }
}
