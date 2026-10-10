import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Masthead scroll fade")
struct MastheadScrollFadeTests {
    @Test("the masthead is fully shown at rest and while overscrolling down")
    func fullyShownAtRest() {
        #expect(MastheadScrollFade.opacity(scrolledDistance: 0) == 1)
        #expect(MastheadScrollFade.opacity(scrolledDistance: -40) == 1)
        #expect(MastheadScrollFade.opacity(scrolledDistance: .nan) == 1)
    }

    @Test("the masthead fades linearly and is gone once it has travelled the fade distance")
    func fadesLinearlyThenHides() {
        let distance = MastheadScrollFade.fadeDistance
        #expect(MastheadScrollFade.opacity(scrolledDistance: distance / 2) == 0.5)
        #expect(MastheadScrollFade.opacity(scrolledDistance: distance) == 0)
        #expect(MastheadScrollFade.opacity(scrolledDistance: distance * 4) == 0)
        #expect(MastheadScrollFade.opacity(scrolledDistance: .infinity) == 0)
    }
}
