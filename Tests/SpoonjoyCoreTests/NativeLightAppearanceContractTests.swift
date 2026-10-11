import Foundation
import Testing

/// Spoonjoy's native palette (`KitchenTableTheme`) is one fixed set of light colours. When the app follows system Dark Mode, the system draws its own controls, sheets, keyboards, bars and large titles dark against that bone palette, which leaves screens mismatched and some text unreadable (the "Kitchen" large title and the status bar turn white on bone).
///
/// Until a designed dark palette ships, the app is pinned to the light appearance on every surface that draws the palette. This is a stopgap: a designed dark mode is an open product decision. Remove these pins only in the same change that ships a designed dark palette, and delete this suite with them. The last test fails when `KitchenTableTheme` stops defining bone as a fixed web colour, so that change has to revisit the pins.
@Suite("Native light appearance contract")
struct NativeLightAppearanceContractTests {
    @Test("the iOS app is pinned to the light appearance while the palette is fixed light colours")
    func iOSAppIsPinnedToLightWhilePaletteIsFixed() throws {
        let plistPath = "Apps/Spoonjoy/Shared/Info.plist"
        let data = try Data(contentsOf: lightAppearanceRepoURL.appendingPathComponent(plistPath))
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        #expect(
            plist["UIUserInterfaceStyle"] as? String == "Light",
            Comment(rawValue: "\(plistPath) must set UIUserInterfaceStyle to Light until a designed dark palette ships; otherwise system chrome turns dark against the fixed bone palette.")
        )
    }

    @Test("the macOS app is pinned to the light Aqua appearance at launch while the palette is fixed light colours")
    func macAppIsPinnedToAquaWhilePaletteIsFixed() throws {
        let appPath = "Apps/Spoonjoy/macOS/SpoonjoyMacApp.swift"
        let app = lightAppearanceUncommentedSwift(try readLightAppearanceRepoFile(appPath))

        expectLightAppearanceContent(
            app,
            in: appPath,
            contains: [
                "func applicationWillFinishLaunching(_ notification: Notification) {\n        NSApp.appearance = NSAppearance(named: .aqua)"
            ],
            forbids: [
                "NSAppearance(named: .darkAqua)",
                ".preferredColorScheme(.dark)"
            ]
        )
    }

    @Test("the cook timer Lock Screen card keeps its bone card light while the palette is fixed light colours")
    func lockScreenLiveActivityIsPinnedToLightWhilePaletteIsFixed() throws {
        let widgetPath = "Apps/Spoonjoy/LiveActivity/Widget/SpoonjoyCookTimerLiveActivity.swift"
        let widget = lightAppearanceUncommentedSwift(try readLightAppearanceRepoFile(widgetPath))

        expectLightAppearanceContent(
            widget,
            in: widgetPath,
            contains: [
                "CookTimerLockScreenView(metadata: context.attributes.metadata, state: context.state)\n                .environment(\\.colorScheme, .light)\n                .activityBackgroundTint(KitchenTableTheme.bone)"
            ]
        )
    }

    @Test("the palette is still fixed light colours, so the light pins above still apply")
    func paletteIsStillFixedLightColours() throws {
        #expect(
            try paletteIsFixedLight(),
            "KitchenTableTheme no longer defines bone as a fixed web colour. If a designed dark palette shipped, delete this suite together with the light-appearance pins; otherwise restore the fixed palette."
        )
    }
}

private let lightAppearanceRepoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func paletteIsFixedLight() throws -> Bool {
    let theme = lightAppearanceUncommentedSwift(
        try readLightAppearanceRepoFile("Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift")
    )
    return theme.contains("static let bone = webColor(0xFBFAF4)")
}

private func readLightAppearanceRepoFile(_ relativePath: String) throws -> String {
    try String(contentsOf: lightAppearanceRepoURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func lightAppearanceUncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: .regularExpression)
}

private func expectLightAppearanceContent(
    _ content: String,
    in relativePath: String,
    contains requiredTokens: [String] = [],
    forbids forbiddenTokens: [String] = []
) {
    let missing = requiredTokens.filter { !content.contains($0) }
    let forbidden = forbiddenTokens.filter { content.contains($0) }
    #expect(missing.isEmpty, Comment(rawValue: "\(relativePath) missing tokens: \(missing.joined(separator: ", "))"))
    #expect(forbidden.isEmpty, Comment(rawValue: "\(relativePath) contains forbidden tokens: \(forbidden.joined(separator: ", "))"))
}
