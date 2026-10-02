import Foundation

/// Where an ingredient came from. A source's share of a reminder's quantity is replaced, never added twice.
public struct ReminderSource: Equatable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }

    public static let shoppingList = ReminderSource(id: "shopping-list", label: "Shopping list")

    static let existingListEntry = ReminderSource(id: "existing", label: "on your list")
}

public struct ReminderIncomingIngredient: Equatable, Sendable {
    public let name: String
    public let quantity: Double?
    public let unit: String?

    public init(name: String, quantity: Double?, unit: String?) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    public static func fromRecipe(_ ingredients: [RecipeIngredient], scaleFactor: Double) -> [ReminderIncomingIngredient] {
        let scale = scaleFactor > 0 ? scaleFactor : 1
        return ingredients.map { ingredient in
            ReminderIncomingIngredient(
                name: ingredient.name,
                quantity: ingredient.quantity > 0 ? ingredient.quantity * scale : nil,
                unit: ingredient.unit
            )
        }
    }

    /// Open, undeleted shopping items. Items already checked off are not sent.
    public static func fromShoppingItems(_ items: [ShoppingListItem]) -> [ReminderIncomingIngredient] {
        items
            .filter { $0.deletedAt == nil && !$0.isEffectivelyChecked }
            .map { item in
                ReminderIncomingIngredient(
                    name: item.name,
                    quantity: item.quantity.flatMap { $0 > 0 ? $0 : nil },
                    unit: item.unit
                )
            }
    }
}

/// A reminder already in the chosen list, as read from EventKit.
public struct ReminderExisting: Equatable, Sendable {
    public let id: String
    public let title: String
    public let notes: String?
    public let isCompleted: Bool

    public init(id: String, title: String, notes: String?, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
    }
}

public enum ReminderOperation: Equatable, Sendable {
    case create(title: String, notes: String)
    case update(id: String, title: String, notes: String, reopen: Bool)
    case unchanged(id: String)
}

public struct ReminderSyncSummary: Equatable, Sendable {
    public let added: Int
    public let updated: Int
    public let reopened: Int
    public let unchanged: Int

    public init(added: Int, updated: Int, reopened: Int, unchanged: Int) {
        self.added = added
        self.updated = updated
        self.reopened = reopened
        self.unchanged = unchanged
    }

    public var totalChanged: Int {
        added + updated + reopened
    }

    public func message(listName: String) -> String {
        if totalChanged == 0 {
            return unchanged == 0
                ? "No ingredients to send."
                : "Everything was already in \(listName). Nothing changed."
        }
        let parts = [("Added", added), ("updated", updated), ("reopened", reopened)]
            .filter { $0.1 > 0 }
            .map { "\($0.0) \($0.1)" }
            .joined(separator: ", ")
        var message = "\(parts) in \(listName)."
        if unchanged > 0 {
            message += unchanged == 1 ? " 1 was already there." : " \(unchanged) were already there."
        }
        return message
    }
}

public struct ReminderSyncPlan: Equatable, Sendable {
    public let operations: [ReminderOperation]
    public let summary: ReminderSyncSummary

    public var isNoOp: Bool {
        summary.totalChanged == 0
    }
}

public struct ReminderListSummary: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    /// An existing Groceries list when one can be identified by name, otherwise nil.
    public static func preferredDefault(in lists: [ReminderListSummary]) -> ReminderListSummary? {
        let exactNames: Set<String> = ["groceries", "grocery", "grocery list", "grocery shopping"]
        return lists.first { exactNames.contains($0.title.lowercased()) }
            ?? lists.first { $0.title.lowercased().contains("grocer") }
    }
}

/// Decides, without touching EventKit, what to create, update or reopen so that no ingredient is listed twice.
public enum ReminderSyncPlanner {
    public static func plan(
        incoming: [ReminderIncomingIngredient],
        existing: [ReminderExisting],
        source: ReminderSource
    ) -> ReminderSyncPlan {
        var operations: [ReminderOperation] = []
        var added = 0, updated = 0, reopened = 0, unchanged = 0

        for group in groups(from: incoming) {
            guard let match = bestMatch(forKey: group.key, in: existing) else {
                let share = Share(source: source, quantities: group.quantities)
                operations.append(.create(title: title(name: group.displayName, shares: [share]), notes: notesText(userLines: [], shares: [share])))
                added += 1
                continue
            }

            let notes = parseNotes(match.notes)
            let name = ReminderIngredientText.parse(match.title).name
            let displayName = name.isEmpty ? group.displayName : name

            if match.isCompleted {
                let share = Share(source: source, quantities: group.quantities)
                operations.append(.update(
                    id: match.id,
                    title: title(name: displayName, shares: [share]),
                    notes: notesText(userLines: notes.userLines, shares: [share]),
                    reopen: true
                ))
                reopened += 1
                continue
            }

            var shares = notes.shares
            if shares.isEmpty {
                let typed = ReminderIngredientText.parse(match.title).quantity
                if typed.value != nil {
                    shares = [Share(source: .existingListEntry, quantities: [typed])]
                }
            }
            let newShare = Share(source: source, quantities: group.quantities)
            if let index = shares.firstIndex(where: { $0.source.id == source.id }) {
                shares[index] = newShare
            } else if group.quantities.isEmpty {
                operations.append(.unchanged(id: match.id))
                unchanged += 1
                continue
            } else {
                shares.append(newShare)
            }

            let newTitle = title(name: displayName, shares: shares)
            let newNotes = notesText(userLines: notes.userLines, shares: shares)
            let oldNotes = match.notes ?? ""
            if newTitle == match.title, newNotes == oldNotes {
                operations.append(.unchanged(id: match.id))
                unchanged += 1
            } else {
                operations.append(.update(id: match.id, title: newTitle, notes: newNotes, reopen: false))
                updated += 1
            }
        }

        return ReminderSyncPlan(
            operations: operations,
            summary: ReminderSyncSummary(added: added, updated: updated, reopened: reopened, unchanged: unchanged)
        )
    }

    // MARK: Grouping and matching

    private struct Group {
        let key: String
        let displayName: String
        var quantities: [ReminderQuantity]
    }

    private static func groups(from incoming: [ReminderIncomingIngredient]) -> [Group] {
        var ordered: [Group] = []
        for ingredient in incoming {
            let key = ReminderIngredientText.key(for: ingredient.name)
            guard !key.isEmpty else {
                continue
            }
            let quantity = ReminderQuantity(value: ingredient.quantity, unit: ingredient.unit)
            let index: Int
            if let found = ordered.firstIndex(where: { $0.key == key }) {
                index = found
            } else {
                let display = ingredient.name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                ordered.append(Group(key: key, displayName: display, quantities: []))
                index = ordered.count - 1
            }
            if quantity.value != nil {
                ordered[index].quantities.append(quantity)
            }
        }
        return ordered.map { group in
            Group(key: group.key, displayName: group.displayName, quantities: combine(group.quantities))
        }
    }

    private static func bestMatch(forKey key: String, in existing: [ReminderExisting]) -> ReminderExisting? {
        let matches = existing.filter { ReminderIngredientText.key(for: ReminderIngredientText.parse($0.title).name) == key }
        return matches.first { !$0.isCompleted } ?? matches.first
    }

    // MARK: Shares, notes and titles

    private struct Share {
        let source: ReminderSource
        let quantities: [ReminderQuantity]
    }

    private static let shareLine = #"^(.*) · (.*) \[sj:([^\]]+)\]$"#

    private static func parseNotes(_ notes: String?) -> (userLines: [String], shares: [Share]) {
        var userLines: [String] = []
        var shares: [Share] = []
        for line in (notes ?? "").split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            guard let match = ReminderIngredientText.firstMatch(shareLine, in: line) else {
                userLines.append(line)
                continue
            }
            let quantities = match[1].components(separatedBy: " + ").compactMap(ReminderQuantity.parse)
            shares.append(Share(source: ReminderSource(id: match[3], label: match[2]), quantities: quantities))
        }
        return (userLines, shares)
    }

    private static func notesText(userLines: [String], shares: [Share]) -> String {
        let lines = shares.map { share in
            let text = share.quantities.map(\.displayText).joined(separator: " + ")
            return "\(text.isEmpty ? "some" : text) · \(share.source.label) [sj:\(share.source.id)]"
        }
        return (userLines + lines).joined(separator: "\n")
    }

    /// The title total. Every source stays listed in the notes; only this total follows the rule below.
    ///
    /// The shopping list is an aggregate: Spoonjoy's shopping items carry no recipe provenance, so the list may
    /// already include what a recipe share counted. The two must not stack. Per unit, the total is
    /// `max(shopping-list share, sum of the recipe shares)`, plus the hand-typed `existing` share, which
    /// never came from Spoonjoy. Over-counting is the failure to avoid; under-counting can only happen when
    /// recipes and the list hold different amounts of the same food, and the notes still show every source.
    private static func title(name: String, shares: [Share]) -> String {
        let typed = shares.filter { $0.source.id == ReminderSource.existingListEntry.id }
        let list = shares.filter { $0.source.id == ReminderSource.shoppingList.id }
        let recipes = shares.filter { $0.source.id != ReminderSource.existingListEntry.id && $0.source.id != ReminderSource.shoppingList.id }
        let listTotal = combine(list.flatMap(\.quantities))
        let recipeTotal = combine(recipes.flatMap(\.quantities))

        var order: [String?] = []
        var larger: [String?: Double] = [:]
        for quantity in listTotal + recipeTotal {
            guard let value = quantity.value else {
                continue
            }
            if larger[quantity.unit] == nil {
                order.append(quantity.unit)
            }
            larger[quantity.unit] = max(larger[quantity.unit] ?? 0, value)
        }
        let aggregate = order.map { ReminderQuantity(value: larger[$0], unit: $0) }
        let total = combine(typed.flatMap(\.quantities) + aggregate).map(\.displayText).joined(separator: " + ")
        return total.isEmpty ? name : "\(name) (\(total))"
    }

    /// Adds quantities that share a unit. Different units stay separate because Spoonjoy does not convert between them.
    private static func combine(_ quantities: [ReminderQuantity]) -> [ReminderQuantity] {
        var order: [String?] = []
        var totals: [String?: Double] = [:]
        for quantity in quantities {
            if let value = quantity.value {
                if totals[quantity.unit] == nil {
                    order.append(quantity.unit)
                }
                totals[quantity.unit, default: 0] += value
            }
        }
        return order.map { ReminderQuantity(value: totals[$0], unit: $0) }
    }
}
