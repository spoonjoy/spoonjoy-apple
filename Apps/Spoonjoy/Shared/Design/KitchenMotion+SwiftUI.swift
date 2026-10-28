import SpoonjoyCore
import SwiftUI

extension KitchenSpring {
    /// The SwiftUI spring for this motion token.
    var animation: Animation {
        .spring(response: response, dampingFraction: dampingFraction)
    }
}

extension KitchenMotionStep {
    var animation: Animation {
        switch self {
        case .spring(let spring): spring.animation
        case .crossfade(let duration): .easeInOut(duration: duration)
        }
    }
}

extension KitchenMotion {
    /// The animation for a change: the spring, or the short crossfade under Reduce Motion.
    static func animation(_ spring: KitchenSpring, reduceMotion: Bool) -> Animation {
        step(spring, reduceMotion: reduceMotion).animation
    }

    /// The transition for content that enters or leaves. Under Reduce Motion any movement (slide, zoom, page turn)
    /// becomes a plain opacity crossfade.
    static func transition(_ motion: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        crossfades(reduceMotion: reduceMotion) ? .opacity : motion
    }
}

extension KitchenHapticKind {
    /// The SwiftUI `sensoryFeedback` value for this haptic.
    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .selection: .selection
        case .impactLight: .impact(weight: .light)
        case .impactMedium: .impact(weight: .medium)
        case .success: .success
        case .warning: .warning
        }
    }
}

extension KitchenHapticMoment {
    var sensoryFeedback: SensoryFeedback {
        feedback.sensoryFeedback
    }
}

private struct KitchenAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let spring: KitchenSpring
    let value: Value

    func body(content: Content) -> some View {
        content.animation(KitchenMotion.animation(spring, reduceMotion: reduceMotion), value: value)
    }
}

private struct KitchenTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let motion: AnyTransition

    func body(content: Content) -> some View {
        content.transition(KitchenMotion.transition(motion, reduceMotion: reduceMotion))
    }
}

extension View {
    /// Animates changes to `value` on a Kitchen spring, or with the short crossfade under Reduce Motion. Use it for
    /// changes that don't move things (colour, opacity, a numeric text change); for movement, pair the change with
    /// `kitchenTransition` so Reduce Motion swaps the movement for a crossfade.
    func kitchenAnimation<Value: Equatable>(_ spring: KitchenSpring, value: Value) -> some View {
        modifier(KitchenAnimationModifier(spring: spring, value: value))
    }

    /// Inserts and removes this view with `motion` (a slide, zoom or page turn), or with an opacity crossfade under
    /// Reduce Motion. Drive the change with `withAnimation(KitchenMotion.animation(_:reduceMotion:))`.
    func kitchenTransition(_ motion: AnyTransition) -> some View {
        modifier(KitchenTransitionModifier(motion: motion))
    }

    /// Plays the haptic for a Kitchen moment each time `trigger` changes.
    func kitchenHaptic<Trigger: Equatable>(_ moment: KitchenHapticMoment, trigger: Trigger) -> some View {
        sensoryFeedback(moment.sensoryFeedback, trigger: trigger)
    }

    /// Plays the haptic for a Kitchen moment when `trigger` changes and `condition` holds for the change, for a
    /// moment that happens only one way (a timer starting, the last step finishing).
    func kitchenHaptic<Trigger: Equatable>(
        _ moment: KitchenHapticMoment,
        trigger: Trigger,
        condition: @escaping (Trigger, Trigger) -> Bool
    ) -> some View {
        sensoryFeedback(moment.sensoryFeedback, trigger: trigger, condition: condition)
    }
}
