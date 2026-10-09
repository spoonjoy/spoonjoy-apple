import Foundation

/// How long a Spoonjoy API request may go without hearing from the server before it fails. The system default is
/// 60 s, which let one stalled request hold a launch sync, a sign-in or an App Intent for a minute. A timeout is
/// treated as being offline, so the work stays queued and the next trigger tries again.
public enum APIRequestTimeout {
    public static let seconds: TimeInterval = 15
    /// A recipe import sends nothing back until the server has fetched the page (up to 15 s) and extracted the
    /// recipe from it (up to 30 s), so it waits longer. A timed-out import would be queued as offline even though
    /// the device is online.
    public static let recipeImportSeconds: TimeInterval = 60
}
