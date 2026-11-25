import Foundation
import OuroReins
import SpoonjoyCore

struct UnitSystemChoice: ReinsInput { let system: String }

extension SpoonjoyReinsShell {
    /// The units the cook picked, as the recipe page, cook mode and the shopping list keep them with `@AppStorage` under
    /// `UnitSystem.storageKey`: one choice on the device for all three. Headless, it lives in the kitchen folder under
    /// the same name, so it survives a relaunch and never leaks between journeys.
    var unitSystem: UnitSystem {
        guard let url = unitSystemURL else {
            return page.unitSystem
        }
        return UnitSystem(parsing: try? String(contentsOf: url, encoding: .utf8))
    }

    func pickUnits(_ system: UnitSystem) {
        guard let url = unitSystemURL else {
            page.unitSystem = system
            return
        }
        try? system.rawValue.write(to: url, atomically: true, encoding: .utf8)
    }

    private var unitSystemURL: URL? {
        kitchenDirectory?.appendingPathComponent(UnitSystem.storageKey)
    }

    /// The Units picker, `name`d for where it sits: under Serves on the recipe page (`RecipeServesPopover`), in cook
    /// mode's More menu beside Scale, and in the shopping list's menu.
    func pickUnitsAction(_ name: String, _ description: String) -> ReinsAction {
        ReinsAction(name, description, input: UnitSystemChoice.self) { [unowned self] input in
            self.pickUnits(UnitSystem(parsing: input.system))
        }.narrowed(.object(properties: ["system": .oneOf(UnitSystem.allCases.map(\.rawValue))], required: ["system"]))
    }

    /// The picker's state: the picked system's label and the labels it offers, in order.
    var unitsState: ReinsValue {
        ["picked": .string(unitSystem.label), "choices": .array(UnitSystem.allCases.map { .string($0.label) })]
    }
}
