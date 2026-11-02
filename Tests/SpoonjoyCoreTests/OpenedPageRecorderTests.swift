import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("A window saves the page it opened as its own once the system names the window")
struct OpenedPageRecorderTests {
    static let pastaCook = AppRoute.recipeDetail(id: "recipe_pasta", presentation: .cook)

    @Test("a link that launches the app waits for the window's name, then saves at once")
    func linkBeforeSceneID() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.opened(.kitchen) == nil)
        #expect(recorder.sceneIdentified("scene_a") == .init(route: .kitchen, sceneID: "scene_a"))
        // Saved once: naming the window again saves nothing more.
        #expect(recorder.sceneIdentified("scene_a") == nil)
    }

    @Test("a page opened once the window is named saves at once")
    func sceneIDBeforeLink() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.sceneIdentified("scene_a") == nil)
        #expect(recorder.opened(Self.pastaCook) == .init(route: Self.pastaCook, sceneID: "scene_a"))
    }

    @Test("only the latest page opened while waiting is saved")
    func latestPageWins() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.opened(Self.pastaCook) == nil)
        #expect(recorder.opened(.kitchen) == nil)
        #expect(recorder.sceneIdentified("scene_a") == .init(route: .kitchen, sceneID: "scene_a"))
    }

    @Test("a page a window never reopens on is never saved as the window's page")
    func unremembered() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.opened(.settings) == nil)
        #expect(recorder.sceneIdentified("scene_a") == nil)
        #expect(recorder.opened(.search(query: "basil", scope: .all)) == nil)
    }

    @Test("after a kill, the window a link moved to the Kitchen reopens on the Kitchen, not its older cook page")
    func killedAfterLinkReopensOnLinkedPage() throws {
        var book = SceneRouteBook()
        book.record(Self.pastaCook, scene: "scene_a", at: Date(timeIntervalSince1970: 1_793_000_000))

        // The link starts a new process: it arrives before the window is named.
        var recorder = OpenedPageRecorder()
        #expect(recorder.opened(.kitchen) == nil)
        let identified = recorder.sceneIdentified("scene_a")
        let page = try #require(identified)
        book.record(page.route, scene: page.sceneID, at: Date(timeIntervalSince1970: 1_793_000_060))

        let reopened = SceneRestoration.route(
            scenePage: book.route(forScene: "scene_a"),
            windowValue: nil,
            appLastRoute: Self.pastaCook,
            isOnlyWindow: false
        )
        #expect(reopened == .kitchen)
    }

    @Test("two windows killed together each reopen on their own recipe, mode and step page")
    func twoWindowsReopenOnTheirOwnPages() {
        var book = SceneRouteBook()
        var left = OpenedPageRecorder()
        var right = OpenedPageRecorder()
        let chickpeas = AppRoute.recipeDetail(id: "recipe_chickpeas", presentation: .detail)
        _ = left.sceneIdentified("left")
        _ = right.sceneIdentified("right")
        for page in [left.opened(Self.pastaCook), right.opened(chickpeas)].compactMap({ $0 }) {
            book.record(page.route, scene: page.sceneID, at: Date(timeIntervalSince1970: 1_793_000_000))
        }
        // Either window can come back first after a kill; neither is the app's only window.
        let reopenedLeft = SceneRestoration.route(scenePage: book.route(forScene: "left"), windowValue: nil, appLastRoute: chickpeas, isOnlyWindow: false)
        let reopenedRight = SceneRestoration.route(scenePage: book.route(forScene: "right"), windowValue: WindowRoute(.kitchen).route, appLastRoute: Self.pastaCook, isOnlyWindow: true)
        #expect(reopenedLeft == Self.pastaCook)
        #expect(reopenedRight == chickpeas)
    }
}
