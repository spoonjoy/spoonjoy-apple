import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("A window saves the page it opened only when the save is safe")
struct OpenedPageRecorderTests {
    static let pastaCook = AppRoute.recipeDetail(id: "recipe_pasta", presentation: .cook)

    @Test("a link that launches the app waits for the window's name and for the saved snapshot")
    func linkBeforeSceneIDAndSnapshot() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.opened(.kitchen) == [])
        #expect(recorder.sceneIdentified("scene_a") == [.windowPage(.kitchen, sceneID: "scene_a")])
        #expect(recorder.snapshotLoaded() == [.appPage(.kitchen)])
    }

    @Test("a page opened once the window is named and the snapshot loaded saves at once, and only once")
    func sceneIDBeforeLink() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.sceneIdentified("scene_a") == [])
        #expect(recorder.snapshotLoaded() == [])
        #expect(recorder.opened(Self.pastaCook) == [.appPage(Self.pastaCook), .windowPage(Self.pastaCook, sceneID: "scene_a")])
        #expect(recorder.sceneIdentified("scene_a") == [])
        #expect(recorder.snapshotLoaded() == [])
    }

    @Test("a link before the saved snapshot loads keeps the chef's state until the snapshot is shown")
    func linkBeforeSnapshotLoad() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.sceneIdentified("scene_a") == [])
        #expect(recorder.opened(.kitchen) == [.windowPage(.kitchen, sceneID: "scene_a")])
        #expect(recorder.snapshotLoaded() == [.appPage(.kitchen)])
    }

    @Test("only the latest page opened while waiting is saved")
    func latestPageWins() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.opened(Self.pastaCook) == [])
        #expect(recorder.opened(.kitchen) == [])
        #expect(recorder.snapshotLoaded() == [.appPage(.kitchen)])
        #expect(recorder.sceneIdentified("scene_a") == [.windowPage(.kitchen, sceneID: "scene_a")])
    }

    @Test("a page a window never reopens on is saved for the app but never as the window's page")
    func unremembered() {
        var recorder = OpenedPageRecorder()
        #expect(recorder.opened(.settings) == [])
        #expect(recorder.sceneIdentified("scene_a") == [])
        #expect(recorder.snapshotLoaded() == [.appPage(.settings)])
        #expect(recorder.opened(.settings) == [.appPage(.settings)])
    }

    @Test("after a kill, the window a link moved to the Kitchen reopens on the Kitchen, not its older cook page")
    func killedAfterLinkReopensOnLinkedPage() {
        var book = SceneRouteBook()
        book.record(Self.pastaCook, scene: "scene_a", at: Date(timeIntervalSince1970: 1_793_000_000))

        // The link starts a new process: it arrives before the window is named.
        var recorder = OpenedPageRecorder()
        let saves = recorder.opened(.kitchen) + recorder.sceneIdentified("scene_a") + recorder.snapshotLoaded()
        let windowPages = saves.compactMap { save -> (AppRoute, String)? in
            guard case .windowPage(let route, let sceneID) = save else {
                return nil
            }
            return (route, sceneID)
        }
        #expect(windowPages.count == 1)
        let (route, sceneID) = windowPages[0]
        book.record(route, scene: sceneID, at: Date(timeIntervalSince1970: 1_793_000_060))

        let reopened = SceneRestoration.route(
            scenePage: book.route(forScene: "scene_a"),
            windowValue: nil,
            appLastRoute: Self.pastaCook,
            isOnlyWindow: false
        )
        #expect(reopened == .kitchen)
    }
}
