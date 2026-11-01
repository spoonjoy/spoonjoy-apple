import Foundation
import Testing

/// Pins what App Review checks in the binary and its screens, so a refactor cannot quietly drop it.
@Suite("App Review readiness contract")
struct AppReviewReadinessContractTests {
    private static let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoURL.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("the app declares it uses only exempt encryption, so uploads skip the export-compliance question")
    func exportComplianceKey() throws {
        let data = try Data(contentsOf: Self.repoURL.appendingPathComponent("Apps/Spoonjoy/Shared/Info.plist"))
        let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }

    @Test("other chefs' recipes and kitchens offer Report and Block, and Settings lists blocked chefs (guideline 1.2)")
    func reportAndBlock() throws {
        #expect(try Self.source("Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift").contains("ModerationMenuItems("))
        #expect(try Self.source("Apps/Spoonjoy/Shared/Views/ProfileView.swift").contains("ModerationMenuItems("))
        #expect(try Self.source("Apps/Spoonjoy/Shared/Views/SearchView.swift").contains("hidesSearchResult"))
        #expect(try Self.source("Apps/Spoonjoy/Shared/Views/SettingsView.swift").contains("BlockedChefsView()"))
        #expect(try Self.source("Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift").contains(".environment(\\.moderation, moderation)"))
    }

    @Test("Settings links the privacy policy, terms, support and contact (guideline 5.1.1(i))")
    func policyLinks() throws {
        let settings = try Self.source("Apps/Spoonjoy/Shared/Views/SettingsView.swift")
        for url in ["https://spoonjoy.app/privacy", "https://spoonjoy.app/terms", "https://spoonjoy.app/support", "mailto:ari@spoonjoy.app"] {
            #expect(settings.contains(url), Comment(rawValue: "Settings must link \(url)"))
        }
    }

    // Review round 1: the 1.1 restyle dropped the row, so a chef could no longer link Google from the app.
    @Test("Settings offers Provider Links, which plans the in-app Google link handoff")
    func providerLinks() throws {
        let settings = try Self.source("Apps/Spoonjoy/Shared/Views/SettingsView.swift")
        #expect(settings.contains("ForEach(surface.securityRows.filter { $0.id == .providerLinks }, id: \\.id) { row in"))
        #expect(settings.contains("planSettingsAction(row.action, using: surface.actionPlanner)"))
        #expect(settings.contains("settings.providerLinks"))
    }

    // Review round 1: signed-out Settings stacked an "Account" bar title over the page's "Settings" header.
    @Test("standalone Settings shows one title, the page header, like signed-in Settings")
    func standaloneSettingsSingleTitle() throws {
        let root = try Self.source("Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift")
        #expect(!root.contains(".navigationTitle(\"Account\")"))
        #expect(root.contains("#if os(macOS)\n            .navigationTitle(\"Settings\")\n#else\n            .navigationBarTitleDisplayMode(.inline)\n#endif"))
        #expect(try Self.source("Apps/Spoonjoy/Shared/Views/SettingsView.swift").contains("KitchenTableHeader(title: \"Settings\", subtitle: nil)"))
    }

    @Test("every path that sends content to an AI service asks for consent first (guideline 5.1.2(i))")
    func aiConsentGates() throws {
        #expect(try Self.source("Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift").contains("ThirdPartyAIConsentGate.request(use)"))
        #expect(try Self.source("Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift").contains("ThirdPartyAIConsentGate.request(.recipeImport)"))
        let intents = try Self.source("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
        #expect(intents.contains("requireConsent(for: .recipeImport)"))
        #expect(intents.contains("requireConsent(for: .coverFromPhoto)"))
        #expect(try Self.source("Apps/Spoonjoy/Shared/Views/SettingsView.swift").contains("settings.aiConsent"))
    }
}
