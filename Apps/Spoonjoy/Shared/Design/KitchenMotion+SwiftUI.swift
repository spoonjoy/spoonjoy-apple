import OuroHX
import SpoonjoyCore
import SwiftUI

extension KitchenSpring {
    /// The SwiftUI spring for this motion token.
    var animation: Animation {
        KitchenMotion.slowedForMotionChecks(.spring(response: response, dampingFraction: dampingFraction))
    }
}

extension KitchenMotionStep {
    var animation: Animation {
        switch self {
        case .spring(let spring): spring.animation
        // OuroHX's crossfade always animates (only its `.none` step does not), so the fallback never runs.
        case .crossfade(let duration):
            KitchenMotion.slowedForMotionChecks(OuroMotion.Step.crossfade(duration: duration).animation ?? .easeInOut(duration: duration))
        }
    }
}

extension KitchenMotion {
    /// `-SpoonjoySlowMotion <factor>` (DEBUG): every Kitchen spring and crossfade plays that many times slower, so a
    /// motion check sampling screenshots a few times a second sees each frame of a transition, however busy the machine.
    static let slowMotionFactor: Double = {
#if DEBUG
        max(UserDefaults.standard.double(forKey: "SpoonjoySlowMotion"), 1)
#else
        1
#endif
    }()

    static func slowedForMotionChecks(_ animation: Animation) -> Animation {
        slowMotionFactor > 1 ? animation.speed(1 / slowMotionFactor) : animation
    }

    /// The animation for a change: the spring, or the short crossfade under Reduce Motion.
    static func animation(_ spring: KitchenSpring, reduceMotion: Bool) -> Animation {
        step(spring, reduceMotion: reduceMotion).animation
    }

    /// The transition for content that enters or leaves. Under Reduce Motion any movement (slide, zoom, page turn)
    /// becomes a plain opacity crossfade.
    static func transition(_ motion: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        OuroMotion.transition(motion, reduceMotion: reduceMotion)
    }
}

extension KitchenHapticMoment {
    /// The SwiftUI `sensoryFeedback` value for this moment, from its OuroHX moment.
    var sensoryFeedback: SensoryFeedback {
        ouroMoment.sensoryFeedback
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
