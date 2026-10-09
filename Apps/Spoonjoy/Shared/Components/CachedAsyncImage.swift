import CoreGraphics
import Foundation
import SpoonjoyCore
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The app-wide image pipeline: memory cache, then a bounded disk cache in Caches, then the network.
enum AppImagePipeline {
    static let shared = ImagePipeline.standard(
        cachesDirectory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    )
}

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

/// A cached stand-in for AsyncImage. It decodes to the size it is shown at, shows a memory-cached image on
/// its first frame, and drops its load when the view goes away without leaving anything half-written.
struct CachedAsyncImage<Content: View>: View {
    private struct LoadKey: Hashable {
        let url: URL
        let pixelSize: Int
    }

    /// The wait before each retry after a failed load; the first attempt starts immediately.
    private static var retryDelays: [Duration] {
        [.seconds(1), .seconds(3), .seconds(8)]
    }

    let url: URL
    let animation: Animation?
    @ViewBuilder let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase = .empty
    @State private var pixelSize = 0
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        content(phase)
            .onGeometryChange(for: Double.self) { proxy in
                max(proxy.size.width, proxy.size.height)
            } action: { points in
                let bucket = ImageDownsampleBucket.pixelSize(points: points, scale: displayScale)
                guard bucket != pixelSize else {
                    return
                }
                pixelSize = bucket
                if let cached = AppImagePipeline.shared.memory.image(url: url, maxPixelSize: bucket) {
                    phase = .success(Image(decorative: cached, scale: 1))
                }
            }
            .task(id: LoadKey(url: url, pixelSize: pixelSize)) {
                guard pixelSize > 0, !isLoaded else {
                    return
                }
                // A load that fails right after launch (network not ready, a request cancelled by a relayout)
                // must not leave the placeholder up until the chef navigates away and back: retry a few times
                // before giving up.
                var image = await AppImagePipeline.shared.image(for: url, maxPixelSize: pixelSize)
                for delay in Self.retryDelays where image == nil {
                    guard !Task.isCancelled else {
                        return
                    }
                    try? await Task.sleep(for: delay)
                    guard !Task.isCancelled else {
                        return
                    }
                    image = await AppImagePipeline.shared.image(for: url, maxPixelSize: pixelSize)
                }
                guard !Task.isCancelled else {
                    return
                }
                withAnimation(animation) {
                    phase = image.map { .success(Image(decorative: $0, scale: 1)) } ?? .failure
                }
            }
    }

    private var isLoaded: Bool {
        if case .success = phase {
            return true
        }
        return false
    }
}
