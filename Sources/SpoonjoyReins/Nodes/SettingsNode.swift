import Foundation
import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    /// Settings (SettingsView over `settingsSurfaceViewModel`): the account, the environment row, and the rows the
    /// journeys use. Server-only rows are off offline (`onlineOnlyActionsDisabled`); the account's own sections need a
    /// known account.
    var settingsNode: ReinsNode {
        let surface = content.settingsSurfaceViewModel
        let disabled = surface.onlineOnlyActionsDisabled
        let account = surface.data.account
        var rows = ["Sign Out"]
        var actions: [ReinsAction] = []
        if account != nil {
            rows = ["Blocked chefs", "Download my data", "Delete account…"] + rows
            actions.append(ReinsAction("openBlockedChefs", "Blocked chefs") { [unowned self] in try await self.openBlockedChefs() })
        }
        if !disabled {
            if let username = account?.username {
                actions.append(ReinsAction("downloadData", "Download my data") { [unowned self] in
                    await self.runSettingsAction(.exportAccountData(username: username), surface: surface)
                })
                if let form = surface.accountDeletionForm() {
                    actions.append(ReinsAction("deleteAccount", "Delete account…") { [unowned self] in self.sheet = .deleteAccount(form) })
                }
            }
            actions.append(ReinsAction("signOut", "Sign Out") { [unowned self] in self.sheet = .confirmSignOut })
        }
        return ReinsNode("settings", state: [
            "account": account.map { ["username": .string($0.username), "email": .string($0.email)] } ?? .null,
            "environment": .string(surface.data.environment.rawValue),
            "connectivity": .string(disabled ? "offline" : "online"),
            "rows": .array(rows.map(ReinsValue.string)),
            "disabled": .array(disabled ? ["Download my data", "Delete account…", "Sign Out"].filter(rows.contains).map(ReinsValue.string) : []),
            "message": page.settingsMessage.map(ReinsValue.string) ?? .null,
        ], actions: actions)
    }

    /// The Delete account sheet (AccountDeletionSheet). Deleting asks the server, so only Cancel is headless.
    func deleteAccountSheetNode(_ form: AccountDeletionForm) -> ReinsNode {
        ReinsNode("deleteAccount", state: [
            "username": .string(form.username),
            "reauthentication": .string(String(describing: form.reauthentication)),
        ], actions: [
            ReinsAction("cancel", "Cancel") { [unowned self] in self.sheet = nil },
        ])
    }

    /// The "Sign out?" confirmation; Sign Out runs the logout plan.
    var confirmSignOutSheetNode: ReinsNode {
        ReinsNode("confirmSignOut", state: [
            "title": "Sign out?",
            "message": "Spoonjoy will revoke the local session and send you through the secure sign-out flow.",
        ], actions: [
            ReinsAction("confirm", "Sign Out") { [unowned self] in
                self.sheet = nil
                await self.runSettingsAction(.logout, surface: self.content.settingsSurfaceViewModel)
            },
            ReinsAction("cancel", "Cancel") { [unowned self] in self.sheet = nil },
        ])
    }

    /// SettingsView's `planSettingsAction`, then PlatformNavigationView's `performSettingsAction`: one runner
    /// (`SettingsActionPlan.perform`) over the live store's methods. The secure hand-off opens Safari in the app;
    /// here it is recorded in `page.openedURLs`.
    func runSettingsAction(_ action: SettingsAction, surface: SettingsSurfaceViewModel) async {
        do {
            let plan = try surface.actionPlanner.plan(action)
            page.settingsMessage = plan.onlineOnlyReason?.message ?? plan.userFacingMessage
            let outcome = try await plan.perform(
                queuedMutations: content.queuedMutations,
                queueMutation: { [store] in try await store.queueMutation($0) },
                queueMutations: { [store] in _ = try await store.queueMutations($0, drainImmediately: $1) },
                execute: { [store] in try await store.executeSettingsActionRequest($0, responseHandling: $1) },
                sessionOperation: { [store] in try await store.performSettingsSessionOperation($0) },
                openURL: { [unowned self] in self.page.openedURLs.append($0) }
            )
            if case .exportedAccountData? = outcome {
                page.settingsMessage = "Your data is ready to save or share."
            }
        } catch {
            page.settingsMessage = SettingsActionFailureMessage.serverMessage(for: error)
                ?? "Settings could not be updated. Try again. Code: \(SettingsActionFailureMessage.diagnosticCode(for: error))."
        }
    }
}
