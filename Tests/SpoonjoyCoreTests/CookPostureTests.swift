import Testing
@testable import SpoonjoyCore

@Suite("Cook posture")
struct CookPostureTests {
    @Test("a closed hinge is the cover glance, whatever the angle")
    func closedIsGlance() {
        #expect(TabletopLayout.posture(hingeStatus: .closed, angleDegrees: 0) == .closedGlance)
        #expect(TabletopLayout.posture(hingeStatus: .closed, angleDegrees: nil) == .closedGlance)
    }

    @Test("a screen with no hinge is one page")
    func noHingeIsSingle() {
        #expect(TabletopLayout.posture(hingeStatus: .unknown, angleDegrees: nil) == .single)
        #expect(TabletopLayout.posture(hingeStatus: .unknown, angleDegrees: 90) == .single)
    }

    @Test("bent between 60 and 140 degrees it stands up as a tabletop")
    func tabletopBand() {
        #expect(TabletopLayout.posture(hingeStatus: .partiallyOpen, angleDegrees: 90) == .tabletop)
        #expect(TabletopLayout.posture(hingeStatus: .partiallyOpen, angleDegrees: 60) == .tabletop)
        #expect(TabletopLayout.posture(hingeStatus: .partiallyOpen, angleDegrees: 140) == .tabletop)
        #expect(TabletopLayout.posture(hingeStatus: .fullyOpen, angleDegrees: 100) == .tabletop)
    }

    @Test("150 degrees or more lies open flat")
    func openFlatBand() {
        #expect(TabletopLayout.posture(hingeStatus: .fullyOpen, angleDegrees: 175) == .openFlat)
        #expect(TabletopLayout.posture(hingeStatus: .partiallyOpen, angleDegrees: 150) == .openFlat)
        #expect(TabletopLayout.posture(hingeStatus: .fullyOpen, angleDegrees: 180) == .openFlat)
    }

    @Test("too shallow a bend to stand on is one page")
    func shallowBendIsSingle() {
        #expect(TabletopLayout.posture(hingeStatus: .partiallyOpen, angleDegrees: 59.9) == .single)
    }

    @Test("between the bands, and with no angle, the reported status decides")
    func statusDecidesWithoutAnAngle() {
        #expect(TabletopLayout.posture(hingeStatus: .fullyOpen, angleDegrees: nil) == .openFlat)
        #expect(TabletopLayout.posture(hingeStatus: .partiallyOpen, angleDegrees: nil) == .tabletop)
        #expect(TabletopLayout.posture(hingeStatus: .partiallyOpen, angleDegrees: 145) == .tabletop)
        #expect(TabletopLayout.posture(hingeStatus: .fullyOpen, angleDegrees: 145) == .openFlat)
    }

    @Test("the spread's fold shadow is 24 points each side")
    func gutterShadowWidth() {
        #expect(BookSpreadLayout.gutterShadowWidth == 24)
    }
}
