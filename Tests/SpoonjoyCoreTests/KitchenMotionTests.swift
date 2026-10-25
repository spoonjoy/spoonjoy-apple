import Testing
@testable import SpoonjoyCore

@Suite("Kitchen motion")
struct KitchenMotionTests {
    @Test("reduced motion drops springs, so the caller crossfades")
    func reducedMotionDropsSprings() {
        #expect(KitchenMotion.spring(.glide, reduceMotion: true) == nil)
    }

    @Test("with motion on, the spring passes through unchanged")
    func motionOnKeepsSpring() {
        #expect(KitchenMotion.spring(.pageTurn, reduceMotion: false) == .pageTurn)
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
