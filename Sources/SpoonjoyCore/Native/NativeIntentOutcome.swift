import Foundation

/// Whether an App Intent brings Spoonjoy to the front when it finishes.
///
/// Siri and Shortcuts should finish a change in place and say what happened. An intent opens the app only when seeing
/// the app is the point: opening a screen, cooking, searching, handing off to a signed-in web flow, or showing a
/// one-time secret.
public enum NativeIntentResultMode: Equatable, Sendable {
    case finishesInPlace
    case opensApp(reason: String)
}

/// Every App Intent in `SpoonjoyAppIntents.swift` and whether it opens the app. Contract tests compare this list with
/// the intent source, so an intent cannot start or stop opening the app without the list changing too.
public enum NativeIntentResultCatalog {
    public static let modes: [String: NativeIntentResultMode] = [
        "OpenRecipeIntent": .opensApp(reason: "Opening the recipe is the request."),
        "OpenCookbookIntent": .opensApp(reason: "Opening the cookbook is the request."),
        "OpenProfileIntent": .opensApp(reason: "Opening the profile is the request."),
        "OpenSettingsIntent": .opensApp(reason: "Opening Settings is the request."),
        "OpenNotificationAPNsStatusIntent": .opensApp(reason: "Opening notification delivery status is the request."),
        "OpenAPITokensIntent": .opensApp(reason: "Opening agent access settings is the request."),
        "CreateAPITokenIntent": .opensApp(reason: "A new access key is shown once, in the app, and never spoken by Siri."),
        "OpenAccountConnectionsIntent": .opensApp(reason: "Opening account connections is the request."),
        "OpenPasskeysIntent": .opensApp(reason: "Passkeys are managed in a signed-in web flow."),
        "OpenPasswordIntent": .opensApp(reason: "Passwords are managed in a signed-in web flow."),
        "LinkProviderIntent": .opensApp(reason: "Linking a provider needs the provider's sign-in page."),
        "SearchSpoonjoyIntent": .opensApp(reason: "Search results are shown in the app."),
        "ShareRecipeIntent": .opensApp(reason: "Sharing opens the public recipe page to share from."),
        "ShareCookbookIntent": .opensApp(reason: "Sharing opens the public cookbook page to share from."),
        "StartCookModeIntent": .opensApp(reason: "Cook mode runs on screen."),
        "ContinueCookModeIntent": .opensApp(reason: "Cook mode runs on screen."),
        "OpenCaptureDraftIntent": .opensApp(reason: "Opening the capture draft is the request."),

        "ReadNotificationPreferencesIntent": .finishesInPlace,
        "UpdateNotificationPreferencesIntent": .finishesInPlace,
        "UpdateProfileDisplayIntent": .finishesInPlace,
        "UpdateProfilePhotoIntent": .finishesInPlace,
        "RemoveProfilePhotoIntent": .finishesInPlace,
        "RevokeAPITokenIntent": .finishesInPlace,
        "DisconnectAccountConnectionIntent": .finishesInPlace,
        "LogoutIntent": .finishesInPlace,
        "RevokeCurrentSessionIntent": .finishesInPlace,
        "ShareShoppingListIntent": .finishesInPlace,
        "NextCookStepIntent": .finishesInPlace,
        "PreviousCookStepIntent": .finishesInPlace,
        "StartCookStepTimerIntent": .finishesInPlace,
        "ReadCookStepIntent": .finishesInPlace,
        "ForkRecipeIntent": .finishesInPlace,
        "SaveRecipeToCookbookIntent": .finishesInPlace,
        "CreateCookbookIntent": .finishesInPlace,
        "RenameCookbookIntent": .finishesInPlace,
        "DeleteCookbookIntent": .finishesInPlace,
        "AddRecipeToCookbookIntent": .finishesInPlace,
        "RemoveRecipeFromCookbookIntent": .finishesInPlace,
        "DeleteRecipeIntent": .finishesInPlace,
        "AddShoppingListItemIntent": .finishesInPlace,
        "SetShoppingListItemCheckedIntent": .finishesInPlace,
        "RemoveShoppingListItemIntent": .finishesInPlace,
        "AddRecipeIngredientsToShoppingListIntent": .finishesInPlace,
        "ClearCompletedShoppingItemsIntent": .finishesInPlace,
        "ClearShoppingListIntent": .finishesInPlace,
        "LogCookIntent": .finishesInPlace,
        "EditCookLogIntent": .finishesInPlace,
        "DeleteCookLogIntent": .finishesInPlace,
        "CreateCoverFromSpoonIntent": .finishesInPlace,
        "CaptureRecipeIntent": .finishesInPlace,
        "SubmitCaptureImportIntent": .finishesInPlace,
        "DiscardCaptureDraftIntent": .finishesInPlace
    ]

    public static var intentsThatOpenTheApp: Set<String> {
        Set(modes.compactMap { name, mode in mode == .finishesInPlace ? nil : name })
    }
}

/// What happened when an intent tried to send the edit it just queued.
public enum NativeIntentSyncOutcome: Equatable, Sendable {
    /// The server accepted every queued edit.
    case synced
    /// The edit is still queued, because the device is offline, the server was slow, or the send failed. The app
    /// sends it on its next sync, as it does for edits made in the app.
    case pending
    /// The server refused the edit.
    case rejected(message: String)
}

/// Sends the edits an intent just queued, through the same sync engine and queue the app uses, without making Siri
/// wait longer than `timeout`.
public enum NativeIntentWriteSync {
    public static let defaultTimeout: Duration = .seconds(5)

    public static func outcome(clientMutationIDs: [String], report: NativeSyncReport) -> NativeIntentSyncOutcome {
        let queued = Set(clientMutationIDs)
        if let conflict = report.conflicts.first(where: { queued.contains($0.clientMutationID) }) {
            return .rejected(message: conflict.message)
        }
        if !queued.isEmpty, queued.isSubset(of: Set(report.drainedClientMutationIDs)) {
            return .synced
        }
        return .pending
    }

    /// Runs `sync` and reports what happened to `clientMutationIDs`. A failed or slow sync leaves the edits queued.
    public static func drain(
        clientMutationIDs: [String],
        timeout: Duration = defaultTimeout,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        sync: @escaping @Sendable () async throws -> NativeSyncReport
    ) async -> NativeIntentSyncOutcome {
        guard !clientMutationIDs.isEmpty else {
            return .pending
        }
        return await withTaskGroup(of: NativeIntentSyncOutcome?.self) { group in
            group.addTask {
                do {
                    return outcome(clientMutationIDs: clientMutationIDs, report: try await sync())
                } catch {
                    return .pending
                }
            }
            group.addTask {
                try? await sleep(timeout)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first.flatMap { $0 } ?? .pending
        }
    }
}

/// The short sentences Siri says when an intent finishes in place.
public enum NativeIntentDialog {
    public static let pendingSyncSuffix = "Spoonjoy will sync it soon."
    public static let signInRequired = "Sign in to Spoonjoy first. Nothing was changed."
    public static let offlineOnlineOnly = "You're offline, and this change can't wait for a connection. Nothing was changed."
    public static let genericFailure = "Spoonjoy couldn't make that change. Try again, or make it in the app."

    public static func confirmation(_ done: String, sync: NativeIntentSyncOutcome) -> String {
        switch sync {
        case .synced:
            done
        case .pending:
            "\(done) \(pendingSyncSuffix)"
        case .rejected(let message):
            "Spoonjoy couldn't save that change: \(message)"
        }
    }

    /// The sentence for a failed intent, or nil when the intent was cancelled and should end without one.
    public static func failureMessage(for error: any Error) -> String? {
        if error is CancellationError {
            return nil
        }
        if let error = error as? NativeIntentActionError {
            return error == .authRequired ? signInRequired : error.description
        }
        if let error = error as? TokenRefreshError {
            return error == .refreshInconclusive ? genericFailure : signInRequired
        }
        if let error = error as? APITransportError {
            if error.isCancelled {
                return nil
            }
            return error.isOffline ? offlineOnlineOnly : genericFailure
        }
        return genericFailure
    }

    public static func addedShoppingItem(name: String) -> String {
        "Added \(named(name, otherwise: "that item")) to your shopping list."
    }

    public static func setShoppingItemChecked(title: String, checked: Bool) -> String {
        let item = named(title, otherwise: "that item")
        return checked ? "Checked off \(item)." : "Unchecked \(item)."
    }

    public static func removedShoppingItem(title: String) -> String {
        "Removed \(named(title, otherwise: "that item")) from your shopping list."
    }

    public static func addedRecipeIngredients(recipeTitle: String) -> String {
        "Added the ingredients for \(named(recipeTitle, otherwise: "that recipe")) to your shopping list."
    }

    public static let clearedCompletedShoppingItems = "Cleared checked-off items from your shopping list."
    public static let clearedShoppingList = "Cleared your shopping list."

    public static func forkedRecipe(recipeTitle: String, newTitle: String) -> String {
        let recipe = named(recipeTitle, otherwise: "that recipe")
        let trimmedNewTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNewTitle.isEmpty
            ? "Made your own version of \(recipe)."
            : "Made \(trimmedNewTitle), your own version of \(recipe)."
    }

    public static func savedRecipeToCookbook(recipeTitle: String, cookbookTitle: String) -> String {
        "Saved \(named(recipeTitle, otherwise: "that recipe")) to \(named(cookbookTitle, otherwise: "your cookbook"))."
    }

    public static func addedRecipeToCookbook(recipeTitle: String, cookbookTitle: String) -> String {
        "Added \(named(recipeTitle, otherwise: "that recipe")) to \(named(cookbookTitle, otherwise: "your cookbook"))."
    }

    public static func removedRecipeFromCookbook(recipeTitle: String, cookbookTitle: String) -> String {
        "Removed \(named(recipeTitle, otherwise: "that recipe")) from \(named(cookbookTitle, otherwise: "your cookbook"))."
    }

    public static func createdCookbook(title: String) -> String {
        "Created the cookbook \(named(title, otherwise: "you asked for"))."
    }

    public static func renamedCookbook(oldTitle: String, newTitle: String) -> String {
        "Renamed \(named(oldTitle, otherwise: "your cookbook")) to \(named(newTitle, otherwise: "its new title"))."
    }

    public static func deletedCookbook(title: String) -> String {
        "Deleted the cookbook \(named(title, otherwise: "you chose"))."
    }

    public static func deletedRecipe(title: String) -> String {
        "Deleted \(named(title, otherwise: "that recipe"))."
    }

    public static func loggedCook(recipeTitle: String) -> String {
        "Logged your cook of \(named(recipeTitle, otherwise: "that recipe"))."
    }

    public static let editedCookLog = "Updated your cook log."
    public static let deletedCookLog = "Deleted your cook log."

    public static func createdCoverFromCookLog(recipeTitle: String, activate: Bool) -> String {
        let recipe = named(recipeTitle, otherwise: "that recipe")
        return activate
            ? "Made your cook photo the cover of \(recipe)."
            : "Added your cook photo as a cover option for \(recipe)."
    }

    public static let capturedRecipe = "Saved to your capture drafts."
    public static let submittedCaptureImport = "Sent your capture draft to import."
    public static let discardedCaptureDraft = "Discarded the capture draft."

    private static func named(_ title: String, otherwise fallback: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
