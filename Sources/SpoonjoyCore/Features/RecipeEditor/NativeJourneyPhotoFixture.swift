import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Lets a journey choose a recipe photo without driving the system photo picker, which is system UI that
/// automation cannot drive reliably. When a journey launches the app with the environment key set, the
/// editor's "Add Photo" button stages this generated picture directly. The app reads the key only in DEBUG
/// builds, so release builds always show the real picker.
public enum NativeJourneyPhotoFixture {
    public static let environmentKey = "SPOONJOY_JOURNEY_PHOTO_FIXTURE"

    public static func isRequested(environment: [String: String]) -> Bool {
        switch environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            true
        default:
            false
        }
    }

    /// A small warm gradient, encoded as a JPEG so it goes through the same cover preparation as a real photo.
    /// Every call below succeeds for these fixed inputs, so the force unwraps cannot fire.
    public static func stagedUpload() -> NativeStagedMediaUpload {
        let width = 320
        let height = 240
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let colors = [CGColor(red: 0.93, green: 0.45, blue: 0.24, alpha: 1), CGColor(red: 0.96, green: 0.80, blue: 0.40, alpha: 1)] as CFArray
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return NativeStagedMediaUpload(localStageID: "journey-photo-fixture", fileName: "cover.jpg", contentType: "image/jpeg", data: data as Data)
    }
}
