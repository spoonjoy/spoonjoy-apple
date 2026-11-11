@testable import SpoonjoyCore
import XCTest

final class CookCanvasTests: XCTestCase {
    func testAPhonePageKeepsTheReferenceLayout() {
        // An iPhone 17 Pro's cook page, and the same phone held sideways.
        XCTAssertEqual(CookCanvas.page(width: 353, height: 640), .reference)
        XCTAssertEqual(CookCanvas.page(width: 800, height: 300), .reference)
    }

    func testAPageOfTheOpenDuoKeepsTheReferenceLayout() {
        // One page of the open Duo held sideways (951 x 669) is about 475 pt wide.
        XCTAssertEqual(CookCanvas.page(width: 475, height: 600), .reference)
    }

    func testThe13InchIPadInPortraitSetsTheStepLargeBesideItsChecklist() {
        let canvas = CookCanvas.page(width: 990, height: 1200)
        XCTAssertEqual(canvas.scale, CookCanvas.maximumScale)
        XCTAssertTrue(canvas.setsChecklistBesideStep)
        XCTAssertEqual(canvas.typeSteps, CookCanvas.maximumTypeSteps)
    }

    func testAPageOfThe13InchIPadSpreadGrowsButStaysOneColumn() {
        // Each page of the 13" iPad's landscape spread is about 688 x 950 pt.
        let canvas = CookCanvas.page(width: 688, height: 950)
        XCTAssertEqual(canvas.scale, 950.0 / 700.0, accuracy: 0.001)
        XCTAssertFalse(canvas.setsChecklistBesideStep)
        XCTAssertEqual(canvas.typeSteps, 2)
    }

    func testTheShorterSideLimitsTheScale() {
        // Wide but short, as a Stage Manager window can be: the height decides.
        let canvas = CookCanvas.page(width: 1000, height: 770)
        XCTAssertEqual(canvas.scale, 1.1, accuracy: 0.001)
        XCTAssertTrue(canvas.setsChecklistBesideStep)
        // Shorter than the reference page, it keeps the checklist under the step.
        XCTAssertFalse(CookCanvas.page(width: 1000, height: 600).setsChecklistBesideStep)
    }

    func testAccessibilityTextSizesKeepTheReferenceLayout() {
        XCTAssertEqual(CookCanvas.page(width: 990, height: 1200, isAccessibilityTextSize: true), .reference)
    }

    func testAnEmptyPageKeepsTheReferenceLayout() {
        XCTAssertEqual(CookCanvas.page(width: 0, height: 0), .reference)
        XCTAssertEqual(CookCanvas.reference.typeSteps, 0)
        XCTAssertFalse(CookCanvas.reference.isLarge)
    }
}
