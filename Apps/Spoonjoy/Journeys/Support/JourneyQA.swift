import Foundation

/// The QA mirror every journey talks to. Journeys never talk to spoonjoy.app.
enum JourneyQA {
    static let baseURL = URL(string: "https://spoonjoy-v2-qa.mendelow-studio.workers.dev")!
    /// The Settings "Environment" row for a build pointed at the QA mirror.
    static let expectedEnvironmentValue = "preview:spoonjoy-v2-qa.mendelow-studio.workers.dev"
    /// A password no journey account ever has; used to prove a wrong password is rejected.
    static let rejectedPassword = "journey-rejected-password"
}
