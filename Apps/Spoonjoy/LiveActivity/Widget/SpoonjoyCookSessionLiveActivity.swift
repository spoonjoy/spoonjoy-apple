import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Draws the cook session in the Dynamic Island, on the Lock Screen and in StandBy.
///
/// The Lock Screen follows the system appearance. The Dynamic Island is always black, so its views pin the dark
/// palette. On a limited-width island (iPhone Duo) the compact presentation is one brass ring with the step number
/// inside, as the HIG asks for limited-width presentations, sized to fit that island's narrow compact region.
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
                    CookSessionRing(snapshot: snapshot, diameter: 36)
                        .padding(.leading, 4)
                        .islandPalette()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CookSessionExpandedTrailing(snapshot: snapshot)
                        .padding(.trailing, 4)
                        .islandPalette()
                }
                DynamicIslandExpandedRegion(.center) {
                    CookSessionExpandedCenter(snapshot: snapshot)
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
                IslandWidthReader { limited in
                    CookSessionRing(snapshot: snapshot, diameter: CookSessionIslandLayout.minimalRingDiameter(limitedWidth: limited))
                }
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
                CookSessionRing(snapshot: snapshot, diameter: CookSessionIslandLayout.compactRingDiameter(limitedWidth: limited))
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

    var body: some View {
        ZStack {
            Circle()
                .stroke(KitchenTableTheme.brass.opacity(0.28), lineWidth: lineWidth)
            ringProgress
            Text(CookSessionIslandLayout.ringNumber(for: snapshot))
                .font(KitchenTableTheme.runningHead.monospacedDigit())
                .foregroundStyle(KitchenTableTheme.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(lineWidth + 1)
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
    /// In the single-column fallback the chip takes the row's width and a name too long for it ends in "…", so the
    /// countdown always shows whole.
    var fillsRow = false

    var body: some View {
        HStack(spacing: 4) {
            // The readout names the timer for VoiceOver, so the visible name is not read twice.
            Text(timer.label)
                .font(KitchenTableTheme.runningHead)
                .foregroundStyle(KitchenTableTheme.ink2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: fillsRow ? .infinity : nil, alignment: .leading)
                .accessibilityHidden(true)
            CookSessionTimerTime(timer: timer)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(KitchenTableTheme.vellum, in: Capsule())
    }
}

/// A timer's time. A system countdown asks for as much width as it is offered, so this sizes to the timer's whole
/// length and lays the countdown over it. "2:14:23" is never cut to "2:14:…", and the time never grows past it.
private struct CookSessionTimerTime: View {
    let timer: CookTimerEntry

    var body: some View {
        HStack(spacing: 2) {
            if timer.isPaused {
                Image(systemName: "pause.fill").imageScale(.small)
            }
            Text(CookSessionIslandLayout.clockText(remaining: max(timer.duration, timer.pausedRemaining ?? 0)))
        }
            .hidden()
            .accessibilityHidden(true)
            .overlay(alignment: .trailing) {
                CookSessionTimerReadout(timer: timer)
            }
            .font(KitchenTableTheme.uiLabel.monospacedDigit())
            .foregroundStyle(timer.isPaused ? KitchenTableTheme.ink2 : KitchenTableTheme.brass)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .fixedSize()
            .layoutPriority(1)
    }
}

/// A countdown the system advances, the frozen time with a pause mark, or Done once the countdown has run out.
/// VoiceOver hears the timer's name as the label and the time as the value.
private struct CookSessionTimerReadout: View {
    let timer: CookTimerEntry

    var body: some View {
        let readout = CookSessionIslandLayout.readout(for: timer, now: .now)
        readoutView(readout)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CookSessionIslandLayout.timerAccessibilityLabel(for: timer))
            .accessibilityValue(accessibilityValue(readout))
            .accessibilityIdentifier("cookSession.liveActivity.timer")
    }

    @ViewBuilder
    private func readoutView(_ readout: CookSessionIslandLayout.Readout) -> some View {
        switch readout {
        case .countdown(let end):
            Text(timerInterval: Date.now...max(Date.now, end), countsDown: true)
                .multilineTextAlignment(.trailing)
        case .paused(let remaining):
            HStack(spacing: 2) {
                Image(systemName: "pause.fill").imageScale(.small)
                Text(CookSessionIslandLayout.clockText(remaining: remaining))
            }
        case .done:
            Text(CookSessionIslandLayout.doneText)
        }
    }

    private func accessibilityValue(_ readout: CookSessionIslandLayout.Readout) -> Text {
        switch readout {
        case .countdown(let end):
            Text(timerInterval: Date.now...max(Date.now, end), countsDown: true)
        case .paused(let remaining):
            Text(CookSessionIslandLayout.pausedText(remaining: remaining))
        case .done:
            Text(CookSessionIslandLayout.doneText)
        }
    }
}

/// The timers as named chips, soonest first, one row when every name fits whole. Otherwise it depends on the room:
/// at standard text sizes the chips wrap two to a row and the names end in "…" (the Lock Screen gives up the step
/// text for the second row); at accessibility sizes the card grows, so the chips wrap two to a row, then one to a row
/// at the full width. In the island (`inIsland`) only the soonest timer shows, with a count of the rest and when the
/// next one ends. Timers past the payload's cap show as "+N" after the last chip. Only the last option can shrink, so
/// no layout widens the card or island past the screen.
private struct CookSessionTimerRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let timers: [CookTimerEntry]
    /// Every timer in the session, including those past the cap (`CookSessionIslandLayout.totalTimerCount`).
    let total: Int
    var inIsland = false

    var body: some View {
        // The app sends at most `maxTimers`; capping here too means a fourth chip can never push a third row past the
        // Lock Screen card's height.
        let timers = Array(CookSessionIslandLayout.timersBySoonest(self.timers).prefix(CookSessionSnapshot.maxTimers))
        let hidden = max(0, total - timers.count)
        if !timers.isEmpty {
            ViewThatFits(in: .horizontal) {
                chipRow(timers, hidden: hidden)
                if inIsland {
                    soonestTimer(timers)
                } else if typeSize.isAccessibilitySize {
                    let rows = CookSessionIslandLayout.wrappedTimerRows(timers)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            chipRow(row, hidden: index == rows.count - 1 ? hidden : 0)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(timers.enumerated()), id: \.element.id) { index, timer in
                            HStack(spacing: 6) {
                                CookSessionTimerChip(timer: timer, fillsRow: true)
                                overflow(index == timers.count - 1 ? hidden : 0)
                            }
                        }
                    }
                } else {
                    let rows = CookSessionIslandLayout.wrappedTimerRows(timers)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: 6) {
                                ForEach(row) { timer in
                                    CookSessionTimerChip(timer: timer, fillsRow: true)
                                }
                                overflow(index == rows.count - 1 ? hidden : 0)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The soonest timer, then "+4 · 7:27": how many more run in the whole session and the next one's live time, which
    /// VoiceOver reads with its name.
    @ViewBuilder
    private func soonestTimer(_ timers: [CookTimerEntry]) -> some View {
        if let timer = timers.first {
            HStack(spacing: 6) {
                CookSessionTimerChip(timer: timer, fillsRow: true)
                HStack(spacing: 3) {
                    overflow(total - 1)
                    if timers.count > 1 {
                        Text("·")
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .accessibilityHidden(true)
                        CookSessionTimerTime(timer: timers[1])
                    }
                }
                .fixedSize()
            }
        }
    }

    /// "+2" for timers not shown, read as "2 more timers". Nothing when none are hidden.
    @ViewBuilder
    private func overflow(_ hidden: Int) -> some View {
        if let text = CookSessionIslandLayout.hiddenTimersText(hidden: hidden) {
            Text(text)
                .font(KitchenTableTheme.uiLabel.monospacedDigit())
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize()
                .accessibilityLabel(CookSessionIslandLayout.hiddenTimersAccessibilityLabel(hidden: hidden) ?? text)
        }
    }

    private func chipRow(_ row: [CookTimerEntry], hidden: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(row) { timer in
                CookSessionTimerChip(timer: timer)
                    .fixedSize()
            }
            overflow(hidden)
        }
    }
}

/// Check and Next. Both run without opening the app while cook mode is open.
private struct CookSessionButtons: View {
    let snapshot: CookSessionSnapshot
    let recipeID: String
    /// The expanded island is short, so its buttons are a little lower than the Lock Screen's.
    var height: CGFloat = KitchenTableTheme.minimumTouchTarget

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: CheckCurrentStepIntent(recipeID: recipeID)) {
                Label("Check", systemImage: "checkmark")
                    .font(KitchenTableTheme.uiLabel)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: height)
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
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: height)
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

/// Beside the step: where you are. The timers sit in the body below, each with its name.
private struct CookSessionExpandedTrailing: View {
    let snapshot: CookSessionSnapshot

    var body: some View {
        Text(CookSessionIslandLayout.expandedStepCount(for: snapshot))
            .font(KitchenTableTheme.uiLabel.monospacedDigit())
            .foregroundStyle(KitchenTableTheme.brass)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// The step's title and text. At accessibility text sizes the island can't hold the text as well as the timer and
/// buttons, so the text gives way.
private struct CookSessionExpandedCenter: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let snapshot: CookSessionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.stepTitle)
                .font(KitchenTableTheme.objectTitle)
                .foregroundStyle(KitchenTableTheme.onPhoto)
                .lineLimit(1)
            if !typeSize.isAccessibilitySize {
                Text(snapshot.stepText)
                    .font(KitchenTableTheme.meta)
                    .foregroundStyle(KitchenTableTheme.onPhoto)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The timers, "Next:" and the buttons. When "Next:" and the buttons can't share a row, the line goes and the buttons
/// take the width.
private struct CookSessionExpandedBody: View {
    let snapshot: CookSessionSnapshot
    let recipeID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CookSessionTimerRow(timers: snapshot.timers, total: CookSessionIslandLayout.totalTimerCount(in: snapshot), inIsland: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(snapshot.nextStepTitle.map { "Next: \($0)" } ?? "Last step")
                        .font(KitchenTableTheme.runningHead)
                        .foregroundStyle(KitchenTableTheme.onPhotoMuted)
                        .lineLimit(2)
                        // ViewThatFits measures ideal widths, so the line asks for 80 pt here instead of its whole text.
                        .frame(minWidth: 80, idealWidth: 80, maxWidth: .infinity, alignment: .leading)
                    CookSessionButtons(snapshot: snapshot, recipeID: recipeID, height: 36)
                        .fixedSize(horizontal: true, vertical: false)
                }
                CookSessionButtons(snapshot: snapshot, recipeID: recipeID, height: 36)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// The Lock Screen and StandBy card. It follows the system appearance. The small family (Apple Watch Smart Stack and
/// CarPlay) shows only the ring, the step and what comes next.
private struct CookSessionLockScreenView: View {
    @Environment(\.activityFamily) private var family
    @Environment(\.dynamicTypeSize) private var typeSize
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
            let timersTakeStepText = CookSessionIslandLayout.lockScreenTimersTakeStepText(
                timerCount: snapshot.timers.count,
                accessibilitySize: typeSize.isAccessibilitySize
            )
            HStack(alignment: timersTakeStepText ? .center : .top, spacing: 12) {
                CookSessionRing(snapshot: snapshot, diameter: timersTakeStepText ? 32 : 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.stepTitle)
                        .font(KitchenTableTheme.indexTitle)
                        .foregroundStyle(KitchenTableTheme.ink)
                        .lineLimit(1)
                    if !timersTakeStepText {
                        Text(snapshot.stepText)
                            .font(KitchenTableTheme.meta)
                            .foregroundStyle(KitchenTableTheme.ink)
                            .lineLimit(2)
                    }
                    if !timersTakeStepText, let next = snapshot.nextStepTitle {
                        Text("Next: \(next)")
                            .font(KitchenTableTheme.runningHead)
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            CookSessionTimerRow(timers: snapshot.timers, total: CookSessionIslandLayout.totalTimerCount(in: snapshot))
            CookSessionButtons(snapshot: snapshot, recipeID: recipeID)
        }
        .padding(14)
    }
}
