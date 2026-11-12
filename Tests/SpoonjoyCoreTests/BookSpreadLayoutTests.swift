import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Book spread layout")
struct BookSpreadLayoutTests {
    @Test("compact width always reads as one page")
    func compactWidthIsOnePage() {
        let layout = BookSpreadLayout.resolve(width: 1133, height: 744, isRegularWidth: false)
        #expect(layout == .singlePage)
        #expect(!layout.isSpread)
        #expect(layout.leadingPage == nil)
        #expect(layout.trailingPage == nil)
        #expect(layout.gutter == nil)
        #expect(layout.source == nil)
    }

    @Test("a regular-width portrait screen reads as one page")
    func portraitIsOnePage() {
        #expect(BookSpreadLayout.resolve(width: 744, height: 1133, isRegularWidth: true) == .singlePage)
        // A tall screen wide enough for two pages reads as one unless the view allows a tall spread (the recipe does).
        #expect(BookSpreadLayout.resolve(width: 1032, height: 1376, isRegularWidth: true) == .singlePage)
    }

    @Test("a view that allows it opens a spread on the upright iPad, but not on the Duo held tall")
    func tallSpreadOnlyWhereAllowedAndWideEnough() throws {
        // The 13" iPad upright: the recipe opens across two pages instead of a narrow centred column.
        let layout = BookSpreadLayout.resolve(width: 1032, height: 1376, isRegularWidth: true, allowsTallSpread: true)
        #expect(layout.isSpread)
        #expect(try #require(layout.leadingPage).width == 516)
        #expect(layout.source == .screenMiddle)
        // The 11" iPad upright is wide enough too.
        #expect(BookSpreadLayout.resolve(width: 834, height: 1194, isRegularWidth: true, allowsTallSpread: true).isSpread)
        // The open Duo held tall (669 pt) and a narrow iPad window keep one page.
        #expect(BookSpreadLayout.resolve(width: 669, height: 951, isRegularWidth: true, allowsTallSpread: true) == .singlePage)
        #expect(BookSpreadLayout.resolve(width: 744, height: 1133, isRegularWidth: true, allowsTallSpread: true) == .singlePage)
        // Compact width never opens.
        #expect(BookSpreadLayout.resolve(width: 1032, height: 1376, isRegularWidth: false, allowsTallSpread: true) == .singlePage)
    }

    @Test("the cover keeps 220 pt on the Duo's page and grows with an iPad's page")
    func coverHeightFollowsThePage() {
        #expect(BookSpreadLayout.coverHeight(pageWidth: 475) == 220)
        #expect(BookSpreadLayout.coverHeight(pageWidth: 516) == 220)
        // A page of the 13" iPad's landscape spread: 620 pt of image, a little over 3:5.
        #expect(abs(BookSpreadLayout.coverHeight(pageWidth: 688) - 384.4) < 0.01)
        #expect(BookSpreadLayout.coverHeight(pageWidth: 1200) == 420)
    }

    @Test("a narrow landscape window reads as one page")
    func narrowLandscapeIsOnePage() {
        #expect(BookSpreadLayout.resolve(width: 880, height: 600, isRegularWidth: true) == .singlePage)
    }

    @Test("a wide landscape screen opens into two pages split down the middle")
    func wideLandscapeSplitsDownTheMiddle() throws {
        let layout = BookSpreadLayout.resolve(width: 1133, height: 744, isRegularWidth: true)
        #expect(layout.isSpread)
        let leading = try #require(layout.leadingPage)
        let trailing = try #require(layout.trailingPage)
        let gutter = try #require(layout.gutter)
        #expect(leading.minX == 0)
        #expect(leading.width == 566.5)
        #expect(gutter.minX == 566.5)
        #expect(gutter.width == 0)
        #expect(trailing.minX == 566.5)
        #expect(trailing.width == 566.5)
        #expect(trailing.maxX == 1133)
        #expect(layout.source == .screenMiddle)
    }

    @Test("exactly the minimum spread width opens into two pages")
    func minimumSpreadWidth() {
        #expect(BookSpreadLayout.resolve(width: BookSpreadLayout.minimumSpreadWidth, height: 700, isRegularWidth: true).isSpread)
        #expect(!BookSpreadLayout.resolve(width: BookSpreadLayout.minimumSpreadWidth - 1, height: 700, isRegularWidth: true).isSpread)
    }

    @Test("a hardware division puts the gutter exactly on the fold")
    func divisionPlacesGutterOnFold() throws {
        let division = SpreadDivision(minX: 500, width: 20)
        #expect(division.maxX == 520)
        let layout = BookSpreadLayout.resolve(width: 1020, height: 720, isRegularWidth: true, division: division)
        let leading = try #require(layout.leadingPage)
        let trailing = try #require(layout.trailingPage)
        #expect(leading == SpreadColumn(minX: 0, width: 500))
        #expect(layout.gutter == SpreadColumn(minX: 500, width: 20))
        #expect(trailing == SpreadColumn(minX: 520, width: 500))
        #expect(layout.source == .hardwareDivision)
    }

    @Test("a hardware division opens the spread even below the minimum spread width")
    func divisionOverridesMinimumWidth() {
        let layout = BookSpreadLayout.resolve(
            width: 860,
            height: 600,
            isRegularWidth: true,
            division: SpreadDivision(minX: 430, width: 0)
        )
        #expect(layout.isSpread)
    }

    @Test("a division that leaves a page too narrow, or misses the screen, falls back to one page")
    func unusableDivisionFallsBack() {
        #expect(BookSpreadLayout.resolve(width: 1020, height: 720, isRegularWidth: true, division: SpreadDivision(minX: 200, width: 0)) == .singlePage)
        #expect(BookSpreadLayout.resolve(width: 1020, height: 720, isRegularWidth: true, division: SpreadDivision(minX: 1100, width: 10)) == .singlePage)
        #expect(BookSpreadLayout.resolve(width: 1020, height: 720, isRegularWidth: false, division: SpreadDivision(minX: 510, width: 0)) == .singlePage)
    }

    @Test("pages keep wider margins toward the gutter so controls stay off the fold")
    func pageMarginsFavorTheGutter() {
        let leading = BookSpreadLayout.pageInsets(for: .leading)
        let trailing = BookSpreadLayout.pageInsets(for: .trailing)
        #expect(leading.outer == BookSpreadLayout.outerMargin)
        #expect(leading.inner == BookSpreadLayout.innerMargin)
        #expect(leading.leading == BookSpreadLayout.outerMargin)
        #expect(leading.trailing == BookSpreadLayout.innerMargin)
        #expect(trailing.leading == BookSpreadLayout.innerMargin)
        #expect(trailing.trailing == BookSpreadLayout.outerMargin)
        #expect(BookSpreadLayout.innerMargin > BookSpreadLayout.outerMargin)
        // Apple's foldable guidance: keep tap targets well clear of the hinge.
        #expect(BookSpreadLayout.innerMargin >= 36)
    }

    @Test("the library sidebar steps aside only for a recipe spread")
    func sidebarStepsAsideForRecipeSpread() {
        let spread = BookSpreadLayout.resolve(width: 1133, height: 744, isRegularWidth: true)
        let single = BookSpreadLayout.resolve(width: 744, height: 1133, isRegularWidth: true)
        let recipe = AppRoute.recipeDetail(id: "pasta", presentation: .detail)
        #expect(BookSpreadLayout.hidesLibrarySidebar(route: recipe, windowLayout: spread))
        #expect(!BookSpreadLayout.hidesLibrarySidebar(route: recipe, windowLayout: single))
        for route: AppRoute in [.kitchen, .recipes, .cookbooks, .cookbookDetail(id: "weeknights"), .shoppingList, .recipeEditor(id: "pasta"), .recipeDetail(id: "pasta", presentation: .cook)] {
            #expect(!BookSpreadLayout.hidesLibrarySidebar(route: route, windowLayout: spread))
        }
    }

    @Test("a vertical division rect becomes a gutter band")
    func divisionFromVerticalFold() throws {
        let division = try #require(SpreadDivision(
            frameMinX: 500, frameWidth: 24, frameHeight: 720, containerWidth: 1020, containerHeight: 720
        ))
        #expect(division == SpreadDivision(minX: 500, width: 24))
        let layout = BookSpreadLayout.resolve(width: 1020, height: 720, isRegularWidth: true, division: division)
        #expect(layout.source == .hardwareDivision)
        #expect(layout.gutter == SpreadColumn(minX: 500, width: 24))
    }

    @Test("a division rect is clamped to the container")
    func divisionIsClamped() throws {
        let left = try #require(SpreadDivision(
            frameMinX: -10, frameWidth: 30, frameHeight: 720, containerWidth: 1020, containerHeight: 720
        ))
        #expect(left == SpreadDivision(minX: 0, width: 20))
        let right = try #require(SpreadDivision(
            frameMinX: 1000, frameWidth: 40, frameHeight: 720, containerWidth: 1020, containerHeight: 720
        ))
        #expect(right == SpreadDivision(minX: 1000, width: 20))
    }

    @Test("a division rect that is not a vertical fold is ignored")
    func divisionRejectsOtherShapes() {
        // No width, or as wide as the container.
        #expect(SpreadDivision(frameMinX: 500, frameWidth: 0, frameHeight: 720, containerWidth: 1020, containerHeight: 720) == nil)
        #expect(SpreadDivision(frameMinX: 0, frameWidth: 1020, frameHeight: 720, containerWidth: 1020, containerHeight: 720) == nil)
        // Shorter than half the container, or wider than tall.
        #expect(SpreadDivision(frameMinX: 500, frameWidth: 24, frameHeight: 300, containerWidth: 1020, containerHeight: 720) == nil)
        #expect(SpreadDivision(frameMinX: 100, frameWidth: 400, frameHeight: 360, containerWidth: 1020, containerHeight: 720) == nil)
        // Entirely outside the container.
        #expect(SpreadDivision(frameMinX: -50, frameWidth: 30, frameHeight: 720, containerWidth: 1020, containerHeight: 720) == nil)
        #expect(SpreadDivision(frameMinX: 1100, frameWidth: 30, frameHeight: 720, containerWidth: 1020, containerHeight: 720) == nil)
    }
}
