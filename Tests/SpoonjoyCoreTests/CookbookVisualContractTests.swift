import Foundation
import Testing

@Suite("Cookbook visual contracts")
struct CookbookVisualContractTests {
    @Test("cookbook objects lead while native chrome owns creation and compact sharing")
    func cookbookObjectsLeadWhileNativeChromeOwnsCreationAndCompactSharing() throws {
        let path = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let source = try readCookbookRepoFile(path)
        let body = try cookbookSourceSlice(source, from: "var body: some View", to: "private var header")
        let header = try cookbookSourceSlice(source, from: "private var header", to: "private var leadCookbook")
        let spread = try cookbookSourceSlice(source, from: "private var cookbookLibrarySpread", to: "private func leadCookbookStory")
        let story = try cookbookSourceSlice(source, from: "private func leadCookbookStory", to: "private var cookbookShelfStrip")

        #expect(body.contains(".toolbar"))
        #expect(body.contains("ToolbarItem(placement: .primaryAction)"))
        #expect(body.contains("newCookbookButton"))
        #expect(body.firstRange(of: "header")?.lowerBound ?? body.endIndex < body.firstRange(of: "cookbookLibrarySpread")?.lowerBound ?? body.endIndex)
        #expect(!header.contains("isPresentingCreate = true"))
        #expect(spread.contains("leadCookbookCoverButton"))
        #expect(story.contains("Image(systemName: \"square.and.arrow.up\")"))
        #expect(!source.contains("openCookbookButton"))
        #expect(!source.contains("leadCookbookActions"))
        #expect(!source.contains("Label(\"Open cookbook\""))
    }

    @Test("cookbook thumbnails and text-only covers tell the truth without squeezed typography")
    func cookbookThumbnailsAndTextOnlyCoversTellTheTruthWithoutSqueezedTypography() throws {
        let path = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let source = try readCookbookRepoFile(path)
        let index = try cookbookSourceSlice(source, from: "private var cookbookIndexRows", to: "private func cookbookEmptyState")
        let thumb = try cookbookSourceSlice(source, from: "private struct CookbookThumb", to: "private struct CookbookCoverArt")
        let fallback = try cookbookSourceSlice(source, from: "private struct CookbookFallbackCover", to: "struct CookbookDetailRouteView")

        #expect(index.contains("CookbookThumb(row: row)"))
        #expect(thumb.contains("CookbookImageCover(imageURLs:"))
        #expect(thumb.contains("KitchenTableNoPhotoView("))
        #expect(!thumb.contains("Text("))
        #expect(!thumb.contains("books.vertical.fill"))
        #expect(fallback.contains("KitchenTableNoPhotoView("))
        #expect(fallback.contains("subtitle: \"Photo not added\""))
        #expect(!fallback.contains("books.vertical.fill"))
    }

    @Test("cookbooks reserve ordinary page breathing room instead of duplicating shell chrome")
    func cookbooksReserveOrdinaryPageBreathingRoomInsteadOfDuplicatingShellChrome() throws {
        let path = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let source = try readCookbookRepoFile(path)
        let reserve = try cookbookSourceSlice(source, from: "private var cookbookPageBottomReserve", to: "private var leadCoverWidth")

        #expect(reserve.contains("KitchenTableTheme.pageBottomSpacing"))
        #expect(!source.contains("KitchenTableTheme.compactDockReserve"))
    }
}

private enum CookbookVisualContractError: Error {
    case missingMarker(String)
}

private func readCookbookRepoFile(_ relativePath: String) throws -> String {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
}

private func cookbookSourceSlice(_ source: String, from startMarker: String, to endMarker: String) throws -> String {
    guard let start = source.range(of: startMarker) else {
        throw CookbookVisualContractError.missingMarker(startMarker)
    }
    guard let end = source.range(of: endMarker, range: start.upperBound..<source.endIndex) else {
        throw CookbookVisualContractError.missingMarker(endMarker)
    }
    return String(source[start.lowerBound..<end.lowerBound])
}
