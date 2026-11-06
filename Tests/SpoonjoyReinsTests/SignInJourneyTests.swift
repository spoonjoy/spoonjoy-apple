import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// SignInJourney, headless: a signed-in session survives a relaunch; Settings shows the environment, opens and cancels
/// the Delete account sheet and offers Download my data; signing out returns to the sign-in screen, and a relaunch
/// stays signed out. Signing in (a wrong password, by username, by email) and the server's revoke need QA, so they stay
/// in the live journey; here the session is the fixture vault's, shared by every launch as the keychain is.
@MainActor
@Suite("SignInJourney", .serialized)
struct SignInJourney {
    @Test("testSignInOutJourney")
    func testSignInOutJourney() async throws {
        let fixtures = SpoonjoyReinsFixtures.online(vault: try FixtureTokenVault.signedIn())
        try await headless {
            let app = try await HeadlessApp.launch(fixtures: fixtures)
            try await app.journey.expect("kitchen", describing: "the signed-in session opens the kitchen")

            // The session survives a relaunch.
            try await app.relaunch()
            try await app.journey.expect("kitchen", describing: "the session survived the relaunch")
            #expect(!app.screen.path.contains("signIn"))

            // Settings names the environment the build talks to.
            try await app.journey.do("openSettings", until: { $0.focus == "settings" && $0.state["account"]?["username"] == "kitchen" })
            #expect(app.screen.state["environment"] == .string(NativeCacheEnvironment.production.rawValue))

            // Delete account opens its confirmation sheet; Cancel leaves the account and the session alone.
            try await app.journey.do("deleteAccount", until: { $0.focus == "deleteAccount" && $0.state["username"] == "kitchen" })
            try await app.journey.do("cancel", until: { $0.focus == "settings" && $0.context["sheet"] == nil })
            #expect(app.shell.content.trustedAccountID == SpoonjoyFixtureKitchen.accountID)

            // Settings has a Download my data row.
            #expect(app.screen.state["rows"]?.arrayValue?.contains("Download my data") == true)
            #expect(app.screen.actionNames.contains("downloadData"))

            // Signing out asks first, then returns to the sign-in screen through the secure sign-out hand-off.
            try await app.journey.do("signOut", until: { $0.focus == "confirmSignOut" && $0.state["title"] == "Sign out?" })
            try await app.journey.do("confirm", until: { $0.focus == "settings" && $0.actionNames.contains("closeSettings") })
            #expect(app.shell.page.openedURLs.map(\.lastPathComponent) == ["logout"])
            try await app.journey.do("closeSettings", until: { $0.focus == "signIn" })
            #expect(app.shell.content.trustedAccountID == nil)

            // A relaunch is still signed out.
            try await app.relaunch()
            try await app.journey.expect("signIn", describing: "the app stayed signed out after the relaunch")
            #expect(!app.screen.path.contains("kitchen"))
        }
    }
}
