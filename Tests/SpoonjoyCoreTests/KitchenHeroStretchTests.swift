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

@Suite("Kitchen top edge under the bar")
struct KitchenTopEdgeEffectTests {
    @Test("the photo meets the top cleanly at rest and while pulled, and the bar gets its edge once content scrolls under it")
    func topEdgeEffect() {
        #expect(KitchenHeroStretch.showsTopEdgeEffect(scrollOffset: 0) == false)
        #expect(KitchenHeroStretch.showsTopEdgeEffect(scrollOffset: -120) == false)
        #expect(KitchenHeroStretch.showsTopEdgeEffect(scrollOffset: 0.5) == false)
        #expect(KitchenHeroStretch.showsTopEdgeEffect(scrollOffset: 1.5) == true)
        #expect(KitchenHeroStretch.showsTopEdgeEffect(scrollOffset: 640) == true)
    }
}

@Suite("Recipe hero height")
struct RecipeHeroHeightTests {
    // A closed iPhone Duo held sideways is 466 pt tall. The 420 pt hero filled it, so the offline status and its
    // close button at the top of the recipe sheet started off the bottom of the screen.
    @Test("the hero keeps its height on a tall screen and takes half of a short one")
    func heroHeight() {
        #expect(KitchenHeroStretch.heroHeight(preferred: 420, viewportHeight: 956) == 420)
        // The closed Duo upright (678 pt) keeps the full photo.
        #expect(KitchenHeroStretch.heroHeight(preferred: 420, viewportHeight: 678) == 420)
        #expect(KitchenHeroStretch.heroHeight(preferred: 420, viewportHeight: 629) == 314.5)
        #expect(KitchenHeroStretch.heroHeight(preferred: 420, viewportHeight: 466) == 233)
        // Before the page has been measured, the preferred height stands.
        #expect(KitchenHeroStretch.heroHeight(preferred: 420, viewportHeight: 0) == 420)
    }
}
