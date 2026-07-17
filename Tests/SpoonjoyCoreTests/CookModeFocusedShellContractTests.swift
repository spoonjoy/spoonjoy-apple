import Foundation
import Testing

@Suite("Cook mode focused shell contract")
struct CookModeFocusedShellContractTests {
    @Test("macOS focused cook mode exposes a close action without changing iOS chrome")
    func macOSFocusedCookModeExposesCloseActionWithoutChangingIOSChrome() throws {
        let path = "Apps/Spoonjoy/Shared/Views/CookModeView.swift"
        let source = try String(contentsOfFile: path, encoding: .utf8)

        let headerStart = try #require(source.range(of: "private var compactTaskHeader"))
        let progressStart = try #require(source.range(of: "private var stepProgressRail", range: headerStart.upperBound..<source.endIndex))
        let header = String(source[headerStart.lowerBound..<progressStart.lowerBound])

        #expect(header.contains("#if os(macOS)"))
        #expect(header.contains("macOSCookModeCloseButton"))
        #expect(header.contains("Button(action: close)"))
        #expect(header.contains("Label(\"Close\", systemImage: \"xmark\")"))
        #expect(header.contains(".accessibilityLabel(\"Close cook mode\")"))
        #expect(!header.contains("#if os(iOS)"))
    }
}
