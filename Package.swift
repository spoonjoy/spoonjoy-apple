// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SpoonjoyApple",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "SpoonjoyCore", targets: ["SpoonjoyCore"]),
        .executable(name: "SpoonjoyNativeDogfood", targets: ["SpoonjoyNativeDogfood"]),
        .executable(name: "SpoonjoyScenarioVerifier", targets: ["SpoonjoyScenarioVerifier"]),
        .executable(name: "SpoonjoyJourneyRules", targets: ["SpoonjoyJourneyRules"]),
        // SPIKE (W13, Ouro Reins): the phone shell driven headless with `ls` and `do`. Not for merge.
        .executable(name: "spoonjoy-reins", targets: ["spoonjoy-reins"])
    ],
    // ouro-ui-apple, pinned exactly: Ouro HX (the shared Reduce Motion crossfade, haptic moments and cookbook colour
    // tokens), which the Xcode project pins at the same version for the app targets, and, for tests only, the X-ray's
    // claim set and checker (OuroAXTesting, ouro-ax-xray). Bump the version and config/xray-expected.json together.
    dependencies: [
        // SPIKE: Ouro Reins exists only on ouro-ui-apple's w13/reins-core branch so far.
        .package(url: "https://github.com/ourostack/ouro-ui-apple.git", branch: "w13/reins-core")
    ],
    targets: [
        .target(
            name: "SpoonjoyCore",
            dependencies: [.product(name: "OuroHX", package: "ouro-ui-apple")],
            resources: [.copy("Fixtures")]
        ),
        .executableTarget(name: "SpoonjoyNativeDogfood", dependencies: ["SpoonjoyCore"]),
        .executableTarget(name: "SpoonjoyScenarioVerifier", dependencies: ["SpoonjoyCore"]),
        .executableTarget(name: "SpoonjoyJourneyRules", dependencies: ["SpoonjoyCore"]),
        // SPIKE (W13, Ouro Reins).
        .target(
            name: "SpoonjoyReins",
            dependencies: ["SpoonjoyCore", .product(name: "OuroReins", package: "ouro-ui-apple")],
            resources: [.copy("Fixtures")]
        ),
        .executableTarget(name: "spoonjoy-reins", dependencies: ["SpoonjoyReins", .product(name: "OuroReins", package: "ouro-ui-apple")]),
        .testTarget(
            name: "SpoonjoyReinsTests",
            dependencies: ["SpoonjoyReins", "SpoonjoyCore", .product(name: "OuroReins", package: "ouro-ui-apple")]
        ),
        .testTarget(
            name: "SpoonjoyCoreTests",
            dependencies: [
                "SpoonjoyCore",
                .product(name: "OuroHX", package: "ouro-ui-apple"),
                .product(name: "OuroAXTesting", package: "ouro-ui-apple")
            ]
        )
    ]
)
