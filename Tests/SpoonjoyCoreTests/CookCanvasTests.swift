@testable import SpoonjoyCore
import XCTest

final class CookCanvasTests: XCTestCase {
    func testAPhonePageKeepsTheReferenceLayout() {
        // An iPhone 17 Pro's cook page, and the same phone held sideways.
        XCTAssertEqual(CookCanvas.page(width: 353, height: 640, isPad: false), .reference)
        XCTAssertEqual(CookCanvas.page(width: 800, height: 300, isPad: false), .reference)
    }

    func testEveryPageOfTheOpenDuoKeepsTheReferenceLayout() {
        // One page of the open Duo held sideways (951 x 669) is about 475 pt wide.
        XCTAssertEqual(CookCanvas.page(width: 475, height: 600, isPad: false), .reference)
        // Held upright, its single page is about 637 x 800 pt: as big as some iPad pages, but an iPhone never grows.
        XCTAssertEqual(CookCanvas.page(width: 637, height: 800, isPad: false), .reference)
    }

    func testAShortIPadPageKeepsTheReferenceLayout() {
        XCTAssertEqual(CookCanvas.page(width: 475, height: 600, isPad: true), .reference)
    }

    func testTheIPadMiniUprightGrowsButKeepsOneColumn() {
        let canvas = CookCanvas.page(width: 712, height: 1000, isPad: true)
        XCTAssertTrue(canvas.isLarge)
        XCTAssertFalse(canvas.setsChecklistBesideStep)
    }

    func testTheChecklistColumnIsAboutAThirdOfThePage() {
        XCTAssertEqual(CookCanvas.checklistWidth(pageWidth: 820), 300)
        XCTAssertEqual(CookCanvas.checklistWidth(pageWidth: 1000), 360)
        XCTAssertEqual(CookCanvas.checklistWidth(pageWidth: 1400), 380)
    }

    func testMarginsOpenWithThePage() {
        XCTAssertEqual(CookCanvas.reference.interpolate(20, 40), 20)
        XCTAssertEqual(CookCanvas(scale: 1.25, setsChecklistBesideStep: false).interpolate(20, 40), 30, accuracy: 0.001)
        XCTAssertEqual(CookCanvas(scale: 1.5, setsChecklistBesideStep: true).interpolate(20, 40), 40, accuracy: 0.001)
    }

    func testThe13InchIPadInPortraitSetsTheStepLargeBesideItsChecklist() {
        let canvas = CookCanvas.page(width: 990, height: 1200, isPad: true)
        XCTAssertEqual(canvas.scale, CookCanvas.maximumScale)
        XCTAssertTrue(canvas.setsChecklistBesideStep)
        XCTAssertEqual(canvas.typeSteps, CookCanvas.maximumTypeSteps)
    }

    func testAPageOfThe13InchIPadSpreadGrowsButStaysOneColumn() {
        // Each page of the 13" iPad's landscape spread is about 688 x 950 pt.
        let canvas = CookCanvas.page(width: 688, height: 950, isPad: true)
        XCTAssertEqual(canvas.scale, 950.0 / 700.0, accuracy: 0.001)
        XCTAssertFalse(canvas.setsChecklistBesideStep)
        XCTAssertEqual(canvas.typeSteps, 2)
    }

    func testTheShorterSideLimitsTheScale() {
        // Wide but short, as a Stage Manager window can be: the height decides.
        let canvas = CookCanvas.page(width: 1000, height: 770, isPad: true)
        XCTAssertEqual(canvas.scale, 1.1, accuracy: 0.001)
        XCTAssertTrue(canvas.setsChecklistBesideStep)
        // Shorter than the reference page, it keeps the checklist under the step.
        XCTAssertFalse(CookCanvas.page(width: 1000, height: 600, isPad: true).setsChecklistBesideStep)
    }

    func testAccessibilityTextSizesKeepTheReferenceLayout() {
        XCTAssertEqual(CookCanvas.page(width: 990, height: 1200, isPad: true, isAccessibilityTextSize: true), .reference)
    }

    func testAnEmptyPageKeepsTheReferenceLayout() {
        XCTAssertEqual(CookCanvas.page(width: 0, height: 0, isPad: true), .reference)
        XCTAssertEqual(CookCanvas.reference.typeSteps, 0)
        XCTAssertFalse(CookCanvas.reference.isLarge)
    }
}
