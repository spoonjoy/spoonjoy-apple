import Foundation
import SwiftUI

#if canImport(AppIntents)
import AppIntents

/// The cook-mode step that is on screen. Cook mode annotates its user activity with this entity,
/// so "start this timer" resolves to the step the cook is looking at.
@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCookStepEntity: AppEntity {
    typealias DefaultQuery = SpoonjoyCookStepEntityQuery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cooking Step")
    static let defaultQuery = SpoonjoyCookStepEntityQuery()

    let id: String
    let recipeTitle: String
    let stepNumber: Int
    let stepTitle: String

    init() {
        id = "placeholder"
        recipeTitle = "Recipe"
        stepNumber = 1
        stepTitle = "Step"
    }

    init(step: CookModeOnScreenStep) {
        id = step.entityID
        recipeTitle = step.recipeTitle
        stepNumber = step.stepNumber
        stepTitle = step.stepTitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Step \(stepNumber): \(stepTitle)", subtitle: "\(recipeTitle)")
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoyCookStepEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [SpoonjoyCookStepEntity] {
        guard let step = CookModeSessionCenter.shared.onScreenStep(), identifiers.contains(step.entityID) else {
            return []
        }
        return [SpoonjoyCookStepEntity(step: step)]
    }

    @MainActor
    func suggestedEntities() async throws -> [SpoonjoyCookStepEntity] {
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
