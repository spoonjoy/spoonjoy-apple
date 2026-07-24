import CoreGraphics
import Foundation

struct PointSize: Codable {
    let width: Double
    let height: Double
}

struct VerificationRequest: Codable {
    let screenshotPath: String
    let pointSize: PointSize
    let frame: ObservedRect
    let requiredContrastRatio: Double
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let input = FileHandle.standardInput.readDataToEndOfFile()
let request: VerificationRequest
do {
    request = try JSONDecoder().decode(VerificationRequest.self, from: input)
} catch {
    fail("invalid screenshot contrast verification request: \(error)")
}

let screenshotURL = URL(fileURLWithPath: request.screenshotPath)
guard let pngData = try? Data(contentsOf: screenshotURL) else {
    fail("screenshot contrast evidence could not read the screenshot")
}
guard let buffer = ScreenshotPixelBuffer(
    pngData: pngData,
    pointSize: CGSize(width: request.pointSize.width, height: request.pointSize.height)
) else {
    fail("screenshot contrast evidence could not decode the screenshot")
}
guard let crop = buffer.crop(in: request.frame) else {
    fail(
        "screenshot contrast evidence crop is outside the point-size bounds " +
        "(pixels=\(buffer.width)x\(buffer.height), points=\(request.pointSize.width)x\(request.pointSize.height), " +
        "frame=\(request.frame.x),\(request.frame.y),\(request.frame.width),\(request.frame.height))"
    )
}
guard let evidence = ScreenshotPixelContrastAdjudicator.analyze(
    pixels: crop.pixels,
    width: crop.width,
    height: crop.height,
    screenshotSHA256: buffer.screenshotSHA256 ?? "",
    requiredContrastRatio: request.requiredContrastRatio
) else {
    fail(
        "screenshot contrast evidence did not satisfy pixel adjudication " +
        "(crop=\(crop.width)x\(crop.height), requiredContrastRatio=\(request.requiredContrastRatio))"
    )
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
do {
    FileHandle.standardOutput.write(try encoder.encode(evidence))
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    fail("screenshot contrast evidence could not be encoded: \(error)")
}
