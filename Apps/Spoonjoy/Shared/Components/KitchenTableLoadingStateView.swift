import SpoonjoyCore
import SwiftUI

struct KitchenTableLoadingStateView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var readinessToken: ScreenshotVisualReadinessBlockingToken

    let title: String
    let subtitle: String?
    let systemImage: String?

    init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        _readinessToken = State(initialValue: ScreenshotVisualReadinessBlockingToken(resourceID: "route-loading:\(title)"))
    }

    var body: some View {
        VStack(spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
                    .accessibilityHidden(true)
            }

            ProgressView()
                .controlSize(.large)

            VStack(spacing: 5) {
                Text(title)
                    .font(KitchenTableTheme.sectionTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                if let subtitle {
                    Text(subtitle)
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(32)
        .background(KitchenTableTheme.bone)
        .transition(accessibilityReduceMotion ? .identity : .opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .task(id: readinessToken) {
            await ScreenshotVisualReadiness.beginBlockingIndicator(readinessToken)
            do {
                try await Task.sleep(nanoseconds: .max)
            } catch {
                // View disappearance cancels the task and releases the readiness blocker.
            }
            await ScreenshotVisualReadiness.endBlockingIndicator(readinessToken)
        }
    }
}

private struct SpoonjoyBackToRecipesKey: EnvironmentKey {
    static let defaultValue: (@Sendable () -> Void)? = nil
}

extension EnvironmentValues {
    /// Set by the shell: opens the recipes list, so a page that cannot load always has a way back.
    var spoonjoyBackToRecipes: (@Sendable () -> Void)? {
        get { self[SpoonjoyBackToRecipesKey.self] }
        set { self[SpoonjoyBackToRecipesKey.self] = newValue }
    }
}

/// A page that is missing or could not load: the same quiet empty-state treatment as the web's
/// "Page not found", with a button back to the recipes instead of a dead end.
struct KitchenTableRouteErrorView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.spoonjoyBackToRecipes) private var backToRecipes

    let message: String
    let systemImage: String

    init(message: String, systemImage: String) {
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Spoonjoy".uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
            } icon: {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(KitchenTableTheme.brass)

            Text(message)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .fixedSize(horizontal: false, vertical: true)

            Text(guidance)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(KitchenTableTheme.line.opacity(0.55))
                .frame(height: 1)

            if let backToRecipes {
                Button(action: backToRecipes) {
                    Label("Back to recipes", systemImage: "book")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
                .frame(maxWidth: 260)
                .accessibilityIdentifier("route.error.back")
            }
        }
        .padding(KitchenTableTheme.pagePadding)
        .frame(maxWidth: 720, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(KitchenTableTheme.bone)
        .transition(accessibilityReduceMotion ? .identity : .opacity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("route.error")
    }

    private var guidance: String {
        message.contains("find")
            ? "It may have been removed, or the link may be out of date."
            : "Check your connection, then try again from the recipes."
    }
}
