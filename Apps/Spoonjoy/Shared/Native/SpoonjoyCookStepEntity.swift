import Foundation
import SpoonjoyCore
import SwiftUI

#if canImport(AppIntents)
import AppIntents
import CoreTransferable
import UniformTypeIdentifiers

/// The cook-mode step that is on screen. Cook mode annotates its user activity with this entity,
/// so "start this timer" resolves to the step the cook is looking at.
@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCookStepEntity: AppEntity, Transferable {
    typealias DefaultQuery = SpoonjoyCookStepEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cooking Step")
    static let defaultQuery = SpoonjoyCookStepEntityQuery()

    // Only the app needs the ids, so they stay plain members, hidden from Siri.
    let id: String
    let recipeID: String

    // What a person asks about the step on screen. Descriptions need the Siri AI SDK (27.3), behind ouro-ui-apple's fence.
    #if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)
    @Property(title: "Recipe", description: "The recipe being cooked.")
    var recipeTitle: String
    @Property(title: "Step number", description: "Which step this is, counting from 1.")
    var stepNumber: Int
    @Property(title: "Step", description: "What the step says to do.")
    var stepTitle: String
    @Property(title: "Link", description: "The recipe's page on spoonjoy.app.")
    var link: URL
    #else
    @Property(title: "Recipe")
    var recipeTitle: String
    @Property(title: "Step number")
    var stepNumber: Int
    @Property(title: "Step")
    var stepTitle: String
    @Property(title: "Link")
    var link: URL
    #endif

    var shareText: String { "\(recipeTitle), step \(stepNumber): \(stepTitle)\n\(link.absoluteString)" }

    init() {
        self.init(id: "placeholder", recipeID: "placeholder", recipeTitle: "Recipe", stepNumber: 1, stepTitle: "Step")
    }

    init(step: CookModeOnScreenStep) {
        self.init(id: step.entityID, recipeID: step.recipeID, recipeTitle: step.recipeTitle, stepNumber: step.stepNumber, stepTitle: step.stepTitle)
    }

    private init(id: String, recipeID: String, recipeTitle: String, stepNumber: Int, stepTitle: String) {
        self.id = id
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.stepNumber = stepNumber
        self.stepTitle = stepTitle
        link = NativeEntityWebLink.url(for: .recipeDetail(id: recipeID, presentation: .detail))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Step \(stepNumber): \(stepTitle)", subtitle: "\(recipeTitle)")
    }

    // Spelled inline with a literal content type, which Xcode 27.1's App Intents metadata records.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { entity in Data(entity.shareText.utf8) }
        ProxyRepresentation(exporting: \.link)
    }
}

/// Steps exist only while cook mode is open, so they are never indexed in Spotlight. The query lists the one on screen,
/// which is every step Siri can act on.
@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCookStepEntityQuery: EnumerableEntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [SpoonjoyCookStepEntity] {
        guard let step = CookModeSessionCenter.shared.onScreenStep(), identifiers.contains(step.entityID) else {
            return []
        }
        return [SpoonjoyCookStepEntity(step: step)]
    }

    @MainActor
    func suggestedEntities() async throws -> [SpoonjoyCookStepEntity] {
        try await allEntities()
    }

    @MainActor
    func allEntities() async throws -> [SpoonjoyCookStepEntity] {
        CookModeSessionCenter.shared.onScreenStep().map { [SpoonjoyCookStepEntity(step: $0)] } ?? []
    }
}
#endif

extension View {
    /// Tells the system which cook-mode step is on screen, so Siri can resolve "this step" to the entity.
    @ViewBuilder func cookModeStepAnnotation(_ step: CookModeOnScreenStep?) -> some View {
#if canImport(AppIntents)
        if #available(iOS 27.0, macOS 27.0, *), let step {
            userActivity("app.spoonjoy.cook-step") { activity in
                activity.title = "Step \(step.stepNumber): \(step.stepTitle)"
                activity.appEntityIdentifier = EntityIdentifier(for: SpoonjoyCookStepEntity(step: step))
            }
        } else {
            self
        }
#else
        self
#endif
    }
}
