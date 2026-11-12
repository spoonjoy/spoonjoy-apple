@testable import SpoonjoyCore
import SwiftUI
import Testing

@Suite("Cook canvas")
struct CookCanvasTests {
    @Test func testAPhonePageKeepsTheReferenceLayout() {
        // An iPhone 17 Pro's cook page, and the same phone held sideways.
        #expect(CookCanvas.page(width: 353, height: 640, isPad: false) == .reference)
        #expect(CookCanvas.page(width: 800, height: 300, isPad: false) == .reference)
    }

    @Test func testEveryPageOfTheOpenDuoKeepsTheReferenceLayout() {
        // One page of the open Duo held sideways (951 x 669) is about 475 pt wide.
        #expect(CookCanvas.page(width: 475, height: 600, isPad: false) == .reference)
        // Held upright, its single page is about 637 x 800 pt: as big as some iPad pages, but an iPhone never grows.
        #expect(CookCanvas.page(width: 637, height: 800, isPad: false) == .reference)
    }

    @Test func testAShortIPadPageKeepsTheReferenceLayout() {
        #expect(CookCanvas.page(width: 475, height: 600, isPad: true) == .reference)
    }

    @Test func testTheIPadMiniUprightGrowsButKeepsOneColumn() {
        let canvas = CookCanvas.page(width: 712, height: 1000, isPad: true)
        #expect(canvas.isLarge)
        #expect(!(canvas.setsChecklistBesideStep))
    }

    @Test func testTheChecklistColumnIsAboutAThirdOfThePage() {
        #expect(CookCanvas.checklistWidth(pageWidth: 820) == 300)
        #expect(CookCanvas.checklistWidth(pageWidth: 1000) == 360)
        #expect(CookCanvas.checklistWidth(pageWidth: 1400) == 380)
    }

    @Test func testMarginsOpenWithThePage() {
        #expect(CookCanvas.reference.interpolate(20, 40) == 20)
        #expect(abs((CookCanvas(scale: 1.25, setsChecklistBesideStep: false).interpolate(20, 40)) - (30)) <= 0.001)
        #expect(abs((CookCanvas(scale: 1.5, setsChecklistBesideStep: true).interpolate(20, 40)) - (40)) <= 0.001)
    }

    @Test func testThe13InchIPadInPortraitSetsTheStepLargeBesideItsChecklist() {
        let canvas = CookCanvas.page(width: 990, height: 1200, isPad: true)
        #expect(canvas.scale == CookCanvas.maximumScale)
        #expect(canvas.setsChecklistBesideStep)
        #expect(canvas.typeSteps == CookCanvas.maximumTypeSteps)
    }

    @Test func testAPageOfThe13InchIPadSpreadGrowsButStaysOneColumn() {
        // Each page of the 13" iPad's landscape spread is about 688 x 950 pt.
        let canvas = CookCanvas.page(width: 688, height: 950, isPad: true)
        #expect(abs((canvas.scale) - (950.0 / 700.0)) <= 0.001)
        #expect(!(canvas.setsChecklistBesideStep))
        #expect(canvas.typeSteps == 2)
    }

    @Test func testTheShorterSideLimitsTheScale() {
        // Wide but short, as a Stage Manager window can be: the height decides.
        let canvas = CookCanvas.page(width: 1000, height: 770, isPad: true)
        #expect(abs((canvas.scale) - (1.1)) <= 0.001)
        #expect(canvas.setsChecklistBesideStep)
        // Shorter than the reference page, it keeps the checklist under the step.
        #expect(!(CookCanvas.page(width: 1000, height: 600, isPad: true).setsChecklistBesideStep))
    }

    @Test func testAccessibilityTextSizesKeepTheReferenceLayout() {
        #expect(CookCanvas.page(width: 990, height: 1200, isPad: true, isAccessibilityTextSize: true) == .reference)
    }

    @Test func testAnEmptyPageKeepsTheReferenceLayout() {
        #expect(CookCanvas.page(width: 0, height: 0, isPad: true) == .reference)
        #expect(CookCanvas.reference.typeSteps == 0)
        #expect(!(CookCanvas.reference.isLarge))
    }
}

@Suite("Kitchen type scaled for a large canvas")
struct KitchenTypeScaledTests {
    @Test func aScaleOfOneIsTheRolesOwnFont() {
        #expect(KitchenTypeRole.cookStep.font(scaledBy: 1) == KitchenTypeRole.cookStep.font)
    }

    @Test func aLargerScaleSetsALargerFont() {
        #expect(KitchenTypeRole.cookStep.font(scaledBy: 1.5) != KitchenTypeRole.cookStep.font)
        #expect(KitchenTypeRole.cookStep.font(scaledBy: 1.5) == KitchenTypeRole.cookStep.font(scaledBy: 1.5))
    }
}
