import Testing
@testable import SpoonjoyCore

@Suite("Kitchen motion")
struct KitchenMotionTests {
    @Test("reduced motion turns every spring into the same short crossfade")
    func reducedMotionCrossfades() {
        for spring in [KitchenSpring.snappy, .glide, .pageTurn, .zoom, .bounce] {
            #expect(KitchenMotion.step(spring, reduceMotion: true) == .crossfade(duration: 0.2))
        }
        #expect(KitchenMotion.reducedMotionCrossfadeDuration == 0.2)
        #expect(KitchenMotion.crossfades(reduceMotion: true))
    }

    @Test("with motion on, the spring passes through unchanged and nothing crossfades")
    func motionOnKeepsSpring() {
        #expect(KitchenMotion.step(.pageTurn, reduceMotion: false) == .spring(.pageTurn))
        #expect(!KitchenMotion.crossfades(reduceMotion: false))
    }

    @Test("the named springs carry the design system's values")
    func namedSpringValues() {
        #expect(KitchenSpring.snappy == KitchenSpring(response: 0.32, dampingFraction: 0.86))
        #expect(KitchenSpring.glide == KitchenSpring(response: 0.42, dampingFraction: 0.82))
        #expect(KitchenSpring.pageTurn == KitchenSpring(response: 0.5, dampingFraction: 0.88))
        #expect(KitchenSpring.zoom == KitchenSpring(response: 0.45, dampingFraction: 0.9))
        #expect(KitchenSpring.bounce == KitchenSpring(response: 0.35, dampingFraction: 0.6))
    }
}
