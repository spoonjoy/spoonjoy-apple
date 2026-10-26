import Testing
@testable import SpoonjoyCore

@Suite("Kitchen hero stretch")
struct KitchenHeroStretchTests {
    @Test("pulling past the top measures the overscroll, and normal scrolling measures none")
    func pullDistance() {
        #expect(KitchenHeroStretch.pull(contentOffsetY: -130, topInset: 0) == 130)
        #expect(KitchenHeroStretch.pull(contentOffsetY: -150, topInset: 62) == 88)
        #expect(KitchenHeroStretch.pull(contentOffsetY: 240, topInset: 0) == 0)
    }

    @Test("the photo grows from its top edge by exactly the pull")
    func scaleMatchesPull() {
        let scale = KitchenHeroStretch.scale(pull: 108, heroHeight: 540, reduceMotion: false)
        #expect(scale == 1.2)
        #expect(540 * scale == 648)
        #expect(KitchenHeroStretch.scale(pull: 0, heroHeight: 540, reduceMotion: false) == 1)
        #expect(KitchenHeroStretch.scale(pull: -40, heroHeight: 540, reduceMotion: false) == 1)
    }

    @Test("Reduce Motion and an unmeasured hero never scale the photo")
    func noScale() {
        #expect(KitchenHeroStretch.scale(pull: 200, heroHeight: 540, reduceMotion: true) == 1)
        #expect(KitchenHeroStretch.scale(pull: 200, heroHeight: 0, reduceMotion: false) == 1)
    }
}

@Suite("Kitchen hero under Reduce Motion")
struct KitchenHeroStillPhotoTests {
    @Test("a still photo gets a dark fill exactly as tall as the pull, and a stretching photo needs none")
    func stillPhotoFill() {
        #expect(KitchenHeroStretch.stillPhotoFill(pull: 90, reduceMotion: true) == 90)
        #expect(KitchenHeroStretch.stillPhotoFill(pull: -20, reduceMotion: true) == 0)
        #expect(KitchenHeroStretch.stillPhotoFill(pull: 90, reduceMotion: false) == 0)
    }
}
