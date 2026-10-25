import Testing
@testable import SpoonjoyCore

@Suite("Cook page turn")
struct CookPageTurnTests {
    @Test func turnCommitsPastAThird() {
        #expect(CookPageTurn.target(from: 1, count: 4, dragFraction: -0.34, velocity: 0) == 2)
        #expect(CookPageTurn.target(from: 1, count: 4, dragFraction: 0.34, velocity: 0) == 0)
    }

    @Test func turnStaysBelowAThird() {
        #expect(CookPageTurn.target(from: 1, count: 4, dragFraction: -0.2, velocity: 0) == 1)
        #expect(CookPageTurn.target(from: 1, count: 4, dragFraction: 0.2, velocity: 100) == 1)
    }

    @Test func turnClampsAtLastPage() {
        #expect(CookPageTurn.target(from: 3, count: 4, dragFraction: -0.9, velocity: -900) == 3)
    }

    @Test func turnClampsAtFirstPage() {
        #expect(CookPageTurn.target(from: 0, count: 4, dragFraction: 0.9, velocity: 900) == 0)
    }

    @Test func fastFlickCommits() {
        #expect(CookPageTurn.target(from: 1, count: 4, dragFraction: -0.1, velocity: -700) == 2)
        #expect(CookPageTurn.target(from: 1, count: 4, dragFraction: 0.1, velocity: 700) == 0)
    }

    @Test func emptyOrOutOfRangeIndexClamps() {
        #expect(CookPageTurn.target(from: 5, count: 0, dragFraction: 0, velocity: 0) == 0)
        #expect(CookPageTurn.target(from: 9, count: 4, dragFraction: 0, velocity: 0) == 3)
        #expect(CookPageTurn.target(from: -2, count: 4, dragFraction: 0, velocity: 0) == 0)
    }

    @Test func rubberBandIsMonotonicAndBounded() {
        #expect(CookPageTurn.rubberBand(offset: 1000, limit: 80) < 80)
        #expect(CookPageTurn.rubberBand(offset: 1000, limit: 80) > CookPageTurn.rubberBand(offset: 100, limit: 80))
    }

    @Test func rubberBandKeepsSignAndZero() {
        #expect(CookPageTurn.rubberBand(offset: -100, limit: 80) == -CookPageTurn.rubberBand(offset: 100, limit: 80))
        #expect(CookPageTurn.rubberBand(offset: 0, limit: 80) == 0)
        #expect(CookPageTurn.rubberBand(offset: 50, limit: 0) == 0)
    }
}
