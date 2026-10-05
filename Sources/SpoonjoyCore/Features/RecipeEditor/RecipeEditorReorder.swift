import Foundation

/// Why a step or ingredient did not move.
public enum RecipeEditorMoveOutcome: Equatable, Sendable {
    case moved
    /// The move would not change the order, for example moving the first step up.
    case unchanged
    /// The move would put a step ahead of a step whose output it uses (or behind a step that uses its output).
    case blocked(String)
}

extension RecipeEditorDraft {
    /// Moves a step by `offset` positions (negative moves it earlier), then renumbers every step.
    /// Like the web editor, a step cannot move past a step it depends on through "uses output from".
    @discardableResult
    public mutating func moveStep(id: String, by offset: Int) -> RecipeEditorMoveOutcome {
        guard let index = steps.firstIndex(where: { $0.id == id }) else {
            return .unchanged
        }
        let target = index + offset
        guard steps.indices.contains(target), target != index else {
            return .unchanged
        }
        return moveSteps(fromOffsets: IndexSet(integer: index), toOffset: target > index ? target + 1 : target)
    }

    /// Moves steps the way SwiftUI's `onMove` reports them, then renumbers every step.
    @discardableResult
    public mutating func moveSteps(fromOffsets source: IndexSet, toOffset destination: Int) -> RecipeEditorMoveOutcome {
        var reordered = steps
        reordered.moveElements(fromOffsets: source, toOffset: destination)
        guard reordered.map(\.id) != steps.map(\.id) else {
            return .unchanged
        }
        if let message = Self.dependencyViolation(in: reordered) {
            return .blocked(message)
        }
        steps = reordered
        renumberStepsPreservingOutputIdentities()
        return .moved
    }

    /// Moves an ingredient by `offset` positions inside its step.
    @discardableResult
    public mutating func moveIngredient(id: String, inStep stepID: String, by offset: Int) -> RecipeEditorMoveOutcome {
        guard let stepIndex = steps.firstIndex(where: { $0.id == stepID }),
              let index = steps[stepIndex].ingredients.firstIndex(where: { $0.id == id }) else {
            return .unchanged
        }
        let target = index + offset
        guard steps[stepIndex].ingredients.indices.contains(target), target != index else {
            return .unchanged
        }
        steps[stepIndex].ingredients.moveElements(fromOffsets: IndexSet(integer: index), toOffset: target > index ? target + 1 : target)
        return .moved
    }

    /// A step may only use the output of steps that come before it. Returns a sentence naming the first
    /// violation in `candidate` order, or nil when every dependency still points backwards.
    private static func dependencyViolation(in candidate: [RecipeEditorStepDraft]) -> String? {
        var position: [Int: Int] = [:]
        for (index, step) in candidate.enumerated() {
            position[step.stepNum] = index
        }
        for (index, step) in candidate.enumerated() {
            for outputStepNum in step.outputStepNums {
                guard let outputIndex = position[outputStepNum], outputIndex >= index else {
                    continue
                }
                return "Step \(outputStepNum) feeds step \(step.stepNum), so step \(outputStepNum) has to stay before it. Clear \"Uses Output From\" first to move it."
            }
        }
        return nil
    }
}

extension Array {
    /// `Array.move(fromOffsets:toOffset:)` lives in SwiftUI; this is the same operation for Core.
    mutating func moveElements(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { self[$0] }
        let before = source.filter { $0 < destination }.count
        for index in source.reversed() {
            remove(at: index)
        }
        insert(contentsOf: moving, at: destination - before)
    }
}
