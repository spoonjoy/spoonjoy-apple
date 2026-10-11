import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Siri and Shortcuts writes finish in place")
struct NativeIntentOutcomeTests {
    private static let appIntentsPath = "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift"

    // MARK: Which intents open the app

    @Test("every App Intent is in the catalog, and only the catalog's open-the-app intents open the app")
    func catalogMatchesIntentSource() throws {
        let bodies = try Self.intentBodies()
        #expect(Set(bodies.keys) == Set(NativeIntentResultCatalog.modes.keys))

        for (name, body) in bodies {
            let opensApp = NativeIntentResultCatalog.intentsThatOpenTheApp.contains(name)
            #expect(body.contains("opensIntent") == opensApp, "\(name) opens the app: \(!opensApp)")
            #expect(body.contains("OpenURLIntent") == opensApp, "\(name) builds an OpenURLIntent: \(!opensApp)")
        }
    }

    @Test("the intents that open the app are exactly the ones where seeing the app is the point")
    func openTheAppListIsPinned() {
        #expect(NativeIntentResultCatalog.intentsThatOpenTheApp == [
            "OpenRecipeIntent",
            "OpenCookbookIntent",
            "OpenProfileIntent",
            "OpenSettingsIntent",
            "OpenNotificationAPNsStatusIntent",
            "OpenAPITokensIntent",
            "CreateAPITokenIntent",
            "OpenAccountConnectionsIntent",
            "OpenPasskeysIntent",
            "OpenPasswordIntent",
            "LinkProviderIntent",
            "SearchSpoonjoyIntent",
            "ShareRecipeIntent",
            "ShareCookbookIntent",
            "StartCookModeIntent",
            "ContinueCookModeIntent",
            "OpenCaptureDraftIntent"
        ])
        for (name, mode) in NativeIntentResultCatalog.modes {
            if case .opensApp(let reason) = mode {
                #expect(!reason.isEmpty, "\(name) needs a reason to open the app")
            }
        }
    }

    @Test("write intents queue through the shared store, sync in place, and answer failures with a dialog")
    func writeIntentsFinishInPlace() throws {
        let bodies = try Self.intentBodies()
        let queuedWrites = [
            "ForkRecipeIntent", "SaveRecipeToCookbookIntent", "CreateCookbookIntent", "RenameCookbookIntent",
            "DeleteCookbookIntent", "AddRecipeToCookbookIntent", "RemoveRecipeFromCookbookIntent", "DeleteRecipeIntent",
            "AddShoppingListItemIntent", "SetShoppingListItemCheckedIntent", "RemoveShoppingListItemIntent",
            "AddRecipeIngredientsToShoppingListIntent", "ClearCompletedShoppingItemsIntent", "ClearShoppingListIntent",
            "LogCookIntent", "EditCookLogIntent", "DeleteCookLogIntent", "CreateCoverFromSpoonIntent",
            "CaptureRecipeIntent", "SubmitCaptureImportIntent", "DiscardCaptureDraftIntent"
        ]
        let settingsWrites = [
            "UpdateNotificationPreferencesIntent", "UpdateProfileDisplayIntent", "UpdateProfilePhotoIntent",
            "RemoveProfilePhotoIntent", "RevokeAPITokenIntent", "DisconnectAccountConnectionIntent", "LogoutIntent",
            "RevokeCurrentSessionIntent"
        ]
        for name in queuedWrites {
            let body = try #require(bodies[name])
            #expect(NativeIntentResultCatalog.modes[name] == .finishesInPlace)
            #expect(body.contains("let queued = try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"), "\(name) queues through the shared store")
            #expect(body.contains("SpoonjoyIntentOutcome.finished(NativeIntentDialog."), "\(name) syncs and confirms in place")
            #expect(body.contains("queued: queued"), "\(name) syncs the edits it queued")
            #expect(body.contains("try SpoonjoyIntentOutcome.failed(error)"), "\(name) answers a failure with a dialog")
            #expect(body.contains("return .result(dialog:"), "\(name) returns a dialog")
        }
        for name in settingsWrites {
            let body = try #require(bodies[name])
            #expect(NativeIntentResultCatalog.modes[name] == .finishesInPlace)
            #expect(body.contains("try SpoonjoyIntentOutcome.failed(error)"), "\(name) answers a failure with a dialog")
            #expect(body.contains("return .result(dialog:"), "\(name) returns a dialog")
        }
    }

    @Test("the intent writer returns the edits it queued, and sends them with the app's sync engine")
    func intentWriterSyncsWithTheAppEngine() throws {
        let source = try Self.readRepoFile(Self.appIntentsPath)
        for token in [
            "func apply(_ action: NativeIntentAction, savedAt: String) async throws -> [String]",
            "NativeSyncEngine(",
            "store: syncStore",
            "URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(authenticationRefresher: refresher))",
            "NativeIntentWriteSync.drain(clientMutationIDs: clientMutationIDs)",
            "NativeSyncExecutionScope(expectedAccountID: scope.accountID, environment: scope.environment)",
            "NativeIntentDialog.failureMessage(for: error)"
        ] {
            #expect(source.contains(token), "missing \(token)")
        }
    }

    // MARK: Sending queued edits

    @Test("a sync report decides whether the queued edits were sent, refused, or are still waiting")
    func outcomeFromReport() {
        let sent = Self.report(drained: ["cm_eggs", "cm_milk"], conflicts: [])
        #expect(NativeIntentWriteSync.outcome(clientMutationIDs: ["cm_eggs"], report: sent) == .synced)
        #expect(NativeIntentWriteSync.outcome(clientMutationIDs: ["cm_eggs", "cm_milk"], report: sent) == .synced)
        #expect(NativeIntentWriteSync.outcome(clientMutationIDs: ["cm_eggs", "cm_bread"], report: sent) == .pending)
        #expect(NativeIntentWriteSync.outcome(clientMutationIDs: [], report: sent) == .pending)

        let refused = Self.report(drained: [], conflicts: [
            NativeSyncConflict(clientMutationID: "cm_other", kind: .validation, serverRevision: nil, message: "Other"),
            NativeSyncConflict(clientMutationID: "cm_eggs", kind: .validation, serverRevision: nil, message: "Name is too long.")
        ])
        #expect(NativeIntentWriteSync.outcome(clientMutationIDs: ["cm_eggs"], report: refused) == .rejected(message: "Name is too long."))
    }

    @Test("draining reports a finished sync")
    func drainReportsFinishedSync() async {
        let outcome = await NativeIntentWriteSync.drain(clientMutationIDs: ["cm_eggs"]) {
            Self.report(drained: ["cm_eggs"], conflicts: [])
        }
        #expect(outcome == .synced)
    }

    @Test("a failed sync leaves the edit queued")
    func drainFailureLeavesEditQueued() async {
        let outcome = await NativeIntentWriteSync.drain(
            clientMutationIDs: ["cm_eggs"],
            sleep: { _ in try await Task.sleep(for: .seconds(60)) }
        ) {
            throw APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        }
        #expect(outcome == .pending)
    }

    @Test("a slow sync stops waiting at the timeout and leaves the edit queued")
    func drainTimesOut() async {
        let outcome = await NativeIntentWriteSync.drain(
            clientMutationIDs: ["cm_eggs"],
            timeout: .milliseconds(1),
            sleep: { _ in }
        ) {
            try await Task.sleep(for: .seconds(60))
            return Self.report(drained: ["cm_eggs"], conflicts: [])
        }
        #expect(outcome == .pending)
    }

    @Test("with nothing queued there is nothing to send")
    func drainWithNothingQueued() async {
        let outcome = await NativeIntentWriteSync.drain(clientMutationIDs: []) {
            Issue.record("sync should not run without queued edits")
            return Self.report(drained: [], conflicts: [])
        }
        #expect(outcome == .pending)
        #expect(NativeIntentWriteSync.defaultTimeout == .seconds(5))
    }

    // MARK: What Siri says

    @Test("a confirmation says whether the edit is synced, still waiting, or refused")
    func confirmationDialog() {
        #expect(NativeIntentDialog.confirmation("Added eggs to your shopping list.", sync: .synced) == "Added eggs to your shopping list.")
        #expect(NativeIntentDialog.confirmation("Added eggs to your shopping list.", sync: .pending) == "Added eggs to your shopping list. Spoonjoy will sync it soon.")
        #expect(NativeIntentDialog.confirmation("Added eggs to your shopping list.", sync: .rejected(message: "Name is too long.")) == "Spoonjoy couldn't save that change: Name is too long.")
    }

    @Test("failures get a clear sentence, and a cancelled intent gets none")
    func failureDialog() {
        #expect(NativeIntentDialog.failureMessage(for: CancellationError()) == nil)
        #expect(NativeIntentDialog.failureMessage(for: NativeIntentActionError.authRequired) == "Sign in to Spoonjoy first. Nothing was changed.")
        #expect(NativeIntentDialog.failureMessage(for: NativeIntentActionError.emptyShoppingItem) == "Shopping item name must be non-empty.")
        #expect(NativeIntentDialog.failureMessage(for: TokenRefreshError.missingSession) == NativeIntentDialog.signInRequired)
        #expect(NativeIntentDialog.failureMessage(for: TokenRefreshError.sessionExpired) == NativeIntentDialog.signInRequired)
        #expect(NativeIntentDialog.failureMessage(for: TokenRefreshError.sessionRevoked) == NativeIntentDialog.signInRequired)
        #expect(NativeIntentDialog.failureMessage(for: TokenRefreshError.refreshInconclusive) == NativeIntentDialog.genericFailure)
        #expect(NativeIntentDialog.failureMessage(for: Self.transportError(.offline)) == NativeIntentDialog.offlineOnlineOnly)
        #expect(NativeIntentDialog.failureMessage(for: Self.transportError(.cancelled)) == nil)
        #expect(NativeIntentDialog.failureMessage(for: Self.transportError(.apiError)) == NativeIntentDialog.genericFailure)
        #expect(NativeIntentDialog.failureMessage(for: CocoaError(.fileWriteUnknown)) == "Spoonjoy couldn't make that change. Try again, or make it in the app.")
    }

    @Test("confirmations name what changed, and fall back to plain words for a blank name")
    func confirmationSentences() {
        #expect(NativeIntentDialog.addedShoppingItem(name: " eggs ") == "Added eggs to your shopping list.")
        #expect(NativeIntentDialog.addedShoppingItem(name: " ") == "Added that item to your shopping list.")
        #expect(NativeIntentDialog.setShoppingItemChecked(title: "Milk", checked: true) == "Checked off Milk.")
        #expect(NativeIntentDialog.setShoppingItemChecked(title: "Milk", checked: false) == "Unchecked Milk.")
        #expect(NativeIntentDialog.removedShoppingItem(title: "Milk") == "Removed Milk from your shopping list.")
        #expect(NativeIntentDialog.addedRecipeIngredients(recipeTitle: "Shakshuka") == "Added the ingredients for Shakshuka to your shopping list.")
        #expect(NativeIntentDialog.clearedCompletedShoppingItems == "Cleared checked-off items from your shopping list.")
        #expect(NativeIntentDialog.clearedShoppingList == "Cleared your shopping list.")
        #expect(NativeIntentDialog.forkedRecipe(recipeTitle: "Shakshuka", newTitle: " ") == "Made your own version of Shakshuka.")
        #expect(NativeIntentDialog.forkedRecipe(recipeTitle: "Shakshuka", newTitle: "Green Shakshuka") == "Made Green Shakshuka, your own version of Shakshuka.")
        #expect(NativeIntentDialog.savedRecipeToCookbook(recipeTitle: "Shakshuka", cookbookTitle: "Brunch") == "Saved Shakshuka to Brunch.")
        #expect(NativeIntentDialog.addedRecipeToCookbook(recipeTitle: "Shakshuka", cookbookTitle: "") == "Added Shakshuka to your cookbook.")
        #expect(NativeIntentDialog.removedRecipeFromCookbook(recipeTitle: "Shakshuka", cookbookTitle: "Brunch") == "Removed Shakshuka from Brunch.")
        #expect(NativeIntentDialog.createdCookbook(title: "Brunch") == "Created the cookbook Brunch.")
        #expect(NativeIntentDialog.renamedCookbook(oldTitle: "Brunch", newTitle: "Weekend") == "Renamed Brunch to Weekend.")
        #expect(NativeIntentDialog.deletedCookbook(title: "Brunch") == "Deleted the cookbook Brunch.")
        #expect(NativeIntentDialog.deletedRecipe(title: "Shakshuka") == "Deleted Shakshuka.")
        #expect(NativeIntentDialog.loggedCook(recipeTitle: "Shakshuka") == "Logged your cook of Shakshuka.")
        #expect(NativeIntentDialog.editedCookLog == "Updated your cook log.")
        #expect(NativeIntentDialog.deletedCookLog == "Deleted your cook log.")
        #expect(NativeIntentDialog.createdCoverFromCookLog(recipeTitle: "Shakshuka", activate: true) == "Made your cook photo the cover of Shakshuka.")
        #expect(NativeIntentDialog.createdCoverFromCookLog(recipeTitle: "Shakshuka", activate: false) == "Added your cook photo as a cover option for Shakshuka.")
        #expect(NativeIntentDialog.capturedRecipe == "Saved to your capture drafts.")
        #expect(NativeIntentDialog.submittedCaptureImport == "Sent your capture draft to import.")
        #expect(NativeIntentDialog.discardedCaptureDraft == "Discarded the capture draft.")
    }

    // MARK: Helpers

    private static func report(drained: [String], conflicts: [NativeSyncConflict]) -> NativeSyncReport {
        NativeSyncReport(
            trigger: .foreground,
            bootstrapCursor: nil,
            drainedClientMutationIDs: drained,
            conflicts: conflicts,
            pausedReason: nil,
            retryAfterSeconds: nil
        )
    }

    private static func transportError(_ kind: APITransportErrorKind) -> APITransportError {
        APITransportError(kind: kind, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
    }

    /// Each `struct <Name>: AppIntent` in the intents file, with its source up to the next declaration.
    private static func intentBodies() throws -> [String: String] {
        let source = try readRepoFile(appIntentsPath)
        let pattern = try NSRegularExpression(pattern: #"struct\s+(\w+)\s*:\s*AppIntent\s*\{"#)
        let range = NSRange(source.startIndex..., in: source)
        let matches = pattern.matches(in: source, range: range)
        var bodies: [String: String] = [:]
        for (index, match) in matches.enumerated() {
            let name = String(source[Range(match.range(at: 1), in: source)!])
            let start = Range(match.range, in: source)!.lowerBound
            let end = index + 1 < matches.count
                ? Range(matches[index + 1].range, in: source)!.lowerBound
                : source.endIndex
            var body = String(source[start..<end])
            if let nextDeclaration = body.range(of: "\n@available", options: [], range: body.index(after: body.startIndex)..<body.endIndex) {
                body = String(body[..<nextDeclaration.lowerBound])
            }
            bodies[name] = body
        }
        return bodies
    }

    private static func readRepoFile(_ relativePath: String) throws -> String {
        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while candidate.path != "/",
              !FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            candidate.deleteLastPathComponent()
        }
        return try String(contentsOf: candidate.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
