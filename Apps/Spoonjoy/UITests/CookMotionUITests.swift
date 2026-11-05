import UIKit
import Vision
import XCTest

/// Motion checks for cook mode. Each one plays a transition in slow motion (`-SpoonjoySlowMotion`, DEBUG), samples
/// screenshots while it runs and reads every frame, so it fails on a frame a person would see, however busy the
/// machine. They need the screenshot fixture kitchen seeded into the simulator, so only `scripts/check-motion.sh`
/// runs them; anywhere else they skip.
@MainActor
final class CookMotionUITests: XCTestCase {
    nonisolated static let fixtureVariable = "SPOONJOY_MOTION_CHECK"
    /// How much the app slows its motion for the check. MOTION_REAL_SPEED=1 on scripts/check-motion.sh plays it at
    /// full speed instead, to film what people see; the frame-count checks then have too few frames to judge.
    static var slowMotion: Double {
        ProcessInfo.processInfo.environment["SPOONJOY_MOTION_REAL_SPEED"] == "1" ? 1 : 10
    }
    /// The second step's heading in the fixture recipe (Sources/SpoonjoyCore/Fixtures/recipes-fixture.json), tracked across the turn.
    static let nextStepHeading = "Build Sauce"
    /// That step's timer hint, from `CookModeView.startHint(ingredientCount:)`.
    static let nextStepHint = "Tap to start or check all"
    /// The start of that step's instruction.
    static let nextStepTextStart = "Warm the"

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

        let headingX = reads.compactMap { read in read.first { $0.text == Self.nextStepHeading }?.frame.minX }
        XCTAssertGreaterThan(
            (headingX.max() ?? 0) - (headingX.min() ?? 0), 40,
            "The samples never caught the turn in motion, so they prove nothing. Heading x: \(headingX)"
        )
        // Keep a few frames from mid-turn as evidence either way.
        let (left, right) = (headingX.min() ?? 0, headingX.max() ?? 0)
        let moving = reads.indices.filter { index in
            guard let x = reads[index].first(where: { $0.text == Self.nextStepHeading })?.frame.minX else { return false }
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

        // The incoming page is whole before it lands: its timer hint dims and brightens with the rest of the page, not
        // fading in on its own as the page becomes current. Measured as the hint's ink against the step text's ink on
        // the same page, which stays put whatever the page's own opacity.
        var ratios: [(index: Int, ratio: Double)] = []
        for (index, read) in reads.enumerated() {
            guard let hint = read.first(where: { $0.text.hasPrefix(Self.nextStepHint) }),
                  let text = read.first(where: { $0.text.hasPrefix(Self.nextStepTextStart) }),
                  hint.frame.minX > 8, hint.frame.maxX < app.frame.width - 8 else { continue }
            let pixels = try MotionPixels(frames[index].screenshot, screen: app.frame)
            let textInk = pixels.contrast(in: text.frame)
            guard textInk > 20 else { continue }
            ratios.append((index, pixels.contrast(in: hint.frame) / textInk))
        }
        let settled = ratios.last?.ratio ?? 0
        XCTAssertGreaterThan(ratios.count, 3, "Too few frames showed the incoming hint to judge it.")
        let faint = ratios.filter { $0.ratio < settled * 0.75 }
        for entry in faint.prefix(3) {
            attach(frames[entry.index].screenshot, named: "faint-hint-\(entry.index)")
        }
        let report = ratios.map { "\(Int(frames[$0.index].time * 1000)) ms \(String(format: "%.2f", $0.ratio))" }.joined(separator: ", ")
        XCTAssertTrue(
            faint.isEmpty,
            "The incoming page's timer hint faded in after the page did. Hint ink against the step text's, per frame: \(report)"
        )
    }

    /// Starting a step's timer sweeps the brass arc in around the ring, as Clock's timer does. It used to appear whole
    /// in one frame, with Start swapped for the countdown and Cancel all at once (W10 jank audit, finding 6).
    func testTimerStartSweepsItsArcIn() throws {
        openCookMode()
        let ring = element("cook.timer.ring")
        XCTAssertTrue(ring.waitForExistence(timeout: 30), "The step has no timer ring.")
        let face = ring.frame
        let frames = sample(seconds: 8) {
            ring.tap()
        }
        let coverage = try frames.map { try MotionFrameArc.brassCoverage($0.screenshot, ring: face, screen: app.frame) }
        let cancel = element("cookMode.timer.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "The running timer offers no Cancel.")
        let cancelling = sample(seconds: 4) {
            cancel.tap()
        }
        let unwinding = try cancelling.map { try MotionFrameArc.brassCoverage($0.screenshot, ring: face, screen: app.frame) }

        let full = coverage.max() ?? 0
        let readout = coverage.map { String(format: "%.2f", $0) }.joined(separator: " ")
        XCTAssertGreaterThan(full, 0.15, "The arc never drew. Brass coverage per frame: \(readout)")
        let sweeping = coverage.indices.filter { coverage[$0] > 0.1 * full && coverage[$0] < 0.85 * full }
        for index in sweeping.prefix(3) {
            attach(frames[index].screenshot, named: "sweep-\(Int(frames[index].time * 1000))ms")
        }
        XCTAssertGreaterThanOrEqual(
            sweeping.count, 3,
            "The arc appeared whole instead of sweeping in. Brass coverage per frame: \(readout)"
        )

        // Cancelling unwinds the arc back to twelve o'clock rather than dropping it in one frame.
        let unwound = unwinding.indices.filter { unwinding[$0] > 0.1 * full && unwinding[$0] < 0.85 * full }
        for index in unwound.prefix(2) {
            attach(cancelling[index].screenshot, named: "unwind-\(Int(cancelling[index].time * 1000))ms")
        }
        XCTAssertGreaterThanOrEqual(
            unwound.count, 2,
            "The arc vanished at once on Cancel. Brass coverage per frame: \(unwinding.map { String(format: "%.2f", $0) }.joined(separator: " "))"
        )

        // The digits read as one clock in every frame, never as two faces fading through each other (which read as
        // "190500" or as two clocks). The label under them may crossfade, so only digits are judged.
        var muddled: [String] = []
        var oneClock = 0, early = 0
        for frame in frames where frame.time < 4 {
            early += 1
            let lines = try MotionFrameText.read(frame.screenshot, screen: app.frame)
            let inRing = lines.filter { face.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
            let clocks = inRing.filter { $0.text.range(of: #"\d:\d\d"#, options: .regularExpression) != nil }
            let runs = inRing.filter { $0.text.range(of: #"\d{3,}"#, options: .regularExpression) != nil }
            if clocks.count == 1 {
                oneClock += 1
            }
            if clocks.count > 1 || !runs.isEmpty {
                muddled.append("\(Int(frame.time * 1000)) ms: \(inRing.map(\.text))")
                if muddled.count <= 3 {
                    attach(frame.screenshot, named: "muddled-\(Int(frame.time * 1000))ms")
                }
            }
        }
        XCTAssertGreaterThanOrEqual(oneClock * 2, early, "The ring's digits were unreadable in most frames.")
        XCTAssertTrue(muddled.isEmpty, "Starting the timer drew two faces at once:\n" + muddled.joined(separator: "\n"))
    }

    /// Cook mode grows out of its Cook button and shrinks back into it, one object, the same way in as out (W10 jank
    /// audit, findings 2 and 3). It used to slide up as a sheet whose spring tail read as the step landing late, and
    /// slide down onto a recipe page with no tab bar, which rose in only once the sheet had gone. Played 25 times slower,
    /// so the screenshots see the whole move.
    func testCookCoverRisesAndFallsWhole() throws {
        // Slower than the other checks, so even a busy machine's screenshots catch each sweep several times over.
        let slowMotion = Self.slowMotion > 1 ? 25 : 1.0
        launch(slowMotion: slowMotion)
        let kitchen = element("kitchen.root"), cooking = element("cook.page"), cook = element("recipeDetail.cook")
        let opened = Date()
        while !kitchen.exists, !cooking.exists, !cook.exists, Date().timeIntervalSince(opened) < 60 {
            Thread.sleep(forTimeInterval: 0.5)
        }
        if cooking.exists {
            // Left open by an earlier run; it answers once it has settled.
            XCTAssertTrue(element("cook.close").waitForHittable(timeout: 60), "Cook mode never settled.")
            element("cook.close").tap()
        } else if !cook.exists {
            element("kitchen.recipe.open").tap()
        }
        XCTAssertTrue(cook.waitForExistence(timeout: 60), "The recipe did not open.")
        Thread.sleep(forTimeInterval: 3)
        let openSeconds = 1.2 * slowMotion
        let rising = sample(seconds: openSeconds) {
            cook.tap()
        }
        let close = element("cook.close")
        XCTAssertTrue(close.waitForExistence(timeout: 30), "Cook mode did not open.")
        Thread.sleep(forTimeInterval: 2)
        let falling = sample(seconds: openSeconds) {
            close.tap()
        }
        // Filming, or at full speed, there are too few frames to judge.
        if ProcessInfo.processInfo.environment["SPOONJOY_MOTION_FILM_ONLY"] == "1" || slowMotion == 1 {
            return
        }

        // Rising: once the page fills the screen, the step stays where it is.
        var settled: [(time: Double, y: Double)] = []
        var risingLook: [(time: Double, look: [Double])] = []
        for frame in rising {
            let pixels = try MotionPixels(frame.screenshot, screen: app.frame)
            risingLook.append((frame.time, Self.look(pixels)))
            guard Self.pageFillsTop(pixels) else { continue }
            let lines = try MotionFrameText.read(frame.screenshot, screen: app.frame)
            if let heading = lines.first(where: { $0.text.hasPrefix(Self.firstStepTextStart) }) {
                settled.append((frame.time, heading.frame.minY))
            }
        }
        if settled.count < 2 {
            for frame in rising.prefix(30) {
                attach(frame.screenshot, named: "rise-\(Int(frame.time * 1000))ms")
            }
        }
        XCTAssertGreaterThanOrEqual(settled.count, 2, "Cook mode never filled the screen in \(rising.count) frames.")
        let ys = settled.map(\.y)
        let climb = (ys.max() ?? 0) - (ys.min() ?? 0)
        XCTAssertLessThanOrEqual(
            climb, 4,
            "The step moved \(Int(climb)) pt after cook mode filled the screen: "
                + settled.map { "\(Int($0.time * 1000)) ms y=\(Int($0.y))" }.joined(separator: ", ")
        )

        // Falling: one object handing over to the page and its tab bar. The tab bar never draws over cook mode while
        // cook mode still fills the screen, it is back before cook mode has gone (no gap it fills late), and no frame
        // shows neither.
        var both = 0
        var overlap: [String] = []
        var neither: [String] = []
        var readout: [String] = []
        var fallingLook: [(time: Double, look: [Double])] = []
        for frame in falling {
            let pixels = try MotionPixels(frame.screenshot, screen: app.frame)
            fallingLook.append((frame.time, Self.look(pixels)))
            let fills = Self.pageFillsTop(pixels)
            let lines = try MotionFrameText.read(frame.screenshot, screen: app.frame).map(\.text)
            let cookShowing = lines.contains { $0.hasPrefix(Self.firstStepTextStart) || $0.hasPrefix("Lemon Pantry Pasta · Step") }
            let tabsShowing = lines.contains("Cookbooks") && lines.contains("Shopping")
            let stamp = "\(Int(frame.time * 1000)) ms"
            if cookShowing, tabsShowing {
                both += 1
            }
            if fills, cookShowing, tabsShowing {
                overlap.append(stamp)
            }
            if !cookShowing, !tabsShowing {
                neither.append(stamp)
            }
            readout.append("\(stamp) cook=\(cookShowing) fills=\(fills) tabs=\(tabsShowing)")
        }
        if both == 0 || !neither.isEmpty || !overlap.isEmpty {
            for frame in falling.prefix(30) {
                attach(frame.screenshot, named: "fall-\(Int(frame.time * 1000))ms")
            }
        }
        let falls = readout.joined(separator: "\n")
        XCTAssertGreaterThan(both, 0, "The tab bar only came back after cook mode had gone:\n" + falls)
        XCTAssertTrue(overlap.isEmpty, "The tab bar drew over cook mode while it filled the screen:\n" + falls)
        XCTAssertTrue(neither.isEmpty, "Frames with neither cook mode nor the tab bar:\n" + falls)

        // Symmetry: closing takes as long as opening, timed from the first frame that differs from where the move
        // began to the last frame that differs from where it ended. It is one spring each way, so the two match.
        let open = try XCTUnwrap(Self.movingSeconds(risingLook), "Opening never moved.")
        let shut = try XCTUnwrap(Self.movingSeconds(fallingLook), "Closing never moved.")
        XCTAssertLessThan(
            max(open, shut) / max(min(open, shut), 0.001), 1.5,
            String(format: "Opening moved for %.2f s and closing for %.2f s.", open, shut)
        )
    }

    /// The screen's brightness on a coarse grid, to tell whether two frames look alike.
    @MainActor static func look(_ pixels: MotionPixels) -> [Double] {
        var values: [Double] = []
        let width = Double(pixels.width) / pixels.scale, height = Double(pixels.height) / pixels.scale
        for y in stride(from: 8.0, to: height, by: 16.0) {
            for x in stride(from: 8.0, to: width, by: 16.0) {
                let (red, green, blue) = pixels.rgb(x: Int(x * pixels.scale), y: Int(y * pixels.scale))
                values.append((0.3 * Double(red) + 0.59 * Double(green) + 0.11 * Double(blue)) / 255)
            }
        }
        return values
    }

    /// Seconds from the first frame that differs from the first to the last frame that differs from the last.
    static func movingSeconds(_ curve: [(time: Double, look: [Double])]) -> Double? {
        guard let first = curve.first?.look, let last = curve.last?.look else { return nil }
        func differs(_ a: [Double], _ b: [Double]) -> Bool {
            zip(a, b).map { abs($0 - $1) }.reduce(0, +) / Double(max(a.count, 1)) > 0.01
        }
        guard let start = curve.first(where: { differs($0.look, first) })?.time,
              let end = curve.last(where: { differs($0.look, last) })?.time else {
            return nil
        }
        return end - start
    }

    /// Cook mode follows a finger and turns around mid-flight, like Music's player: a short pull down from the top
    /// shrinks it under the finger and springs back, a long one closes it, and closing while it is still opening
    /// reverses it from wherever it is rather than finishing the open first. Played at the Kitchen springs' slowed speed.
    func testCookCoverFollowsAFingerAndTurnsMidFlight() throws {
        let slowMotion = Self.slowMotion
        launch(slowMotion: slowMotion)
        let kitchen = element("kitchen.root"), cooking = element("cook.page"), cook = element("recipeDetail.cook")
        let opened = Date()
        while !kitchen.exists, !cooking.exists, !cook.exists, Date().timeIntervalSince(opened) < 60 {
            Thread.sleep(forTimeInterval: 0.5)
        }
        if cooking.exists {
            // Left open by an earlier run; it answers once it has settled.
            XCTAssertTrue(element("cook.close").waitForHittable(timeout: 60), "Cook mode never settled.")
            element("cook.close").tap()
        } else if !cook.exists {
            element("kitchen.recipe.open").tap()
        }
        XCTAssertTrue(cook.waitForExistence(timeout: 60), "The recipe did not open.")
        Thread.sleep(forTimeInterval: 3)
        // Filming, or at full speed, there are too few frames to judge, so only where it ends up is checked.
        let filmOnly = ProcessInfo.processInfo.environment["SPOONJOY_MOTION_FILM_ONLY"] == "1" || slowMotion == 1
        let screen = app.frame
        let point = { (x: Double, y: Double) in
            self.app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
        }

        // Turn around: catch it a third of the way into opening and flick it down. It never fills the screen, and
        // lands back on the recipe.
        // The card's bottom edge runs down from the button's as it opens, so a spot a little below the button is on
        // the card from early in the open until it lands. It is worked out before the tap: asking where an element is
        // while the app animates can wait for it to settle, which would land the grab after the open has finished.
        // At full speed the open is over before a synthesized press can land, so there it is caught by its top instead.
        let close = element("cook.close")
        let grabY = slowMotion == 1 ? 90 : cook.frame.maxY + 40
        let turning = sample(seconds: 1.6 * slowMotion) {
            cook.tap()
            Thread.sleep(forTimeInterval: 0.12 * slowMotion)
            point(screen.midX, grabY).press(
                forDuration: 0.05,
                thenDragTo: point(screen.midX, grabY + screen.height * 0.3),
                withVelocity: 2000,
                thenHoldForDuration: 0
            )
        }
        XCTAssertTrue(cook.waitForExistence(timeout: 60), "The recipe's Cook button did not come back.")
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(close.isHittable, "Cook mode finished opening after it was caught mid-flight.")
        if !filmOnly {
            let filled = try turning.filter { try Self.pageFillsTop(MotionPixels($0.screenshot, screen: screen)) }
            XCTAssertTrue(filled.isEmpty, "Cook mode filled the screen at \(filled.map { Int($0.time * 1000) }) ms after it was caught mid-flight.")
        }

        // Follow the finger: a short pull shrinks it under the finger with the recipe and tab bar showing, and it
        // springs back open on release.
        cook.tap()
        XCTAssertTrue(close.waitForHittable(timeout: 60), "Cook mode did not open.")
        Thread.sleep(forTimeInterval: 1.2 * slowMotion)
        var held: [Frame] = []
        let top = point(screen.midX, 90)
        let shortPull = point(screen.midX, 90 + screen.height * 0.3)
        held = sample(seconds: 0.6 * slowMotion) {
            top.press(forDuration: 0.2, thenDragTo: shortPull, withVelocity: 300, thenHoldForDuration: 0.4 * slowMotion)
        }
        XCTAssertTrue(close.waitForHittable(timeout: 60), "Cook mode closed after a short pull; it should spring back.")
        if !filmOnly {
            let shrunk = try held.filter { frame in
                let pixels = try MotionPixels(frame.screenshot, screen: screen)
                let lines = try MotionFrameText.read(frame.screenshot, screen: screen).map(\.text)
                return !Self.pageFillsTop(pixels) && lines.contains("Shopping")
                    && lines.contains { $0.hasPrefix(Self.firstStepTextStart) || $0.hasPrefix("Lemon Pantry Pasta · Step") }
            }
            XCTAssertFalse(shrunk.isEmpty, "Cook mode did not shrink under the finger in \(held.count) frames.")
        }

        // A long pull closes it.
        let longPull = point(screen.midX, 90 + screen.height * 0.65)
        top.press(forDuration: 0.2, thenDragTo: longPull, withVelocity: 1200, thenHoldForDuration: 0)
        XCTAssertTrue(cook.waitForExistence(timeout: 30), "A long pull did not close cook mode.")
        Thread.sleep(forTimeInterval: 1.6 * slowMotion)
        XCTAssertFalse(close.isHittable, "Cook mode stayed open after a long pull.")
    }

    /// The first step's text in the fixture recipe.
    static let firstStepTextStart = "Boil the pasta"

    /// Whether the cook page reaches the very top of the screen: page colour beside the status bar, where the recipe
    /// photo shows until the cover has fully arrived.
    @MainActor static func pageFillsTop(_ pixels: MotionPixels) -> Bool {
        let y = Int(3 * pixels.scale)
        for point in stride(from: 6.0, through: 30.0, by: 4.0) {
            for x in [Int(point * pixels.scale), pixels.width - 1 - Int(point * pixels.scale)] {
                let (red, green, blue) = pixels.rgb(x: x, y: y)
                guard red > 235, green > 230, blue > 210, red - blue < 35 else { return false }
            }
        }
        return true
    }

    // MARK: Driving

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(arguments: [String] = [], slowMotion: Double = CookMotionUITests.slowMotion) {
        app = XCUIApplication()
        let environment = ProcessInfo.processInfo.environment
        for key in ["SPOONJOY_SCREENSHOT_AUTH", "SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY", "SPOONJOY_SCREENSHOT_ACCOUNT_ID"] {
            if let value = environment[key] {
                app.launchEnvironment[key] = value
            }
        }
        app.launchEnvironment["SPOONJOY_JOURNEY_ALARM_FIXTURE"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-SpoonjoySlowMotion", "\(slowMotion)"]
        app.launchArguments += arguments
        app.launch()
    }

    private func openCookMode() {
        launch()
        let kitchen = element("kitchen.root"), cooking = element("cook.page"), recipe = element("recipeDetail.cook")
        let opened = Date()
        while !kitchen.exists, !cooking.exists, !recipe.exists, Date().timeIntervalSince(opened) < 60 {
            Thread.sleep(forTimeInterval: 0.5)
        }
        if cooking.exists {
            // A cook session from an earlier run restores into cook mode; close it so the run starts on step 1.
            element("cook.close").tap()
        } else if !recipe.exists {
            XCTAssertTrue(kitchen.exists, "The fixture kitchen did not open.")
            element("kitchen.recipe.open").tap()
        }
        XCTAssertTrue(recipe.waitForExistence(timeout: 60), "The recipe did not open.")
        recipe.tap()
        XCTAssertTrue(element("cook.page").waitForExistence(timeout: 60), "Cook mode did not open.")
        // A timer an earlier run left going would leave nothing to start.
        let leftover = element("cookMode.timer.cancel")
        if leftover.waitForExistence(timeout: 1) {
            leftover.tap()
        }
        // Let the cover finish rising (a system transition, not slowed) before the clock starts.
        Thread.sleep(forTimeInterval: 2)
    }

    struct Frame {
        let time: Double
        let screenshot: XCUIScreenshot
    }

    /// Screenshots on a background thread, as fast as XCTest returns them, while `action` runs and until `seconds` pass.
    private func sample(seconds: Double, action: () -> Void) -> [Frame] {
        // SPOONJOY_MOTION_FILM_ONLY=1: take no screenshots, which starve the simulator's own recorder of frames.
        if ProcessInfo.processInfo.environment["SPOONJOY_MOTION_FILM_ONLY"] == "1" {
            action()
            Thread.sleep(forTimeInterval: seconds)
            return []
        }
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

    /// XCTest marks `XCUIScreen` main-actor isolated, but the capture has to run while the main thread is blocked in
    /// the swipe, so it calls `screenshot` through the Objective-C runtime.
    private static let screenshotSelector = NSSelectorFromString("screenshot")

    @MainActor func start() {
        nonisolated(unsafe) let screen: NSObject = XCUIScreen.main
        Thread { [self] in
            let start = Date()
            while Date().timeIntervalSince(start) < seconds {
                let screenshot = autoreleasepool {
                    screen.perform(Self.screenshotSelector)?.takeUnretainedValue() as? XCUIScreenshot
                }
                if let screenshot {
                    frames.append(CookMotionUITests.Frame(time: Date().timeIntervalSince(start), screenshot: screenshot))
                }
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

    @MainActor static func read(_ screenshot: XCUIScreenshot, screen: CGRect) throws -> [Line] {
        let bitmap = screenshot.image.cgImage
        let image = try XCTUnwrap(bitmap, "The screenshot has no bitmap.")
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
    /// Two copies within 2 pt, or overlapping so closely that Vision reads them as one line, go unreported.
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

/// A frame's pixels, addressed in screen points.
struct MotionPixels {
    let width: Int, height: Int, scale: Double, origin: CGPoint
    let bytes: [UInt8]

    @MainActor init(_ screenshot: XCUIScreenshot, screen: CGRect) throws {
        let bitmap = screenshot.image.cgImage
        let image = try XCTUnwrap(bitmap, "The screenshot has no bitmap.")
        let (w, h) = (image.width, image.height)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        XCTAssertTrue(drawn, "Could not read the screenshot's pixels.")
        width = w
        height = h
        scale = Double(w) / screen.width
        origin = screen.origin
        bytes = pixels
    }

    func rgb(x: Int, y: Int) -> (Int, Int, Int) {
        let offset = (y * width + x) * 4
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
    }

    /// Paper less ink inside `rect`: its lightest luminance minus its darkest.
    func contrast(in rect: CGRect) -> Double {
        let left = max(0, Int((rect.minX - origin.x) * scale)), right = min(width - 1, Int((rect.maxX - origin.x) * scale))
        let top = max(0, Int((rect.minY - origin.y) * scale)), bottom = min(height - 1, Int((rect.maxY - origin.y) * scale))
        guard left < right, top < bottom else { return 0 }
        var lightest = 0.0, darkest = 255.0
        for y in top...bottom {
            for x in left...right {
                let (red, green, blue) = rgb(x: x, y: y)
                let luminance = 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
                lightest = max(lightest, luminance)
                darkest = min(darkest, luminance)
            }
        }
        return lightest - darkest
    }
}

/// How much of a timer ring's track is brass in a frame.
enum MotionFrameArc {
    /// The share of the ring's track (an annulus just inside its frame) drawn in the brass of a running arc.
    @MainActor static func brassCoverage(_ screenshot: XCUIScreenshot, ring: CGRect, screen: CGRect) throws -> Double {
        let pixels = try MotionPixels(screenshot, screen: screen)
        let scale = pixels.scale
        let centerX = (ring.midX - screen.minX) * scale, centerY = (ring.midY - screen.minY) * scale
        let outer = min(ring.width, ring.height) / 2 * scale
        let inner = outer * 0.86
        var track = 0, brass = 0
        let lowest = max(0, Int(centerY - outer)), highest = min(pixels.height - 1, Int(centerY + outer))
        let leftmost = max(0, Int(centerX - outer)), rightmost = min(pixels.width - 1, Int(centerX + outer))
        for y in stride(from: lowest, through: highest, by: 2) {
            for x in stride(from: leftmost, through: rightmost, by: 2) {
                let distance = hypot(Double(x) - centerX, Double(y) - centerY)
                guard distance >= inner, distance <= outer else { continue }
                track += 1
                // Kitchen brass, #9B6834, against the cream track; the night brass is lighter, #C4945C.
                let (red, green, blue) = pixels.rgb(x: x, y: y)
                if red - blue > 70, red - green > 30, red < 225 {
                    brass += 1
                }
            }
        }
        return track == 0 ? 0 : Double(brass) / Double(track)
    }
}

extension XCUIElement {
    /// Waits until the element can be tapped.
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists, isHittable {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}
