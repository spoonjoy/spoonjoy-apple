import SpoonjoyCore
import SwiftUI

/// One segment per step in cook mode's top bar: brass for the steps behind the cook, ink for the one on screen.
struct CookStepSegments: View {
    let count: Int
    let currentIndex: Int
    let completedIndexes: Set<Int>

    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 4

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Capsule()
                    .fill(fill(for: index))
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: 360)
        .kitchenAnimation(.snappy, value: currentIndex)
        .accessibilityElement()
        .accessibilityLabel("Step \(min(currentIndex + 1, count)) of \(count)")
        .accessibilityValue("\(completedIndexes.count) done")
        .accessibilityIdentifier("cook.segments")
    }

    private func fill(for index: Int) -> Color {
        if index == currentIndex {
            return KitchenTableTheme.ink
        }
        if completedIndexes.contains(index) || index < currentIndex {
            return KitchenTableTheme.brass
        }
        return KitchenTableTheme.hairline
    }
}

/// An ingredient row in cook mode's step card: the whole 60 pt row is the target, the tick bounces in and the name is
/// struck through. Reduce Motion shows the tick and strike at once.
struct CookIngredientCheckStyle: ToggleStyle {
    static let rowHeight: CGFloat = 60

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                KitchenCheckMark(isChecked: configuration.isOn)
                    .font(.title2)
                    .imageScale(.large)
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : configuration.isOn)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: KitchenTableTheme.minimumTouchTarget)

                configuration.label
                    .strikethrough(configuration.isOn, color: KitchenTableTheme.ink2)
                    .opacity(configuration.isOn ? 0.62 : 1)
            }
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
            .kitchenAnimation(.bounce, value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "checked" : "unchecked")
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

extension ToggleStyle where Self == CookIngredientCheckStyle {
    static var cookIngredient: CookIngredientCheckStyle {
        CookIngredientCheckStyle()
    }
}

/// The other steps' running timers, soonest first, as a compact stack above the step card. At most three show; the
/// rest are counted.
struct CookTimerStack: View {
    static let visibleLimit = 3

    let timers: [CookTimerEntry]

    var body: some View {
        if !timers.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    chips
                }
                VStack(alignment: .leading, spacing: 8) {
                    chips
                }
            }
            .kitchenAnimation(.snappy, value: timers.map(\.id))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cook.timer.stack")
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(timers.prefix(Self.visibleLimit)) { timer in
            CookTimerChip(timer: timer)
                .kitchenTransition(.scale(scale: 0.7).combined(with: .opacity))
        }
        if timers.count > Self.visibleLimit {
            Text("+\(timers.count - Self.visibleLimit)")
                .font(KitchenTableTheme.control)
                .foregroundStyle(KitchenTableTheme.ink2)
                .padding(.horizontal, 12)
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .glassEffect(.regular, in: Capsule())
                .accessibilityLabel("\(timers.count - Self.visibleLimit) more timers")
        }
    }
}

private struct CookTimerChip: View {
    let timer: CookTimerEntry

    var body: some View {
        HStack(spacing: 6) {
            Text("Step \(timer.stepNumber)")
                .font(KitchenTableTheme.meta.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.brass)
            CookTimerDigits(timer: timer, font: KitchenTableTheme.control.monospacedDigit())
                .foregroundStyle(KitchenTableTheme.ink)
        }
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(timer.label) timer")
    }
}

/// A running timer's digits. They count down by themselves and roll as they change; a paused timer shows the time it
/// had left.
struct CookTimerDigits: View {
    let timer: CookTimerEntry
    let font: Font

    var body: some View {
        Group {
            if let remaining = timer.pausedRemaining {
                Text(Self.clock(remaining))
            } else {
                let now = Date()
                Text(timerInterval: min(now, timer.endsAt)...timer.endsAt, countsDown: true)
            }
        }
        .font(font)
        .monospacedDigit()
        .contentTransition(.numericText(countsDown: true))
    }

    static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let rest = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }
}

/// The step's one timer ring. Before it starts it shows the step's length in a faint track; running, a brass arc sweeps
/// in and shrinks as the time runs down. The ring never draws below 120 pt and grows with Dynamic Type until it fills
/// the page width.
struct CookTimerRingFace<Center: View>: View {
    static var minimumDiameter: CGFloat { 120 }
    /// The smallest a ring goes, on a page too short for even the usual smallest size.
    static var compactDiameter: CGFloat { 88 }

    let fraction: Double?
    /// False for an arc laid over another face, which already draws the track.
    var drawsTrack = true
    @ViewBuilder let center: () -> Center

    @ScaledMetric(relativeTo: .largeTitle) private var diameter: CGFloat = 184
    @ScaledMetric(relativeTo: .largeTitle) private var lineWidth: CGFloat = 8
    /// The most room a page can give the ring, set where the ring would otherwise fall off a short page.
    @Environment(\.cookTimerRingLimit) private var ringLimit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far round the arc is drawn: it sweeps in from twelve o'clock when the ring starts running, as Clock's timer
    /// does, and unwinds back to twelve when it stops, rather than appearing or vanishing whole.
    @State private var arcDrawn = false
    /// The arc fades as it finishes unwinding, so it never ends as a dot at twelve o'clock.
    @State private var arcVisible = false
    /// The last time left while running, which the arc unwinds from once the ring stops.
    @State private var lastFraction: Double = 0

    /// The usual smallest size, or the compact size where a page asks for less.
    private var smallest: CGFloat {
        guard let ringLimit, ringLimit < Self.minimumDiameter else {
            return Self.minimumDiameter
        }
        return max(Self.compactDiameter, ringLimit)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(KitchenTableTheme.vellum, lineWidth: lineWidth)
                .opacity(drawsTrack ? 1 : 0)
            Circle()
                .trim(from: 0, to: arcDrawn ? max(0, min(1, fraction ?? lastFraction)) : 0)
                .stroke(KitchenTableTheme.brass, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(arcVisible ? 1 : 0)
                .kitchenAnimation(.glide, value: fraction)
                .onAppear {
                    // A ring built with its timer already running (a page turned back to, cook mode reopened) shows
                    // the arc where it is; only a timer starting or stopping on screen sweeps.
                    show(running: fraction != nil, animated: false)
                }
                .onChange(of: fraction != nil) { _, running in
                    show(running: running, animated: true)
                }
                .onChange(of: fraction) { _, value in
                    if let value {
                        lastFraction = value
                    }
                }
            center()
                .padding(lineWidth * 2)
        }
        .frame(minWidth: smallest, maxWidth: max(min(diameter, ringLimit ?? diameter), smallest))
        .aspectRatio(1, contentMode: .fit)
    }

    /// Sweeps the arc in when the ring starts running and unwinds it when it stops. Under Reduce Motion the arc simply
    /// appears or fades.
    private func show(running: Bool, animated: Bool) {
        if let fraction {
            lastFraction = fraction
        }
        guard running != (arcDrawn && arcVisible) else { return }
        guard animated else {
            var still = Transaction(animation: nil)
            still.disablesAnimations = true
            withTransaction(still) {
                arcDrawn = running
                arcVisible = running
            }
            return
        }
        if running {
            arcVisible = true
            withAnimation(reduceMotion ? nil : KitchenSpring.zoom.animation) {
                arcDrawn = true
            }
        } else if reduceMotion {
            withAnimation(KitchenMotion.slowedForMotionChecks(.easeOut(duration: 0.25))) {
                arcVisible = false
            } completion: {
                if !arcVisible {
                    arcDrawn = false
                }
            }
        } else {
            // A firm unwind for a "never mind", solid until it nears twelve, where it fades rather than leaving a dot.
            withAnimation(KitchenSpring.snappy.animation) {
                arcDrawn = false
            }
            withAnimation(KitchenMotion.slowedForMotionChecks(.easeIn(duration: 0.1).delay(0.1))) {
                arcVisible = false
            }
        }
    }
}

extension EnvironmentValues {
    /// The largest diameter a cook timer ring may take on this page; nil leaves the ring at its full size.
    @Entry var cookTimerRingLimit: CGFloat?
    /// Whether a cook timer shows its start hint under the ring; false where only the compact ring fits.
    @Entry var cookTimerShowsHint: Bool = true
}

extension DynamicTypeSize {
    /// `steps` sizes larger, for a big canvas that sets its text up to match its step: never past the largest standard
    /// size, and never smaller than the person's own setting, so an accessibility size is left as it is.
    func stepped(up steps: Int) -> DynamicTypeSize {
        let sizes = DynamicTypeSize.allCases
        guard steps > 0, self < .xxxLarge,
              let index = sizes.firstIndex(of: self),
              let ceiling = sizes.firstIndex(of: .xxxLarge)
        else {
            return self
        }
        return sizes[min(index + steps, ceiling)]
    }
}
