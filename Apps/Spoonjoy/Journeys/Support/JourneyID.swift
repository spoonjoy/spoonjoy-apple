/// Accessibility identifiers the journeys query, named `<screen>.<element>`.
enum JourneyID {
    // Sign-in identifiers predate the naming scheme; renaming them would churn existing scripts.
    static let signInIdentifier = "native sign-in email or username"
    static let signInPassword = "native sign-in password"
    static let passwordSignIn = "native password sign-in"
    static let signInStatus = "native sign-in status"
    static let signInSettings = "signin.settings"

    static let settingsEnvironmentValue = "settings.environment.value"
    static let settingsClose = "settings.close"
    static let settingsSignOut = "settings.signout"

    static let shellMore = "shell.more"
    static let shellMoreSettings = "shell.more.settings"
    static let shellMoreSearch = "shell.more.search"

    static let kitchenRoot = "kitchen.root"
}
