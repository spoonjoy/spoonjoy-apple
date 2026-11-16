import OSLog
import SpoonjoyCore
import SwiftUI

/// Decides once per process whether windows show the shell or the safe page (``LaunchSafeMode``), and marks the
/// launch finished once a shell has been up and active for `NativeLaunchSettlement.settleDelay` (the same settle as the
/// `launch_completed` report, or at once when that report has already settled the process), or when its scene first
/// goes to the background.
///
/// Created with the app but decides nothing until the first window asks, so a launch with no window (an App Intent,
/// a notification) is never counted. Crashes before the first window is built (in the App's init or
/// `application(_:didFinishLaunchingWithOptions:)`) are not counted either.
@MainActor
@Observable
final class LaunchSafeModeController {
    private static let logger = Logger(subsystem: "app.spoonjoy", category: "launch.safe-mode")
    // Instruments shows these as points of interest beside the launch.
    private static let signposter = OSSignposter(subsystem: "app.spoonjoy", category: .pointsOfInterest)

    @ObservationIgnored private let options: LaunchSafeModeOptions
    @ObservationIgnored private let ledger: LaunchSafeMode
    @ObservationIgnored private var decision: LaunchSafeMode.Decision?
    @ObservationIgnored private var finished = false
    @ObservationIgnored private var safePageStarted = false
    /// Observed: tapping Try again in any window brings every window back to the shell.
    private var leftSafeMode = false
    /// Observed: filled in after the safe page is already on screen.
    private(set) var recentRecipes: [LaunchSafeModeRecentRecipe] = []

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
#if DEBUG
        options = LaunchSafeModeOptions(arguments: arguments, isDebugBuild: true)
#else
        options = LaunchSafeModeOptions(arguments: arguments, isDebugBuild: false)
#endif
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        ledger = LaunchSafeMode(storage: LaunchSafeModeFile(appDirectory: Self.appDirectory), buildVersion: buildVersion)
    }

    private nonisolated static var appDirectory: URL {
        NativeAppStateLocation.defaultFileURL().deletingLastPathComponent()
    }

    /// Whether the window shows the safe page instead of the shell. The first call decides the launch and writes the
    /// count to disk before the shell is built; a window first built in the background is not counted.
    func showsSafePage(scenePhase: ScenePhase) -> Bool {
        !leftSafeMode && decide(scenePhase: scenePhase) != .normal
    }

#if DEBUG
    var crashesShell: Bool { options.armed && options.crashesShell }
#endif

    func tryAgain() {
        Self.logger.notice("launch_safe_mode_try_again")
        Self.signposter.emitEvent("launch_safe_mode_try_again")
        ledger.leaveSafeMode()
        leftSafeMode = true
    }

    /// The safe page is on screen: report the loop once, then read recent recipes off the main thread.
    func safePageAppeared() {
        guard !safePageStarted, case .safeMode(let launch)? = decision else {
            return
        }
        safePageStarted = true
        if launch.reportsLoop {
            report(unfinishedLaunches: launch.unfinishedLaunches)
        }
        guard launch.readsRecentRecipes else {
            Self.logger.notice("launch_safe_mode_bare_page")
            return
        }
        Task {
            let recipes = await Task.detached(priority: .utility) { () -> [LaunchSafeModeRecentRecipe] in
                do {
                    return try LaunchSafeModeRecentRecipes.read(appDirectory: Self.appDirectory)
                } catch {
                    return []
                }
            }.value
            recentRecipes = recipes
        }
    }

    /// Called whenever the safe page's scene phase changes: once it has been up a few seconds, or goes to the
    /// background, the next safe launch may read recipes again.
    func safePageIsUp(scenePhase: ScenePhase) async {
        guard await settles(scenePhase: scenePhase) else {
            return
        }
        ledger.markSafeLaunchSettled()
    }

    /// Called whenever a shell's scene phase changes: after the delay while active, or on first going to the
    /// background, the launch has finished.
    func shellIsUp(scenePhase: ScenePhase) async {
        guard options.armed, !options.neverSucceeds, !finished else {
            return
        }
        // The shell's `launch_completed` report already settled this process (NativeLaunchSettlement): it has finished.
        var settled = scenePhase == .active && NativeLaunchSettlement.process.isSettled
        if !settled {
            settled = await settles(scenePhase: scenePhase)
        }
        guard settled, !finished else {
            return
        }
        finished = true
        ledger.markLaunchSucceeded()
        Self.logger.info("launch_safe_mode_launch_finished")
    }

    private func settles(scenePhase: ScenePhase) async -> Bool {
        switch scenePhase {
        case .background:
            return true
        case .active:
            do {
                try await Task.sleep(for: LaunchSafeMode.successDelay)
                return true
            } catch {
                return false
            }
        default:
            return false
        }
    }

    private func decide(scenePhase: ScenePhase) -> LaunchSafeMode.Decision {
        if let decision {
            return decision
        }
        var decided = LaunchSafeMode.Decision.normal
        if options.armed, scenePhase != .background {
            if let preset = options.presetUnfinishedLaunches {
                ledger.presetUnfinishedLaunches(preset)
            }
            decided = ledger.beginLaunch()
        }
        decision = decided
        if case .safeMode(let launch) = decided {
            Self.logger.error("launch_safe_mode_entered unfinished_launches=\(launch.unfinishedLaunches, privacy: .public)")
            Self.signposter.emitEvent("launch_safe_mode_entered", "unfinished_launches=\(launch.unfinishedLaunches)")
        } else if options.armed {
            // A window first built in the background leaves the count alone, so it never finishes a launch either.
            finished = scenePhase == .background
        }
        return decided
    }

    private func report(unfinishedLaunches: Int) {
        let client = SpoonjoyRootView.defaultAppleSignInTelemetryClient()
        let event = LaunchSafeMode.enteredTelemetryEvent(
            unfinishedLaunches: unfinishedLaunches,
            environment: client.environment,
            metadata: client.metadata
        )
        // Diagnostic only: the safe page never waits for the network.
        Task.detached { await client.report(event, client.configuration) }
    }
}

/// The window's content: the shell, or the safe page after launches in a row that never finished opening.
struct LaunchSafeModeGate<Shell: View>: View {
    let controller: LaunchSafeModeController
    @ViewBuilder let shell: () -> Shell
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if controller.showsSafePage(scenePhase: scenePhase) {
            LaunchSafeModeView(recipes: controller.recentRecipes, tryAgain: controller.tryAgain)
                .onAppear { controller.safePageAppeared() }
                .task(id: scenePhase) {
                    await controller.safePageIsUp(scenePhase: scenePhase)
                }
        } else {
            // Erased, so the shell's deep generic type never adds to this one (#355).
            AnyView(shellContent())
                .task(id: scenePhase) {
                    await controller.shellIsUp(scenePhase: scenePhase)
                }
        }
    }

    private func shellContent() -> Shell {
#if DEBUG
        if controller.crashesShell {
            // The UI test's sudden death: the shell is being built, the count is already on disk, and the launch
            // cannot have finished. `_exit` ends the process at once, as a crash does, but leaves no crash report:
            // XCTest attaches a crash report to the test after it ends, as a failure no expectation can cover.
            _exit(EXIT_FAILURE)
        }
#endif
        return shell()
    }
}

/// A plain page: no navigation stack, no tabs, nothing that loads. Spoonjoy's paper, ink and type, a short note,
/// Try again, and the most recent recipes on this device, read only.
struct LaunchSafeModeView: View {
    let recipes: [LaunchSafeModeRecentRecipe]
    let tryAgain: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
                VStack(alignment: .leading, spacing: KitchenTableTheme.sectionSpacing) {
                    Text("A quiet start")
                        .font(KitchenTableTheme.displayTitle)
                        .foregroundStyle(KitchenTableTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Spoonjoy closed before it finished opening, more than once, so it opened this plain page instead. Nothing in your kitchen was changed.")
                        .font(KitchenTableTheme.story)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: tryAgain) {
                    Text("Try again")
                        .font(KitchenTableTheme.control)
                        .foregroundStyle(KitchenTableTheme.onInk)
                        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                        .background(KitchenTableTheme.action, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("launchSafeMode.tryAgain")

                if !recipes.isEmpty {
                    VStack(alignment: .leading, spacing: KitchenTableTheme.sectionSpacing) {
                        Text("Recently in your kitchen")
                            .font(KitchenTableTheme.sectionTitle)
                            .foregroundStyle(KitchenTableTheme.ink)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(recipes) { recipe in
                            Text(recipe.title)
                                .font(KitchenTableTheme.objectTitle)
                                .foregroundStyle(KitchenTableTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(KitchenTableTheme.hairline)
                                        .frame(height: KitchenTableTheme.hairlineWidth)
                                }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("launchSafeMode.recipes")
                }

                Text("If it keeps closing, Spoonjoy comes back to this page.")
                    .font(KitchenTableTheme.meta)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
            .padding(KitchenTableTheme.pagePadding)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(KitchenTableTheme.page.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("launchSafeMode.root")
    }
}
