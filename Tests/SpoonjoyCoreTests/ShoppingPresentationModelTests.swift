import Testing
@testable import SpoonjoyCore

@Suite("Shopping market presentation")
struct ShoppingPresentationModelTests {
    @Test("checkedAt is canonical legacy checked state even when checked is false")
    func effectiveCheckedStateIncludesLegacyCheckedAt() {
        let legacy = item(
            "legacy-checked",
            "Legacy basket item",
            category: "pantry",
            checkedAt: "2026-08-21T20:00:00.000Z",
            sort: 0
        )

        #expect(legacy.isEffectivelyChecked)
    }

    @Test("starts in All and exposes Need Basket All counts")
    func startsInAllWithCounts() throws {
        let state = try mixedState()
        let model = ShoppingPresentationModel(shoppingList: state)

        #expect(model.mode == .all)
        #expect(model.modeOptions.map(\.label) == ["Need 3", "Basket 1", "All 4"])
        #expect(model.visibleItems.count == 4)
    }

    @Test("modes retain checked rows in ordinary market categories")
    func modesAndOrdinaryCategories() throws {
        let state = try mixedState()
        let need = ShoppingPresentationModel(shoppingList: state, mode: .need)
        let basket = ShoppingPresentationModel(shoppingList: state, mode: .basket)

        #expect(need.visibleItems.allSatisfy { !$0.item.checked })
        #expect(basket.visibleItems.allSatisfy { $0.item.checked })
        #expect(basket.sections.map(\.title) == ["Dairy"])
    }

    @Test("market rank is fixed and source order stays stable within a category")
    func fixedRankAndStableSourceOrder() throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let state = replacingItems(in: baseline, with: [
            item("pantry-first", "Rice", category: "pantry", sort: 30),
            item("produce-first", "Lemon", category: "produce", sort: 90),
            item("produce-second", "Basil", category: "produce", sort: 10),
            item("protein-first", "Salmon", category: "protein", sort: 0),
        ])
        let model = ShoppingPresentationModel(shoppingList: state)

        #expect(model.sections.map(\.title) == ["Produce", "Protein", "Pantry"])
        #expect(model.sections[0].items.map(\.item.id) == ["produce-first", "produce-second"])
    }

    @Test("invalid category resets to All and name fallback matches web affordances")
    func invalidCategoryAndNameFallback() throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let state = replacingItems(in: baseline, with: [
            item("fallback-produce", "Fresh basil", category: "mystery", sort: 0),
            item("explicit-dairy", "Not cheese", category: "dairy", sort: 1),
        ])
        let model = ShoppingPresentationModel(
            shoppingList: state,
            mode: .all,
            activeCategory: "Frozen"
        )

        #expect(model.activeCategory == "all")
        #expect(model.categoryOptions == ["all", "Produce", "Dairy"])
        #expect(model.visibleItems.map(\.categoryLabel) == ["Produce", "Dairy"])
    }

    @Test("active category filters rows and Basket empty copy matches the web market")
    func activeCategoryAndEmptyBasketCopy() throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let state = replacingItems(in: baseline, with: [
            item("produce", "Basil", category: "produce", sort: 0),
            item("pantry", "Rice", category: "pantry", sort: 1),
        ])

        let produce = ShoppingPresentationModel(
            shoppingList: state,
            activeCategory: "Produce"
        )
        #expect(produce.visibleItems.map(\.item.id) == ["produce"])

        let basket = ShoppingPresentationModel(shoppingList: state, mode: .basket)
        #expect(basket.visibleItems.isEmpty)
        #expect(basket.emptyTitle == "Nothing in the basket yet")
    }

    @Test("all-complete list is empty only in Need")
    func allCompleteModeCopy() throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let completed = replacingItems(in: baseline, with: baseline.receiptItems.map { source in
            item(source.id, source.name, category: source.categoryKey, checked: true, sort: source.sortIndex)
        })

        let need = ShoppingPresentationModel(shoppingList: completed, mode: .need)
        let basket = ShoppingPresentationModel(shoppingList: completed, mode: .basket)
        let all = ShoppingPresentationModel(shoppingList: completed)

        #expect(need.visibleItems.isEmpty)
        #expect(need.emptyTitle == "Nothing left in this view")
        #expect(basket.visibleItems.count == completed.receiptItems.count)
        #expect(all.visibleItems.count == completed.receiptItems.count)
    }

    @Test("empty model identifiers and explicit icons are observable")
    func emptyIdentifiersAndExplicitIcons() throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let empty = ShoppingPresentationModel(shoppingList: replacingItems(in: baseline, with: []))
        #expect(empty.emptyTitle == "Your shopping list is empty")
        #expect(empty.emptyMessage == "Add items manually or add all ingredients from a recipe.")

        let explicit = ShoppingPresentationModel(shoppingList: replacingItems(in: baseline, with: [
            ShoppingListItem(
                id: "explicit-icon",
                name: "mystery ingredient",
                quantity: nil,
                unit: nil,
                checked: false,
                checkedAt: nil,
                deletedAt: nil,
                categoryKey: "other",
                iconKey: "leaf",
                sortIndex: 0,
                updatedAt: baseline.updatedAt
            )
        ]))
        #expect(explicit.visibleItems.first?.id == "explicit-icon")
        #expect(explicit.visibleItems.first?.iconKey == "leaf")
        #expect(explicit.sections.first?.id == "Other")
    }

    private func replacingItems(in state: ShoppingListState, with items: [ShoppingListItem]) -> ShoppingListState {
        ShoppingListState(
            id: state.id,
            chef: state.chef,
            items: items,
            nextCursor: state.nextCursor,
            updatedAt: state.updatedAt
        )
    }

    private func mixedState() throws -> ShoppingListState {
        let baseline = try ShoppingListState.decodeFromBundle()
        return replacingItems(
            in: baseline,
            with: baseline.receiptItems + [
                item("basket-yogurt", "Yogurt", category: "dairy", checked: true, sort: 4)
            ]
        )
    }

    private func item(
        _ id: String,
        _ name: String,
        category: String?,
        checked: Bool = false,
        checkedAt: String? = nil,
        sort: Int
    ) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: nil,
            unit: nil,
            checked: checked,
            checkedAt: checkedAt ?? (checked ? "2026-08-21T20:00:00.000Z" : nil),
            deletedAt: nil,
            categoryKey: category,
            iconKey: nil,
            sortIndex: sort,
            updatedAt: "2026-08-21T20:00:00.000Z"
        )
    }
}
