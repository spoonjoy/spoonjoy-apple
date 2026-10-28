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
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .imageScale(.large)
                    .foregroundStyle(configuration.isOn ? KitchenTableTheme.herb : KitchenTableTheme.brass)
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : configuration.isOn)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: KitchenTableTheme.minimumTouchTarget)
                    .accessibilityHidden(true)

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

    let fraction: Double?
    @ViewBuilder let center: () -> Center

    @ScaledMetric(relativeTo: .largeTitle) private var diameter: CGFloat = 184
    @ScaledMetric(relativeTo: .largeTitle) private var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(KitchenTableTheme.vellum, lineWidth: lineWidth)
            if let fraction {
                Circle()
                    .trim(from: 0, to: max(0, min(1, fraction)))
                    .stroke(KitchenTableTheme.brass, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .kitchenAnimation(.glide, value: fraction)
                    .kitchenTransition(.scale(scale: 0.7).combined(with: .opacity))
            }
            center()
                .padding(lineWidth * 2)
        }
        .frame(minWidth: Self.minimumDiameter, maxWidth: max(diameter, Self.minimumDiameter))
        .aspectRatio(1, contentMode: .fit)
    }
}
