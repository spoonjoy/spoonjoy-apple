import UIKit
import Vision
import XCTest

/// Motion checks for cook mode. Each one plays a transition in slow motion (`-SpoonjoySlowMotion`, DEBUG), samples
/// screenshots while it runs and reads every frame, so it fails on a frame a person would see, however busy the
/// machine. They need the screenshot fixture kitchen seeded into the simulator, so only `scripts/check-motion.sh`
/// runs them; anywhere else they skip.
@MainActor
final class CookMotionUITests: XCTestCase {
    static let fixtureVariable = "SPOONJOY_MOTION_CHECK"
    static let slowMotion = 10.0

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.fixtureVariable] == "1",
            "Needs the seeded fixture kitchen; run scripts/check-motion.sh."
        )
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await MainActor.run {
            continueAfterFailure = true
            app?.terminate()
            app = nil
        }
    }

    /// A step turn moves one set of "For this step" rows with its page. Swapping in a second set mid-turn drew both,
    /// a few points apart (W10 jank audit, finding 1).
    func testStepTurnDrawsEachChecklistRowOnce() throws {
        openCookMode()
        let frames = sample(seconds: 7) {
            element("cook.page").swipeLeft()
        }
        let reads = try frames.map { try MotionFrameText.read($0.screenshot, screen: app.frame) }

        let headingX = reads.compactMap { read in read.first { $0.text == "Build Sauce" }?.frame.minX }
        XCTAssertGreaterThan(
            (headingX.max() ?? 0) - (headingX.min() ?? 0), 40,
            "The samples never caught the turn in motion, so they prove nothing. Heading x: \(headingX)"
        )
        // Keep a few frames from mid-turn as evidence either way.
        let (left, right) = (headingX.min() ?? 0, headingX.max() ?? 0)
        let moving = reads.indices.filter { index in
            guard let x = reads[index].first(where: { $0.text == "Build Sauce" })?.frame.minX else { return false }
            return x > left + 10 && x < right - 10
        }
        for index in moving.enumerated().filter({ $0.offset % max(moving.count / 4, 1) == 0 }).map(\.element).prefix(4) {
            attach(frames[index].screenshot, named: "turn-\(Int(frames[index].time * 1000))ms")
        }
        var ghosts: [String] = []
        for (index, read) in reads.enumerated() {
            for ghost in MotionFrameText.doubled(read) {
                ghosts.append("frame \(index) at \(Int(frames[index].time * 1000)) ms: \(ghost)")
                attach(frames[index].screenshot, named: "doubled-\(index)")
            }
        }
        XCTAssertTrue(ghosts.isEmpty, "Rows drawn twice during the turn:\n" + ghosts.joined(separator: "\n"))
    }

    // MARK: Driving

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(arguments: [String] = []) {
        app = XCUIApplication()
        let environment = ProcessInfo.processInfo.environment
        for key in ["SPOONJOY_SCREENSHOT_AUTH", "SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY", "SPOONJOY_SCREENSHOT_ACCOUNT_ID"] {
            if let value = environment[key] {
                app.launchEnvironment[key] = value
            }
        }
        app.launchEnvironment["SPOONJOY_JOURNEY_ALARM_FIXTURE"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-SpoonjoySlowMotion", "\(Self.slowMotion)"]
        app.launchArguments += arguments
        app.launch()
    }

    private func openCookMode() {
        launch()
        let kitchen = element("kitchen.root"), cooking = element("cook.page")
        let opened = Date()
        while !kitchen.exists, !cooking.exists, Date().timeIntervalSince(opened) < 60 {
            Thread.sleep(forTimeInterval: 0.5)
        }
        if cooking.exists {
            // A cook session from an earlier run restores into cook mode; close it so the run starts on step 1.
            element("cook.close").tap()
        } else {
            XCTAssertTrue(kitchen.exists, "The fixture kitchen did not open.")
            element("kitchen.recipe.open").tap()
        }
        XCTAssertTrue(element("recipeDetail.cook").waitForExistence(timeout: 60), "The recipe did not open.")
        element("recipeDetail.cook").tap()
        XCTAssertTrue(element("cook.page").waitForExistence(timeout: 60), "Cook mode did not open.")
        // Let the cover finish rising (a system transition, not slowed) before the clock starts.
        Thread.sleep(forTimeInterval: 2)
    }

    struct Frame {
        let time: Double
        let screenshot: XCUIScreenshot
    }

    /// Screenshots on a background thread, as fast as XCTest returns them, while `action` runs and until `seconds` pass.
    private func sample(seconds: Double, action: () -> Void) -> [Frame] {
        let capture = MotionCapture(seconds: seconds)
        capture.start()
        action()
        return capture.wait()
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Takes screenshots on its own thread until its time runs out.
final class MotionCapture: @unchecked Sendable {
    private let seconds: Double
    private var frames: [CookMotionUITests.Frame] = []
    private let done = DispatchSemaphore(value: 0)

    init(seconds: Double) {
        self.seconds = seconds
    }

    func start() {
        Thread { [self] in
            let start = Date()
            while Date().timeIntervalSince(start) < seconds {
                let time = Date().timeIntervalSince(start)
                frames.append(CookMotionUITests.Frame(time: time, screenshot: XCUIScreen.main.screenshot()))
            }
            done.signal()
        }.start()
    }

    func wait() -> [CookMotionUITests.Frame] {
        done.wait()
        return frames
    }
}

/// The words drawn in a frame, in screen points, and the test for a row drawn twice.
enum MotionFrameText {
    struct Line: CustomStringConvertible {
        let text: String
        let frame: CGRect

        var description: String {
            "\"\(text)\" at \(Int(frame.minX)),\(Int(frame.minY))"
        }
    }

    static func read(_ screenshot: XCUIScreenshot, screen: CGRect) throws -> [Line] {
        let image = try XCTUnwrap(screenshot.image.cgImage, "The screenshot has no bitmap.")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }
            let box = observation.boundingBox
            return Line(
                text: candidate.string.trimmingCharacters(in: .whitespaces),
                frame: CGRect(
                    x: screen.minX + box.minX * screen.width,
                    y: screen.minY + (1 - box.maxY) * screen.height,
                    width: box.width * screen.width,
                    height: box.height * screen.height
                )
            )
        }
    }

    /// The same words drawn twice in one column, a few points apart: one row ghosting over itself. Rows on the
    /// neighbouring page sit a page width away, and the rows of one step are a row height (60 pt) apart and differ.
    static func doubled(_ lines: [Line]) -> [String] {
        var found: [String] = []
        let words = lines.filter { $0.text.count >= 3 && $0.text.contains(where: \.isLetter) }
        for (index, line) in words.enumerated() {
            for other in words[(index + 1)...] where other.text == line.text {
                let dx = abs(other.frame.minX - line.frame.minX)
                let dy = abs(other.frame.minY - line.frame.minY)
                if dx < 14, dy > 2, dy < 56 {
                    found.append("\(line) and \(other)")
                }
            }
        }
        return found
    }
}
