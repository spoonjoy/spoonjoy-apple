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
        // Ouro Reins: the phone shell driven headless with `ls` and `do`, over the fixture kitchen, with the network blocked.
        .executable(name: "spoonjoy-reins", targets: ["spoonjoy-reins"])
    ],
    // ouro-ui-apple, pinned exactly: Ouro HX (the shared Reduce Motion crossfade, haptic moments and cookbook colour
    // tokens), which the Xcode project pins the same way for the app targets; Ouro Reins (SpoonjoyReins, its journeys
    // and spoonjoy-reins); and, for tests only, the X-ray's claim set and checker (OuroAXTesting, ouro-ax-xray). Bump the
    // pin and config/xray-expected.json together. The pin is a release (`exact:`) or, until the release that carries a
    // change is tagged, the merge commit on ouro-ui-apple's main (`revision:`); both are exact.
    dependencies: [
        // v0.3.4: Ouro Reins, and Ouro Feel for the UI tests' feel checks, with its in-app recorder (a push or a sheet
        // filmed frame by frame) and a walk of the whole app that reads tab switches, submenus and popovers right.
        .package(url: "https://github.com/ourostack/ouro-ui-apple.git", exact: "0.3.4")
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
        // Ouro Reins: Spoonjoy's shell as nodes, the fixture kitchen, and the headless journeys.
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
