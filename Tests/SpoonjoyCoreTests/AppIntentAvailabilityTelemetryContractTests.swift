import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("App Intent availability and telemetry contracts")
struct AppIntentAvailabilityTelemetryContractTests {
    @Test("App Intents stay iOS 27/macOS 27 gated with explicit bootstrap-only lower targets")
    func appIntentsStayIOS27MacOS27Gated() throws {
        let appIntentFiles = [
            "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
            "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
            "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift",
            "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift",
            "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
            "Apps/Spoonjoy/Shared/Native/SpoonjoySettingsEntities.swift",
            "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift"
        ]
        var failures: [String] = []

        for relativePath in appIntentFiles {
            let source = uncommentedSwift(try readRepoFile(relativePath))
            failures.append(contentsOf: availabilityFailures(in: source, relativePath: relativePath))
        }

        let appIntents = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift"))
        failures.append(contentsOf: missingTokens(
            in: appIntents,
            relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            tokens: [
                "#if canImport(AppIntents)",
                "import AppIntents",
                "@available(iOS 27.0, macOS 27.0, *)"
            ]
        ))

        let project = try readRepoFile("Spoonjoy.xcodeproj/project.pbxproj")
        failures.append(contentsOf: minimumOccurrenceFailures(
            in: project,
            relativePath: "Spoonjoy.xcodeproj/project.pbxproj",
            occurrences: [
                "IPHONEOS_DEPLOYMENT_TARGET = 27.0;": 2,
                "MACOSX_DEPLOYMENT_TARGET = 27.0;": 2,
                "IPHONEOS_DEPLOYMENT_TARGET = 26.5;": 1,
                "MACOSX_DEPLOYMENT_TARGET = 26.2;": 1
            ]
        ))

        let justification = try readRepoFile("docs/native-justification.md")
        failures.append(contentsOf: missingTokens(
            in: justification,
            relativePath: "docs/native-justification.md",
            tokens: [
                "Product baseline remains iOS 27 and macOS 27 forward.",
                "`BootstrapDebug` may use `IPHONEOS_DEPLOYMENT_TARGET = 26.5`",
                "`BootstrapDebug` must use `MACOSX_DEPLOYMENT_TARGET = 26.2`"
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("App Intent outputs are telemetry-addressable from the core action layer")
    func appIntentOutputsAreTelemetryAddressableFromCoreActionLayer() throws {
        var failures: [String] = []
        let api = uncommentedSwift(try readRepoFile("Sources/SpoonjoyCore/API/NativeAPIRequests.swift"))
        let action = uncommentedSwift(try readRepoFile("Sources/SpoonjoyCore/Native/NativeIntentAction.swift"))
        let metadata = uncommentedSwift(try readRepoFile("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift"))
        let report = uncommentedSwift(try readRepoFile("Sources/SpoonjoyCore/Native/ScenarioReport.swift"))
        let scenarioVerifier = uncommentedSwift(try readRepoFile("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"))
        let appIntents = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift"))

        failures.append(contentsOf: missingTokens(
            in: api,
            relativePath: "Sources/SpoonjoyCore/API/NativeAPIRequests.swift",
            tokens: [
                #"case appIntentCompleted = "app_intent_completed""#,
                #"case appIntentFailed = "app_intent_failed""#,
                "public let intentName: String?",
                "public let intentActionKind: String?",
                "public let intentOutcome: String?",
                "public let intentReturnsValue: Bool?",
                "public let intentQueuedMutationID: String?",
                #"put(event.intentName, in: &body, key: "intentName")"#,
                #"put(event.intentActionKind, in: &body, key: "intentActionKind")"#,
                #"put(event.intentOutcome, in: &body, key: "intentOutcome")"#
            ]
        ))
        failures.append(contentsOf: missingTokens(
            in: action,
            relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
            tokens: [
                "public struct NativeIntentTelemetryDescriptor",
                "public enum NativeIntentTelemetryOutcome",
                "public var telemetryActionKind: String",
                "public func telemetryDescriptor(intentName: String",
                ".appIntentCompleted",
                ".appIntentFailed"
            ]
        ))
        failures.append(contentsOf: missingTokens(
            in: metadata,
            relativePath: "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
            tokens: [
                "public let appIntentTelemetryEvents: [String]",
                #"appIntentTelemetryEvents: ["#,
                #""app_intent_completed""#,
                #""app_intent_failed""#
            ]
        ))
        failures.append(contentsOf: missingTokens(
            in: report,
            relativePath: "Sources/SpoonjoyCore/Native/ScenarioReport.swift",
            tokens: [
                "public let appIntentTelemetryEvents: [String]",
                "appIntentTelemetryEvents: [String]"
            ]
        ))
        failures.append(contentsOf: missingTokens(
            in: scenarioVerifier,
            relativePath: "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
            tokens: [
                "appIntentTelemetryEvents: metadata.appIntentTelemetryEvents",
                "App Intent output telemetry"
            ]
        ))
        failures.append(contentsOf: missingTokens(
            in: appIntents,
            relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            tokens: [
                "struct SpoonjoyIntentTelemetry",
                "static func recordCompleted",
                "static func recordFailed",
                "NativeTelemetryRequests.recordEvent",
                #"SpoonjoyIntentTelemetry.recordCompleted(action, intentName: "OpenRecipeIntent", returnsValue: false)"#,
                #"SpoonjoyIntentTelemetry.recordCompleted(action, intentName: "SearchSpoonjoyIntent", returnsValue: false)"#,
                #"SpoonjoyIntentTelemetry.recordCompleted(share, intentName: "ShareShoppingListIntent", returnsValue: true)"#,
                #"SpoonjoyIntentTelemetry.recordCompleted(action, intentName: "SubmitCaptureImportIntent", returnsValue: false)"#
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("native intent telemetry descriptors preserve route queue share and failure outputs")
    func nativeIntentTelemetryDescriptorsPreserveRouteQueueShareAndFailureOutputs() throws {
        let resolver = NativeIntentActionResolver()
        let metadata = NativeTelemetryAppMetadata(platform: "ios", appVersion: "1.0", buildNumber: "27")

        let openAction = try resolver.openRecipe(recipeID: "recipe_lemon_pantry_pasta")
        let openEvent = openAction
            .telemetryDescriptor(intentName: "OpenRecipeIntent", returnsValue: false)
            .telemetryEvent(environment: "production", metadata: metadata)
        #expect(openEvent.name == .appIntentCompleted)
        #expect(openEvent.stage == "app_intent.OpenRecipeIntent.open-route")
        #expect(openEvent.route == openAction.route.stateIdentifier)
        #expect(openEvent.intentName == "OpenRecipeIntent")
        #expect(openEvent.intentActionKind == "open-route")
        #expect(openEvent.intentOutcome == "completed")
        #expect(openEvent.intentReturnsValue == false)
        #expect(openEvent.intentOpensURL == openAction.url.absoluteString)

        let shoppingAction = try resolver.addShoppingListItem(
            name: "Preserved lemons",
            quantity: 2,
            unit: "jar",
            createdAt: "2026-07-10T16:45:00.000Z"
        )
        let shoppingEvent = shoppingAction
            .telemetryDescriptor(intentName: "AddShoppingListItemIntent", returnsValue: false)
            .telemetryEvent(environment: "production", metadata: metadata)
        #expect(shoppingEvent.intentQueuedMutationID == "intent-shopping-add-preserved-lemons-2026-07-10T16-45-00-000Z")
        #expect(shoppingEvent.intentQueuedMutationKind == NativeQueuedMutationKind.shoppingAddItem.rawValue)

        let shoppingList = ShoppingListEntityDescriptor(
            id: "shopping-list-production-chef_ari",
            scope: ShoppingEntityScope(accountID: "chef_ari", environment: .production),
            title: "Shopping List",
            subtitle: "2 active items",
            disambiguationLabel: "Ari's Shopping List",
            route: .shoppingList,
            activeItemCount: 2,
            transferValue: ShoppingEntityTransferValue(
                kind: .shoppingList,
                rawResourceID: "shopping-list",
                title: "Shopping List",
                routeIdentifier: AppRoute.shoppingList.stateIdentifier,
                publicURL: nil,
                privateTransferValue: "schema=app.spoonjoy.shopping-entity.v1;domain=shopping-list;title=Shopping List",
                userVisibleSummary: "2 active items"
            )
        )
        let share = try resolver.shareShoppingList(shoppingList: shoppingList)
        let shareEvent = share
            .telemetryDescriptor(intentName: "ShareShoppingListIntent", returnsValue: true)
            .telemetryEvent(environment: "production", metadata: metadata)
        #expect(shareEvent.intentActionKind == "share.shopping-list.private-transfer")
        #expect(shareEvent.intentReturnsValue == true)
        #expect(shareEvent.intentOpensURL == nil)

        let failureEvent = NativeIntentTelemetryDescriptor
            .failed(intentName: "OpenRecipeIntent", error: NativeIntentActionError.unresolvedRecipeEntity)
            .telemetryEvent(environment: "production", metadata: metadata)
        #expect(failureEvent.name == .appIntentFailed)
        #expect(failureEvent.stage == "app_intent.OpenRecipeIntent.perform")
        #expect(failureEvent.intentOutcome == "failed")
        #expect(failureEvent.errorType?.contains("NativeIntentActionError") == true)
    }
}

private func availabilityFailures(in source: String, relativePath: String) -> [String] {
    let lines = source.components(separatedBy: .newlines)
    var failures: [String] = []
    let declarationPattern = #"\b(?:struct|enum)\s+[A-Za-z0-9_]+\s*:\s*[^{"\n]*(?:AppIntent|AppEntity|AppEnum|AppShortcutsProvider|IndexedEntity)\b"#

    for index in lines.indices {
        let line = lines[index]
        guard !line.contains("\"") else {
            continue
        }
        guard line.range(of: declarationPattern, options: .regularExpression) != nil else {
            continue
        }
        let availabilityWindowStart = max(0, index - 3)
        let availabilityWindow = lines[availabilityWindowStart...index].joined(separator: "\n")
        if !availabilityWindow.contains("@available(iOS 27.0, macOS 27.0, *)") {
            failures.append("\(relativePath):\(index + 1) missing iOS 27/macOS 27 availability gate")
        }
    }

    if source.contains("@available(iOS 26") || source.contains("@available(macOS 26") {
        failures.append("\(relativePath) contains unsupported AppIntents iOS/macOS 26 availability")
    }

    return failures
}

private func minimumOccurrenceFailures(in source: String, relativePath: String, occurrences: [String: Int]) -> [String] {
    occurrences.flatMap { token, expectedCount -> [String] in
        let actualCount = source.components(separatedBy: token).count - 1
        guard actualCount < expectedCount else {
            return []
        }
        return ["\(relativePath) expected at least \(expectedCount) occurrences of \(token), found \(actualCount)"]
    }
}

private func missingTokens(in source: String, relativePath: String, tokens: [String]) -> [String] {
    tokens.compactMap { token in
        source.contains(token) ? nil : "\(relativePath) missing \(token)"
    }
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw AppIntentAvailabilityTelemetryContractTestError.missingFile(relativePath)
    }
    return try String(contentsOf: url, encoding: .utf8)
}

private func uncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: .regularExpression)
}

private enum AppIntentAvailabilityTelemetryContractTestError: Error {
    case missingFile(String)
}
