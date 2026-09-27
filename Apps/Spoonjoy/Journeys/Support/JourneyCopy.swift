/// User-visible copy that journeys assert. Anything else is found by `JourneyID`.
enum JourneyCopy {
    /// The confirmation dialog button that signs out.
    static let signOutConfirm = "Sign Out"
    /// The sign-in status after a rejected password (`SignedOutSetupView.passwordSignInFailureMessage`).
    static let wrongPasswordStatus = "Could not sign in. Check your username, password, and connection."
}
