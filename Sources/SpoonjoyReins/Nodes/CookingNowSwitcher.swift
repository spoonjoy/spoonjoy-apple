import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    /// The tab bar's Cooking now switcher (CookingNowAccessory): off the Kitchen root, where the page's own strip is
    /// the switcher, it leads with the newest recipe on the stove, and its Resume goes back to that recipe's step.
    func carryCookingNowSwitcher(on tabs: inout ReinsNode) {
        let entries = cookingNowEntries
        guard shell.showsCookingNowSwitcher(hasCooks: !entries.isEmpty), let lead = CookingNowBoard.switcherLead(entries) else {
            return
        }
        if case .object(var state) = tabs.state {
            state["switcher"] = ["lead": Self.cookingNowRow(lead), "count": .number(Double(entries.count))]
            tabs.state = .object(state)
        }
        tabs.lends.append(ReinsAction("switcherResume", "Go back to \(lead.title)") { [unowned self] in self.startCooking(lead.recipeID) })
    }
}
