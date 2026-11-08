import Foundation
import OuroHX
import SpoonjoyCore
import SwiftUI
import Testing

/// Web's typefaces register for the process and resolve as the cookbook's text roles; a face that isn't there falls
/// back to the system font.
@Suite("Kitchen fonts", .serialized)
struct KitchenFontFilesTests {
    static var fontsFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Apps/Spoonjoy/Shared/Fonts")
    }

    static var bundledURLs: [URL] {
        KitchenFontFiles.names.map { fontsFolder.appendingPathComponent($0) }
    }

    @Test("every bundled face is in the repository")
    func everyFaceIsInTheRepository() {
        for url in Self.bundledURLs {
            #expect(FileManager.default.fileExists(atPath: url.path), "\(url.lastPathComponent)")
        }
    }

    @Test("the fonts register, twice is harmless, and each cookbook role resolves to its face")
    func fontsRegisterAndResolve() throws {
        #expect(KitchenFontFiles.register(Self.bundledURLs).isEmpty)
        #expect(KitchenFontFiles.register(Self.bundledURLs).isEmpty)
        for family in ["Fraunces", "Source Serif 4", "IBM Plex Sans Condensed"] {
            #expect(OuroFont.isRegistered(family), "\(family)")
        }
        let extras = OuroTokens.cookbook.extras
        let expected: [OuroExtraType: String] = [
            .sjTypeTitle: "Fraunces", .sjTypeBody: "Source Serif 4", .sjTypeEyebrow: "IBM Plex Sans Condensed"
        ]
        for (role, family) in expected {
            let token = try #require(extras.type[role])
            #expect(OuroFont.resolve(token, in: extras) == .custom(family), "\(role)")
        }
    }

    @Test("a missing face falls back to the system serif or sans")
    func missingFontFallsBack() throws {
        let extras = OuroTokens.cookbook.extras
        let title = try #require(extras.type[.sjTypeTitle])
        let label = try #require(extras.type[.sjTypeUi])
        #expect(OuroFont.resolve(title, in: extras, registered: { _ in false }) == .system(design: .serif))
        #expect(OuroFont.resolve(label, in: extras, registered: { _ in false }) == .system(design: .default))
    }

    @Test("a file that isn't a font fails to register and is reported")
    func notAFontIsReported() throws {
        let bogus = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-not-a-font-\(UUID()).ttf")
        try Data("not a font".utf8).write(to: bogus)
        defer { try? FileManager.default.removeItem(at: bogus) }
        #expect(KitchenFontFiles.register([bogus]) == [bogus])
    }

    @Test("every typeface's OFL text is in the repository, and a bundle lists only the texts it carries")
    func licenceTexts() throws {
        for licence in KitchenFontFiles.licences {
            let text = try String(contentsOf: Self.fontsFolder.appendingPathComponent(licence.file), encoding: .utf8)
            #expect(text.contains("SIL Open Font License, Version 1.1"), "\(licence.file)")
            #expect(text.contains("SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007"), "\(licence.file)")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-licence-bundle-\(UUID()).bundle")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.copyItem(at: Self.fontsFolder.appendingPathComponent("OFL-SourceSerif4.txt"),
                                         to: folder.appendingPathComponent("OFL-SourceSerif4.txt"))
        // A file that isn't UTF-8 text is left out rather than shown garbled.
        try Data([0xFF, 0xFE, 0xFD]).write(to: folder.appendingPathComponent("OFL-Fraunces.txt"))
        let bundle = try #require(Bundle(url: folder))
        let texts = KitchenFontFiles.licenceTexts(in: bundle)
        #expect(texts.map(\.typeface) == ["Source Serif 4"])
        #expect(texts.first?.text.hasPrefix("Copyright 2014 The Source Serif 4 Project Authors") == true)
    }

    @Test("a bundle lists only the faces it carries")
    func bundleListsOnlyWhatItCarries() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-font-bundle-\(UUID()).bundle")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = Self.fontsFolder.appendingPathComponent("IBMPlexSansCondensed-Bold.ttf")
        try FileManager.default.copyItem(at: source, to: folder.appendingPathComponent("IBMPlexSansCondensed-Bold.ttf"))
        let bundle = try #require(Bundle(url: folder))
        #expect(KitchenFontFiles.urls(in: bundle).map(\.lastPathComponent) == ["IBMPlexSansCondensed-Bold.ttf"])
    }
}
