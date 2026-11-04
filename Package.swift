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
    // ouro-ui-apple is a test-only dependency: the X-ray's claim set and checker (OuroAXTesting, ouro-ax-xray). The
    // apps don't link it. Bump the exact version and config/xray-expected.json together.
    dependencies: [
        .package(url: "https://github.com/ourostack/ouro-ui-apple.git", exact: "0.2.1")
    ],
    targets: [
        .target(name: "SpoonjoyCore", resources: [.copy("Fixtures")]),
        .executableTarget(name: "SpoonjoyNativeDogfood", dependencies: ["SpoonjoyCore"]),
        .executableTarget(name: "SpoonjoyScenarioVerifier", dependencies: ["SpoonjoyCore"]),
        .executableTarget(name: "SpoonjoyJourneyRules", dependencies: ["SpoonjoyCore"]),
        .testTarget(
            name: "SpoonjoyCoreTests",
            dependencies: ["SpoonjoyCore", .product(name: "OuroAXTesting", package: "ouro-ui-apple")]
        )
    ]
)
