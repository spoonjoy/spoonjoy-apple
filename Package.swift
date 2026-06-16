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
        .executable(name: "SpoonjoyScenarioVerifier", targets: ["SpoonjoyScenarioVerifier"])
    ],
    targets: [
        .target(name: "SpoonjoyCore", resources: [.copy("Fixtures")]),
        .executableTarget(name: "SpoonjoyScenarioVerifier", dependencies: ["SpoonjoyCore"]),
        .testTarget(name: "SpoonjoyCoreTests", dependencies: ["SpoonjoyCore"])
    ]
)
