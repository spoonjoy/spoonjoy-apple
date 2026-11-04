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
        .executable(name: "SpoonjoyJourneyRules", targets: ["SpoonjoyJourneyRules"])
    ],
    dependencies: [
        // Ouro HX: the shared Reduce Motion crossfade, haptic moments and cookbook colour tokens. Pinned exactly; the
        // Xcode project pins the same version for the app targets.
        .package(url: "https://github.com/ourostack/ouro-ui-apple.git", exact: "0.2.1")
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
        .testTarget(
            name: "SpoonjoyCoreTests",
            dependencies: ["SpoonjoyCore", .product(name: "OuroHX", package: "ouro-ui-apple")]
        )
    ]
)
