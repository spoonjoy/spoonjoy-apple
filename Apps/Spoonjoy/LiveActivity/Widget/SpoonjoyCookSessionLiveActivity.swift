import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Draws the cook session in the Dynamic Island, on the Lock Screen and in StandBy.
///
/// The Lock Screen follows the system appearance. The Dynamic Island is always black, so its views pin the dark
/// palette. On a limited-width island (iPhone Duo) the compact presentation is one 28 pt brass ring with the step
/// number inside, as the HIG asks for limited-width presentations.
struct SpoonjoyCookSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpoonjoyCookSessionAttributes.self) { context in
            CookSessionLockScreenView(snapshot: context.state, recipeID: context.attributes.recipeID)
                .activityBackgroundTint(KitchenTableTheme.page)
                .activitySystemActionForegroundColor(KitchenTableTheme.ink)
                .widgetURL(URL(string: context.attributes.deepLink))
        } dynamicIsland: { context in
            let snapshot = context.state
            let recipeID = context.attributes.recipeID
            let deepLink = URL(string: context.attributes.deepLink)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CookSessionRing(snapshot: snapshot, diameter: 44)
                        .padding(.leading, 4)
                        .islandPalette()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(snapshot.stepNumber) of \(snapshot.stepCount)")
                        .font(KitchenTableTheme.uiLabel.monospacedDigit())
                        .foregroundStyle(KitchenTableTheme.brass)
                        .padding(.trailing, 4)
                        .islandPalette()
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.stepTitle)
                            .font(KitchenTableTheme.objectTitle)
                            .foregroundStyle(KitchenTableTheme.onPhoto)
                            .lineLimit(1)
                        Text(snapshot.recipeTitle)
                            .font(KitchenTableTheme.meta)
                            .foregroundStyle(KitchenTableTheme.onPhotoMuted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .islandPalette()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CookSessionExpandedBody(snapshot: snapshot, recipeID: recipeID)
                        .islandPalette()
                }
            } compactLeading: {
                CookSessionCompactLeading(snapshot: snapshot)
                    .islandPalette()
            } compactTrailing: {
                CookSessionCompactTrailing(snapshot: snapshot)
                    .islandPalette()
            } minimal: {
                CookSessionRing(snapshot: snapshot, diameter: 24)
                    .islandPalette()
            }
            .widgetURL(deepLink)
            .keylineTint(KitchenTableTheme.Night.brassNight)
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}

private extension View {
    /// The Dynamic Island is black in both appearances, so it always uses the night roles.
    func islandPalette() -> some View {
        environment(\.colorScheme, .dark)
    }
}

/// Reads whether the island is limited in width (iPhone Duo). Older systems always have the full island.
private struct IslandWidthReader<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        if #available(iOS 27.0, *) {
            LimitedWidthProbe(content: content)
        } else {
            content(false)
        }
    }
}

@available(iOS 27.0, *)
private struct LimitedWidthProbe<Content: View>: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var isLimited
    let content: (Bool) -> Content

    var body: some View {
        content(isLimited)
    }
}

private struct CookSessionCompactLeading: View {
    let snapshot: CookSessionSnapshot

    var body: some View {
        IslandWidthReader { limited in
            switch CookSessionIslandLayout.compact(for: snapshot, limitedWidth: limited).leading {
            case .ring:
                CookSessionRing(snapshot: snapshot, diameter: 28)
            case .stepLabel(let label):
                Text(label)
                    .font(KitchenTableTheme.uiLabel.monospacedDigit())
                    .foregroundStyle(KitchenTableTheme.brass)
                    .lineLimit(1)
                    .accessibilityLabel(CookSessionIslandLayout.accessibilityLabel(for: snapshot))
                    .accessibilityIdentifier("cookSession.liveActivity.step")
            }
        }
    }
}

private struct CookSessionCompactTrailing: View {
    let snapshot: CookSessionSnapshot

    var body: some View {
        IslandWidthReader { limited in
            switch CookSessionIslandLayout.compact(for: snapshot, limitedWidth: limited).trailing {
            case .none:
                EmptyView()
            case .ring:
                CookSessionRing(snapshot: snapshot, diameter: 22, showsNumber: false)
            case .checkCount(let checked, let total):
                Label("\(checked)/\(total)", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(KitchenTableTheme.uiLabel.monospacedDigit())
                    .foregroundStyle(KitchenTableTheme.onPhoto)
                    .lineLimit(1)
                    .accessibilityLabel("\(checked) of \(total) checked")
            case .steps(let current, let total):
                Text("\(current)/\(total)")
                    .font(KitchenTableTheme.uiLabel.monospacedDigit())
                    .foregroundStyle(KitchenTableTheme.onPhoto)
                    .accessibilityLabel("Step \(current) of \(total)")
            }
        }
    }
}

/// The brass ring. It counts down the soonest running timer, holds still for a paused one, and shows step progress
/// when no timer is running.
struct CookSessionRing: View {
    let snapshot: CookSessionSnapshot
    let diameter: CGFloat
    var showsNumber = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(KitchenTableTheme.brass.opacity(0.28), lineWidth: lineWidth)
            ringProgress
            if showsNumber {
                Text(CookSessionIslandLayout.ringNumber(for: snapshot))
                    .font(KitchenTableTheme.runningHead.monospacedDigit())
                    .foregroundStyle(KitchenTableTheme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(lineWidth + 1)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CookSessionIslandLayout.accessibilityLabel(for: snapshot))
        .accessibilityIdentifier("cookSession.liveActivity.ring")
    }

    private var lineWidth: CGFloat {
        max(2.5, diameter / 10)
    }

    @ViewBuilder
    private var ringProgress: some View {
        switch CookSessionIslandLayout.ring(for: snapshot) {
        case .timer(let start, let end):
            // The system animates a timer-interval progress view, so the ring moves with no activity updates.
            ProgressView(timerInterval: start...max(start, end), countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(KitchenTableTheme.brass)
        case .fixed(let fraction):
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(KitchenTableTheme.brass, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// One step timer: its label and a countdown, or the frozen time while paused.
private struct CookSessionTimerChip: View {
    let timer: CookTimerEntry

    var body: some View {
        HStack(spacing: 4) {
            Text(timer.label)
                .font(KitchenTableTheme.runningHead)
                .foregroundStyle(KitchenTableTheme.ink2)
                .lineLimit(1)
            readout
                .font(KitchenTableTheme.uiLabel.monospacedDigit())
                .foregroundStyle(timer.isPaused ? KitchenTableTheme.ink2 : KitchenTableTheme.brass)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(KitchenTableTheme.vellum, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var readout: some View {
        if let remaining = timer.pausedRemaining {
            Text(CookSessionIslandLayout.pausedText(remaining: remaining))
        } else {
            Text(timerInterval: Date.now...max(Date.now, timer.endsAt), countsDown: true)
        }
    }
}

private struct CookSessionTimerRow: View {
    let timers: [CookTimerEntry]

    var body: some View {
        if !timers.isEmpty {
            HStack(spacing: 6) {
                ForEach(timers) { timer in
                    CookSessionTimerChip(timer: timer)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Check and Next. Both run without opening the app while cook mode is open.
private struct CookSessionButtons: View {
    let snapshot: CookSessionSnapshot
    let recipeID: String

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: CheckCurrentStepIntent(recipeID: recipeID)) {
                Label("Check", systemImage: "checkmark")
                    .font(KitchenTableTheme.uiLabel)
                    .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(KitchenTableTheme.ink)
            .background(KitchenTableTheme.vellum, in: Capsule())
            .accessibilityLabel("Check off step \(snapshot.stepNumber)")
            .accessibilityIdentifier("cookSession.liveActivity.check")

            if snapshot.nextStepTitle != nil {
                Button(intent: NextCookSessionStepIntent(recipeID: recipeID)) {
                    Label("Next", systemImage: "forward.fill")
                        .font(KitchenTableTheme.uiLabel)
                        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(KitchenTableTheme.onInk)
                .background(KitchenTableTheme.action, in: Capsule())
                .accessibilityLabel("Next step")
                .accessibilityIdentifier("cookSession.liveActivity.next")
            }
        }
    }
}

private struct CookSessionExpandedBody: View {
    let snapshot: CookSessionSnapshot
    let recipeID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.stepText)
                .font(KitchenTableTheme.meta)
                .foregroundStyle(KitchenTableTheme.onPhoto)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let next = snapshot.nextStepTitle {
                Text("Next: \(next)")
                    .font(KitchenTableTheme.runningHead)
                    .foregroundStyle(KitchenTableTheme.onPhotoMuted)
                    .lineLimit(1)
            }
            CookSessionTimerRow(timers: snapshot.timers)
            CookSessionButtons(snapshot: snapshot, recipeID: recipeID)
        }
        .padding(.horizontal, 4)
    }
}

/// The Lock Screen and StandBy card. It follows the system appearance. The small family (Apple Watch Smart Stack and
/// CarPlay) shows only the ring, the step and what comes next.
private struct CookSessionLockScreenView: View {
    @Environment(\.activityFamily) private var family
    let snapshot: CookSessionSnapshot
    let recipeID: String

    var body: some View {
        switch family {
        case .small:
            HStack(spacing: 8) {
                CookSessionRing(snapshot: snapshot, diameter: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.stepTitle)
                        .font(KitchenTableTheme.objectTitle)
                        .foregroundStyle(KitchenTableTheme.ink)
                        .lineLimit(1)
                    if let next = snapshot.nextStepTitle {
                        Text("Next: \(next)")
                            .font(KitchenTableTheme.runningHead)
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
        default:
            medium
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.recipeTitle)
                    .font(KitchenTableTheme.meta.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("Step \(snapshot.stepNumber) of \(snapshot.stepCount)")
                    .font(KitchenTableTheme.uiLabel.monospacedDigit())
                    .foregroundStyle(KitchenTableTheme.brass)
            }
            HStack(alignment: .top, spacing: 12) {
                CookSessionRing(snapshot: snapshot, diameter: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.stepTitle)
                        .font(KitchenTableTheme.indexTitle)
                        .foregroundStyle(KitchenTableTheme.ink)
                        .lineLimit(1)
                    Text(snapshot.stepText)
                        .font(KitchenTableTheme.meta)
                        .foregroundStyle(KitchenTableTheme.ink)
                        .lineLimit(2)
                    if let next = snapshot.nextStepTitle {
                        Text("Next: \(next)")
                            .font(KitchenTableTheme.runningHead)
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            CookSessionTimerRow(timers: snapshot.timers)
            CookSessionButtons(snapshot: snapshot, recipeID: recipeID)
        }
        .padding(14)
    }
}
