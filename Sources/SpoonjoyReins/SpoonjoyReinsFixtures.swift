import Foundation
import SpoonjoyCore

/// Every outside dependency a headless journey replaces, passed in through constructors. What isn't replaced stays the
/// production URLSession client on purpose: under `ReinsNetworkGuard` a request nobody expected is caught, so a journey
/// proves it needs no network instead of assuming it.
public struct SpoonjoyReinsFixtures: Sendable {
    /// The clock every journey reads, so two runs write the same bytes.
    public var now: @Sendable () -> Date
    /// The recipe editor's, settings' and capture's API transport (`NativeLiveAppStoreDependencies.recipeEditorAPITransport`).
    public var apiTransport: (@Sendable (any APIAuthenticationRefresher) -> any SpoonjoyAPITransport)?
    /// Settings' surface fetch (`NativeLiveAppStoreDependencies.settingsSurfaceFetch`).
    public var settingsSurfaceFetch: NativeSettingsSurfaceFetchOperation?
    /// Cook mode: how step alarms are set, what the mic hears, and the screen it runs on (`SpoonjoyReinsCookFixtures`).
    public var cook = SpoonjoyReinsCookFixtures()
    /// How the store starts: from the cache only (the UI tests' default, offline), or live-first against `syncTransport`.
    public var bootstrapMode: NativeLiveAppBootstrapMode = .restoreCacheOnly
    /// The sync engine's transport (`NativeSyncEngine(transport:)`); nil is the production URLSession one.
    public var syncTransport: (any NativeSyncTransport)?
    /// Cook sessions (`NativeLiveAppStoreDependencies.cookSessionClient`); nil is the production URLSession one.
    public var cookSessionClient: (@Sendable (APIClientConfiguration) -> any CookSessionClient)?
    /// Everyone's Recipes' transport (`LiveRecipeCatalogRepository(transport:)`); nil is the production URLSession one.
    public var catalogTransport: (any SpoonjoyAPITransport)?
    /// Where the recipe page keeps its scale and checks (`RecipePageProgressStore`); nil is the app's standard defaults.
    public var recipePageProgress: RecipePageProgressStore?

    public init(
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_793_000_000) },
        apiTransport: (@Sendable (any APIAuthenticationRefresher) -> any SpoonjoyAPITransport)? = nil,
        settingsSurfaceFetch: NativeSettingsSurfaceFetchOperation? = nil
    ) {
        self.now = now
        self.apiTransport = apiTransport
        self.settingsSurfaceFetch = settingsSurfaceFetch
    }

    var timestamp: () -> String {
        let now = self.now
        return { ISO8601DateFormatter().string(from: now()) }
    }
}

/// Launching Spoonjoy headless: a store over a kitchen folder, bootstrapped from cache, and the shell over it. A relaunch
/// is a new launch over the same folder, as killing the app and opening it again reads the same files.
public enum SpoonjoyReinsLaunch {
    @MainActor
    public static func launch(in directory: URL, fixtures: SpoonjoyReinsFixtures = SpoonjoyReinsFixtures()) async throws -> SpoonjoyReinsShell {
        let store = try SpoonjoyFixtureKitchen.store(in: directory, fixtures: fixtures)
        await store.bootstrap()
        let shell = SpoonjoyReinsShell(store: store, fixtures: fixtures)
        shell.kitchenDirectory = directory
        return shell
    }

    /// A fresh folder with `kitchen` written into it (or the bundled fixture kitchen when nil).
    public static func freshDirectory(kitchen: SpoonjoyJourneyKitchen? = nil) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-reins-\(UUID().uuidString)")
        if let kitchen {
            try kitchen.write(to: directory)
        } else {
            try SpoonjoyFixtureKitchen.copy(to: directory)
        }
        return directory
    }
}
