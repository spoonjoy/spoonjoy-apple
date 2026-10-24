import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Tabletop layout")
struct TabletopLayoutTests {
    // The iPhone Duo's inner screen held tall, in points.
    private let width = 669.0
    private let height = 951.0

    @Test("a wide screen is a book, never a tabletop")
    func wideScreenIsOnePage() {
        let band = FoldBand(minY: 300, height: 0)
        #expect(TabletopLayout.resolve(width: 951, height: 669, hinge: .partiallyOpen, band: band) == .singlePage)
    }

    @Test("a closed foldable is an ordinary phone")
    func closedIsOnePage() {
        let band = FoldBand(minY: 475.5, height: 0)
        #expect(TabletopLayout.resolve(width: 466, height: 678, hinge: .closed, band: band) == .singlePage)
    }

    @Test("a tall screen with no fold information stays one page")
    func noFoldIsOnePage() {
        let layout = TabletopLayout.resolve(width: width, height: height, hinge: .unknown)
        #expect(layout == .singlePage)
        #expect(!layout.isSplit)
        #expect(layout.top == nil)
        #expect(layout.fold == nil)
        #expect(layout.bottom == nil)
        #expect(layout.source == nil)
        #expect(TabletopLayout.resolve(width: width, height: height, hinge: .fullyOpen) == .singlePage)
    }

    @Test("a reported fold splits the screen on it, with a margin each side")
    func hardwareFoldSplitsOnIt() throws {
        let layout = TabletopLayout.resolve(
            width: width,
            height: height,
            hinge: .fullyOpen,
            band: FoldBand(minY: 475.5, height: 0)
        )
        #expect(layout.isSplit)
        #expect(layout.source == .hardwareDivision)
        let top = try #require(layout.top)
        let fold = try #require(layout.fold)
        let bottom = try #require(layout.bottom)
        #expect(top.minY == 0)
        #expect(top.height == 475.5 - TabletopLayout.foldMargin)
        #expect(fold.minY == top.maxY)
        #expect(fold.height == TabletopLayout.foldMargin * 2)
        #expect(bottom.minY == fold.maxY)
        #expect(bottom.maxY == height)
    }

    @Test("half-open with no fold rect splits at the middle")
    func halfOpenSplitsAtTheMiddle() throws {
        let layout = TabletopLayout.resolve(width: width, height: height, hinge: .partiallyOpen)
        #expect(layout.source == .screenMiddle)
        let fold = try #require(layout.fold)
        #expect(fold.minY + fold.height / 2 == height / 2)
    }

    @Test("a fold too near an edge leaves one page")
    func foldNearTheEdgeIsOnePage() {
        let band = FoldBand(minY: 200, height: 0)
        #expect(TabletopLayout.resolve(width: width, height: height, hinge: .partiallyOpen, band: band) == .singlePage)
    }

    @Test("a division rect becomes a band only when it is a horizontal fold inside the container")
    func bandFromFrame() {
        #expect(
            FoldBand(frameMinY: 470, frameHeight: 10, frameWidth: 669, containerWidth: 669, containerHeight: 951)
                == FoldBand(minY: 470, height: 10)
        )
        // A seamless fold reports no height and is still a fold.
        #expect(
            FoldBand(frameMinY: 475.5, frameHeight: 0, frameWidth: 669, containerWidth: 669, containerHeight: 951)
                == FoldBand(minY: 475.5, height: 0)
        )
        // Clamped to the container.
        #expect(
            FoldBand(frameMinY: 470, frameHeight: 10, frameWidth: 700, containerWidth: 669, containerHeight: 951)?.maxY
                == 480
        )
        // A vertical fold is a SpreadDivision, not a band.
        #expect(FoldBand(frameMinY: 0, frameHeight: 669, frameWidth: 10, containerWidth: 951, containerHeight: 669) == nil)
        // A rect narrower than half the container is not a fold across it.
        #expect(FoldBand(frameMinY: 470, frameHeight: 4, frameWidth: 200, containerWidth: 669, containerHeight: 951) == nil)
        // A fold at or outside the container's edge does not cross it.
        #expect(FoldBand(frameMinY: -10, frameHeight: 4, frameWidth: 669, containerWidth: 669, containerHeight: 951) == nil)
        #expect(FoldBand(frameMinY: 951, frameHeight: 4, frameWidth: 669, containerWidth: 669, containerHeight: 951) == nil)
        #expect(FoldBand(frameMinY: 0, frameHeight: 951, frameWidth: 1000, containerWidth: 669, containerHeight: 951) == nil)
        #expect(FoldBand(frameMinY: 470, frameHeight: -1, frameWidth: 669, containerWidth: 669, containerHeight: 951) == nil)
    }
}
