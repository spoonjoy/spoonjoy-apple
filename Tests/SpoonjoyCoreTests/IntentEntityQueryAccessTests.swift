import Foundation
import Security
import Testing
@testable import SpoonjoyCore

@Suite("Signed out, Siri and Spotlight find nothing instead of an error")
struct IntentEntityQueryAccessTests {
    private struct Unrelated: Error, Equatable {}

    @Test("signed in, the query's own results come back unchanged")
    func signedInResultsPassThrough() async throws {
        let results = try await IntentEntityQueryAccess.results { ["pancakes", "waffles"] }
        #expect(results == ["pancakes", "waffles"])
    }

    @Test("signed out, a query that needs the account returns no results")
    func signedOutIsEmpty() async throws {
        let results: [String] = try await IntentEntityQueryAccess.results { throw NativeIntentActionError.authRequired }
        #expect(results.isEmpty)
    }

    @Test("when the keychain can't hand over a session (locked device, unsigned build), the query returns no results")
    func unreadableKeychainIsEmpty() async throws {
        let results: [String] = try await IntentEntityQueryAccess.results {
            throw KeychainTokenVaultError.unhandledStatus(errSecMissingEntitlement)
        }
        #expect(results.isEmpty)
    }

    @Test("any other failure still reaches the system, so a broken cache is not mistaken for an empty kitchen")
    func otherErrorsStillThrow() async {
        await #expect(throws: Unrelated.self) {
            let _: [String] = try await IntentEntityQueryAccess.results { throw Unrelated() }
        }
        await #expect(throws: NativeIntentActionError.unresolvedRecipeEntity) {
            let _: [String] = try await IntentEntityQueryAccess.results { throw NativeIntentActionError.unresolvedRecipeEntity }
        }
    }

    @Test("signed out is told apart from other errors")
    func classification() {
        #expect(IntentEntityQueryAccess.meansSignedOut(NativeIntentActionError.authRequired))
        #expect(IntentEntityQueryAccess.meansSignedOut(KeychainTokenVaultError.unhandledStatus(errSecInteractionNotAllowed)))
        #expect(!IntentEntityQueryAccess.meansSignedOut(NativeIntentActionError.emptyCookbookTitle))
        #expect(!IntentEntityQueryAccess.meansSignedOut(Unrelated()))
    }
}
