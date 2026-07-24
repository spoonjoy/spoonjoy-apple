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
        let theme = try readCookbookRepoFile("Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift")
        let index = try cookbookSourceSlice(source, from: "private var cookbookIndexRows", to: "private func cookbookEmptyState")
        let shelf = try cookbookSourceSlice(source, from: "struct CookbookShelf: View", to: "private struct CookbookThumb")
        let thumb = try cookbookSourceSlice(source, from: "private struct CookbookThumb", to: "private struct CookbookCoverArt")
        let cover = try cookbookSourceSlice(source, from: "private struct CookbookCoverArt", to: "private struct CookbookImageCover")
        let fallback = try cookbookSourceSlice(source, from: "private struct CookbookFallbackCover", to: "struct CookbookDetailRouteView")
        let fallbackImprint = try cookbookSourceSlice(fallback, from: "Text(\"Spoonjoy\")", to: "Spacer(minLength: 0)")

        #expect(index.contains("CookbookThumb(row: row)"))
        #expect(index.contains("showsLeading: row.cover.imageURLs.contains { $0 != nil }"))
        #expect(thumb.contains("CookbookImageCover(imageURLs:"))
        #expect(!thumb.contains("KitchenTableNoPhotoView("))
        #expect(!thumb.contains("Text("))
        #expect(!thumb.contains("books.vertical.fill"))
        #expect(!shelf.contains(".accessibilityElement(children: .ignore)"))
        #expect(!shelf.contains(".accessibilityAddTraits(.isButton)"))
        #expect(!shelf.contains(".accessibilityLabel(\"\\(row.title), \\(row.recipeCountLabel)\")"))
        #expect(shelf.contains(".accessibilityLabel(row.title)"))
        #expect(shelf.contains(".accessibilityValue(row.recipeCountLabel)"))
        #expect(!shelf.contains("let openRoute: (AppRoute) -> Void"))
        #expect(!shelf.contains("Button {"))
        #expect(shelf.contains("NavigationLink(value: row.openRoute)"))
        #expect(shelf.contains("@Environment(\\.horizontalSizeClass) private var horizontalSizeClass"))
        #expect(shelf.contains("if horizontalSizeClass == .compact || dynamicTypeSize >= .xxLarge"))
        #expect(shelf.contains("CookbookCoverArt(row: row)"))
        #expect(!shelf.contains("hidesFromAccessibility: false"))
        #expect(shelf.contains("KitchenTableObjectRow("))
        #expect(!shelf.contains("accessibleCookbookRow"))
        #expect(!shelf.contains("Text(row.recipeCountLabel)"))
        #expect(!shelf.contains(".font(.headline.weight(.semibold))"))
        #expect(!shelf.contains(".fontDesign(.rounded)"))
        #expect(!shelf.contains(".frame(maxWidth: .infinity, alignment: .leading)\n                .accessibilityHidden(true)"))
        #expect(shelf.contains("LazyVStack(alignment: .leading, spacing: 0)"))
        #expect(shelf.contains("HStack(alignment: .top, spacing: 20)"))
        #expect(!shelf.contains("HStack(alignment: .top, spacing: 14)"))
        #expect(!shelf.contains(".padding(.vertical, 12)"))
        #expect(!shelf.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(cover.contains(".accessibilityHidden(true)"))
        #expect(!cover.contains(".accessibilityElement(children: .combine)"))
        #expect(!cover.contains(".accessibilityIdentifier(\"CookbookCoverArt\")"))
        #expect(!cover.contains(".dynamicTypeSize("))
        #expect(cover.contains(".font(.caption2.weight(.bold))"))
        #expect(cover.contains(".font(.system(.title3, design: .serif).weight(.bold))"))
        #expect(!theme.contains("hidesTextFromAccessibility"))
        #expect(!fallback.contains("KitchenTableNoPhotoView("))
        #expect(!fallback.contains("photo.badge.plus"))
        #expect(fallback.contains("Text(title)"))
        #expect(fallback.contains(".font(.caption2.weight(.bold))"))
        #expect(fallback.contains(".font(.headline.weight(.bold))"))
        #expect(fallback.contains(".fontDesign(.serif)"))
        #expect(!fallback.contains("titleFontSize(for:"))
        #expect(fallback.contains(".lineLimit(4)"))
        #expect(fallback.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(!fallback.contains(".font(.system(size:"))
        #expect(!fallback.contains(".minimumScaleFactor("))
        #expect(!fallback.contains(".lineLimit(3)"))
        #expect(fallbackImprint.contains(".foregroundStyle(KitchenTableTheme.charcoal)"))
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
