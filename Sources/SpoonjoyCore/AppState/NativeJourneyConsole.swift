import Foundation

/// A launch environment entry that UI tests pass so the app never waits on its own console.
///
/// When `OS_ACTIVITY_DT_MODE` is on, every `os_log` message is also written synchronously to the app's
/// stderr. XCUITest evaluates element queries inside the app, on the main thread, and its accessibility
/// attribute fetches log as they go. If whatever reads that stderr stops draining it, the write blocks and
/// the main thread stops with it: two RecipesJourney runs spent 249 of 249 and 275 of 280 spindump samples
/// in `writev`, and failed with "Failed to get matching snapshots: Timed out while evaluating UI query."
/// Turning the mirror off sends the messages only to the unified log, which never blocks the caller. An
/// installed app has no console reader, so this matches what people run.
public enum NativeJourneyConsole {
    public static let environmentKey = "OS_ACTIVITY_DT_MODE"
    public static let value = "NO"
}
