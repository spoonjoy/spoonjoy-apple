import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins

/// Spoonjoy launched headless over a kitchen folder. `relaunch()` is killing the app and opening it again: a new store
/// and a new session over the same files, so whatever survives is what the app wrote to disk.
@MainActor
final class HeadlessApp {
    let directory: URL
    let fixtures: SpoonjoyReinsFixtures
    private(set) var shell: SpoonjoyReinsShell
    private(set) var session: ReinsSession

    private init(directory: URL, fixtures: SpoonjoyReinsFixtures, shell: SpoonjoyReinsShell) {
        self.directory = directory
        self.fixtures = fixtures
        self.shell = shell
        self.session = ReinsSession(shell)
    }

    /// Launches over `kitchen`, or over the bundled fixture kitchen when nil.
    static func launch(_ kitchen: SpoonjoyJourneyKitchen? = nil, fixtures: SpoonjoyReinsFixtures = SpoonjoyReinsFixtures()) async throws -> HeadlessApp {
        let directory = try SpoonjoyReinsLaunch.freshDirectory(kitchen: kitchen)
        return HeadlessApp(directory: directory, fixtures: fixtures, shell: try await SpoonjoyReinsLaunch.launch(in: directory, fixtures: fixtures))
    }

    var journey: ReinsJourney { ReinsJourney(session) }
    var screen: ReinsScreen { session.ls() }

    func relaunch(fixtures: SpoonjoyReinsFixtures? = nil) async throws {
        shell = try await SpoonjoyReinsLaunch.launch(in: directory, fixtures: fixtures ?? self.fixtures)
        session = ReinsSession(shell)
    }
}

/// Runs a journey with every request refused, then waits out the cook session's debounced push (800 ms) so a late
/// request fails the journey too.
@MainActor
func headless(_ body: @MainActor () async throws -> Void) async throws {
    try await ReinsNetworkGuard.withNetworkBlocked {
        try await body()
        try await Task.sleep(for: .seconds(1))
    }
}
