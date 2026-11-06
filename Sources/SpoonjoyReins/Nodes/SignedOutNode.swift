import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    /// The sign-in screen (SignedOutSetupView). Signing in talks to the server, so it stays a live journey; the
    /// screen's Settings link is here.
    var signedOutNode: ReinsNode {
        ReinsNode("signIn", state: [
            "title": "Sign in",
            "pendingRoute": .string(navigation.route.stateIdentifier),
        ], actions: [
            ReinsAction("openSettings", "Open Settings") { [unowned self] in self.navigate(to: .settings) },
        ])
    }

    /// Settings over the sign-in screen (SpoonjoyRootView.settingsContent), whose Kitchen button leaves it.
    var standaloneSettingsNode: ReinsNode {
        ReinsNode("standaloneSettings", state: [:], lends: [
            ReinsAction("closeSettings", "Back to the kitchen") { [unowned self] in
                // SpoonjoyRootView.openKitchenFromStandaloneSettings.
                self.navigate(to: .kitchen)
                self.store.recordingOpenedRoute(.kitchen)
            },
        ], child: settingsNode)
    }
}
