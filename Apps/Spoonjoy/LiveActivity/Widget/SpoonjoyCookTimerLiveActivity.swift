import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 26.0, *)
struct SpoonjoyCookTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpoonjoyCookTimerAttributes.self) { context in
            CookTimerLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(KitchenTableTheme.bone)
                .activitySystemActionForegroundColor(KitchenTableTheme.charcoal)
                .widgetURL(context.attributes.deepLink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.stepLabel)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.brass)
                        Text(context.state.stepTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CookTimerReadout(state: context.state, font: .title2.monospacedDigit().weight(.bold))
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.recipeTitle)
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CookTimerControls(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(KitchenTableTheme.brass)
            } compactTrailing: {
                CookTimerReadout(state: context.state, font: .caption.monospacedDigit().weight(.semibold))
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: context.state.phase == .paused ? "pause.fill" : "timer")
                    .foregroundStyle(KitchenTableTheme.brass)
            }
            .widgetURL(context.attributes.deepLink)
            .keylineTint(KitchenTableTheme.brass)
        }
    }
}

@available(iOS 26.0, *)
private struct CookTimerLockScreenView: View {
    let attributes: SpoonjoyCookTimerAttributes
    let state: SpoonjoyCookTimerAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(attributes.recipeTitle)
                    .font(.system(.headline, design: .serif).weight(.bold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(state.stepLabel)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.stepTitle)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .lineLimit(2)
                    if let timerStepLabel = state.timerStepLabel {
                        Text(timerStepLabel)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                CookTimerReadout(state: state, font: .system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit())
                    .frame(maxWidth: 140, alignment: .trailing)
            }

            CookTimerControls(state: state)
        }
        .padding(16)
    }
}

@available(iOS 26.0, *)
private struct CookTimerReadout: View {
    let state: SpoonjoyCookTimerAttributes.ContentState
    let font: Font

    var body: some View {
        Group {
            switch state.phase {
            case .running:
                // The system draws and advances the countdown, so no update is needed each second.
                Text(timerInterval: state.startDate...state.endDate, countsDown: true)
            case .paused:
                Text(Duration.seconds(state.pausedRemainingSeconds), format: .time(pattern: .minuteSecond))
            case .finished:
                Text("Done")
            }
        }
        .font(font)
        .multilineTextAlignment(.trailing)
        .foregroundStyle(state.phase == .finished ? KitchenTableTheme.herb : KitchenTableTheme.charcoal)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch state.phase {
        case .running:
            "Timer running"
        case .paused:
            "Timer paused"
        case .finished:
            "Timer done"
        }
    }
}

@available(iOS 26.0, *)
private struct CookTimerControls: View {
    let state: SpoonjoyCookTimerAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            if state.phase != .finished {
                Button(intent: ToggleCookTimerIntent()) {
                    Label(state.phase == .paused ? "Resume" : "Pause", systemImage: state.phase == .paused ? "play.fill" : "pause.fill")
                        .font(KitchenTableTheme.uiLabel)
                        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(KitchenTableTheme.bone)
                .background(KitchenTableTheme.action, in: Capsule())
            }

            if state.canAdvance {
                Button(intent: NextCookActivityStepIntent()) {
                    Label("Next step", systemImage: "forward.fill")
                        .font(KitchenTableTheme.uiLabel)
                        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .background(KitchenTableTheme.vellum, in: Capsule())
            }
        }
    }
}
