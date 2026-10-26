#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

/// Draws the step alarm's system Live Activity. AlarmKit owns the countdown, pause and alert state, so this view only reads it.
@available(iOS 26.0, *)
struct SpoonjoyCookTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SpoonjoyCookTimerMetadata>.self) { context in
            // The Lock Screen card follows the system appearance through the theme's light and dark roles.
            CookTimerLockScreenView(metadata: context.attributes.metadata, state: context.state)
                .activityBackgroundTint(KitchenTableTheme.page)
                .activitySystemActionForegroundColor(KitchenTableTheme.ink)
                .widgetURL(context.attributes.metadata.flatMap { URL(string: $0.deepLink) })
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stepLabel(context.attributes.metadata))
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.brass)
                        Text(context.attributes.metadata?.stepTitle ?? "Timer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KitchenTableTheme.onPhoto)
                            .lineLimit(2)
                    }
                    .environment(\.colorScheme, .dark)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CookTimerReadout(mode: context.state.mode, font: .title2.monospacedDigit().weight(.bold))
                        .frame(maxWidth: 110, alignment: .trailing)
                        .environment(\.colorScheme, .dark)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.recipeTitle ?? "Spoonjoy")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(KitchenTableTheme.onPhotoMuted)
                        .lineLimit(1)
                        .environment(\.colorScheme, .dark)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CookTimerControls(alarmID: context.state.alarmID, recipeID: context.attributes.metadata?.recipeID ?? "", mode: context.state.mode)
                        .environment(\.colorScheme, .dark)
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(KitchenTableTheme.Night.brassNight)
            } compactTrailing: {
                CookTimerReadout(mode: context.state.mode, font: .caption.monospacedDigit().weight(.semibold))
                    .frame(maxWidth: 52)
                    .environment(\.colorScheme, .dark)
            } minimal: {
                Image(systemName: isPaused(context.state.mode) ? "pause.fill" : "timer")
                    .foregroundStyle(KitchenTableTheme.Night.brassNight)
            }
            .widgetURL(context.attributes.metadata.flatMap { URL(string: $0.deepLink) })
            .keylineTint(KitchenTableTheme.Night.brassNight)
        }
    }
}

@available(iOS 26.0, *)
private func stepLabel(_ metadata: SpoonjoyCookTimerMetadata?) -> String {
    metadata.map { "Step \($0.stepNumber)" } ?? "Timer"
}

@available(iOS 26.0, *)
private func isPaused(_ mode: AlarmPresentationState.Mode) -> Bool {
    if case .paused = mode {
        return true
    }
    return false
}

@available(iOS 26.0, *)
private struct CookTimerLockScreenView: View {
    let metadata: SpoonjoyCookTimerMetadata?
    let state: AlarmPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(metadata?.recipeTitle ?? "Spoonjoy")
                    .font(.system(.headline, design: .serif).weight(.bold))
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(stepLabel(metadata))
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(metadata?.stepTitle ?? "Timer")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineLimit(2)
                Spacer(minLength: 8)
                CookTimerReadout(mode: state.mode, font: .system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit())
                    .frame(maxWidth: 140, alignment: .trailing)
            }

            CookTimerControls(alarmID: state.alarmID, recipeID: metadata?.recipeID ?? "", mode: state.mode)
        }
        .padding(16)
    }
}

@available(iOS 26.0, *)
struct CookTimerReadout: View {
    let mode: AlarmPresentationState.Mode
    let font: Font

    var body: some View {
        Group {
            switch mode {
            case .countdown(let countdown):
                // The system draws and advances the countdown, so no update is needed each second.
                Text(timerInterval: countdown.startDate...countdown.fireDate, countsDown: true)
            case .paused(let paused):
                Text(Duration.seconds(max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)), format: .time(pattern: .minuteSecond))
            case .alert:
                Text("Done")
            @unknown default:
                Text("Timer")
            }
        }
        .font(font)
        .multilineTextAlignment(.trailing)
        .foregroundStyle(isAlert ? KitchenTableTheme.herb : KitchenTableTheme.ink)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .accessibilityLabel(accessibilityText)
    }

    private var isAlert: Bool {
        if case .alert = mode {
            return true
        }
        return false
    }

    private var accessibilityText: String {
        switch mode {
        case .countdown:
            "Timer running"
        case .paused:
            "Timer paused"
        case .alert:
            "Timer done"
        @unknown default:
            "Timer"
        }
    }
}

@available(iOS 26.0, *)
struct CookTimerControls: View {
    let alarmID: UUID
    let recipeID: String
    let mode: AlarmPresentationState.Mode

    // Light and dark roles, so the same controls work on the Lock Screen in either appearance and on the black island.
    private var primaryText: Color { KitchenTableTheme.onInk }
    private var primaryFill: Color { KitchenTableTheme.action }
    private var secondaryText: Color { KitchenTableTheme.ink }
    private var secondaryFill: Color { KitchenTableTheme.vellum }

    private var showsCancel: Bool {
        switch mode {
        case .countdown, .paused:
            return true
        default:
            return false
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            switch mode {
            case .countdown:
                Button(intent: PauseCookTimerIntent(alarmID: alarmID)) {
                    Label("Pause", systemImage: "pause.fill")
                        .font(KitchenTableTheme.uiLabel)
                        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(primaryText)
                .background(primaryFill, in: Capsule())
            case .paused:
                Button(intent: ResumeCookTimerIntent(alarmID: alarmID)) {
                    Label("Resume", systemImage: "play.fill")
                        .font(KitchenTableTheme.uiLabel)
                        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(primaryText)
                .background(primaryFill, in: Capsule())
            case .alert:
                Button(intent: StopCookTimerIntent(alarmID: alarmID)) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(KitchenTableTheme.uiLabel)
                        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(primaryText)
                .background(primaryFill, in: Capsule())
            @unknown default:
                EmptyView()
            }

            // A running or paused timer can be cancelled here, not only stopped after it rings.
            if showsCancel {
                Button(intent: StopCookTimerIntent(alarmID: alarmID)) {
                    Label("Cancel", systemImage: "xmark")
                        .font(KitchenTableTheme.uiLabel)
                        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(secondaryText)
                .background(secondaryFill, in: Capsule())
                .accessibilityLabel("Cancel timer")
                .accessibilityIdentifier("cookTimer.liveActivity.cancel")
            }

            Button(intent: NextCookActivityStepIntent(recipeID: recipeID)) {
                Label("Next step", systemImage: "forward.fill")
                    .font(KitchenTableTheme.uiLabel)
                    .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(secondaryText)
            .background(secondaryFill, in: Capsule())
        }
    }
}
#endif
