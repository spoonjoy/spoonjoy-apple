import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("A held change holds only what depends on it")
struct NativeShoppingHoldTests {
    private static let configuration = APIClientConfiguration.spoonjoyProduction
    private static let now = Date(timeIntervalSince1970: 1_781_600_000)
    private static let scope = NativeSyncExecutionScope(expectedAccountID: "chef_ari", environment: .production)
    private static let createdAt = "2026-10-09T08:00:00.000Z"

    @Test("a shopping change the server turns down holds only that item, and clearing waits for it")
    func turnedDownShoppingChangeHoldsOnlyItsItem() async throws {
        let queue = try NativeMutationQueue(mutations: [
            .shoppingCheckItem(itemID: "item_milk", checked: true, clientMutationID: "cm_milk", createdAt: Self.createdAt),
            .shoppingCheckItem(itemID: "item_bread", checked: true, clientMutationID: "cm_bread", createdAt: Self.createdAt),
            .shoppingAddItem(name: "eggs", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: "cm_eggs", createdAt: Self.createdAt),
            .shoppingCheckItem(itemID: "item_milk", checked: false, clientMutationID: "cm_milk_again", createdAt: Self.createdAt),
            .shoppingClearCompleted(clientMutationID: "cm_clear", createdAt: Self.createdAt)
        ])
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: queue)
        let transport = HoldTransport(turnedDown: ["cm_milk"])

        let report = try await NativeSyncEngine(store: store, transport: transport, clock: { Self.now })
            .bootstrapAndDrain(configuration: Self.configuration, trigger: .launch, scope: Self.scope)

        #expect(await transport.sentClientMutationIDs() == ["cm_milk", "cm_bread", "cm_eggs"])
        #expect(report.conflicts.map(\.clientMutationID) == ["cm_milk"])
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_milk", "cm_milk_again", "cm_clear"])
    }

    @Test("while clearing the list is held, the shopping changes queued after it wait, so the clear cannot wipe them")
    func heldClearHoldsLaterShoppingChanges() async throws {
        let queue = try NativeMutationQueue(mutations: [
            .shoppingCheckItem(itemID: "item_bread", checked: true, clientMutationID: "cm_bread", createdAt: Self.createdAt),
            .shoppingClearCompleted(clientMutationID: "cm_clear", createdAt: Self.createdAt),
            .shoppingAddItem(name: "eggs", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: "cm_eggs", createdAt: Self.createdAt),
            .shoppingCheckItem(itemID: "item_milk", checked: true, clientMutationID: "cm_milk", createdAt: Self.createdAt),
            .recipeUpdate(recipeID: "recipe_soup", clientMutationID: "cm_soup", title: "Soup", description: nil, servings: nil, createdAt: Self.createdAt)
        ])
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: queue)
        let transport = HoldTransport(turnedDown: ["cm_clear"])

        _ = try await NativeSyncEngine(store: store, transport: transport, clock: { Self.now })
            .bootstrapAndDrain(configuration: Self.configuration, trigger: .launch, scope: Self.scope)

        #expect(await transport.sentClientMutationIDs() == ["cm_bread", "cm_clear", "cm_soup"])
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_clear", "cm_eggs", "cm_milk"])
    }

    @Test("a change to an item added on this device waits for the add, and other items go ahead")
    func changesToALocalItemWaitForItsAdd() async throws {
        let queue = try NativeMutationQueue(mutations: [
            .shoppingAddItem(name: "milk", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: "cm_add_milk", createdAt: Self.createdAt),
            .shoppingCheckItem(itemID: "item_local_cm_add_milk", checked: true, clientMutationID: "cm_check_milk", createdAt: Self.createdAt),
            .shoppingAddFromRecipe(recipeID: "recipe_soup", scaleFactor: 1, clientMutationID: "cm_add_soup", createdAt: Self.createdAt),
            .shoppingDeleteItem(itemID: "item_local_cm_add_soup-ingredient-2", clientMutationID: "cm_drop_onion", createdAt: Self.createdAt)
        ])
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: queue)
        let transport = HoldTransport(turnedDown: ["cm_add_milk"])

        _ = try await NativeSyncEngine(store: store, transport: transport, clock: { Self.now })
            .bootstrapAndDrain(configuration: Self.configuration, trigger: .launch, scope: Self.scope)

        #expect(await transport.sentClientMutationIDs() == ["cm_add_milk", "cm_add_soup", "cm_drop_onion"])
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_add_milk", "cm_check_milk"])
    }

    @Test("ordering keys: each item on its own, local items with their add, clearing on the whole list")
    func shoppingDependencyKeys() throws {
        #expect(NativeQueuedMutation.shoppingItemDependencyKey(itemID: "item_milk") == "shopping:item:item_milk")
        #expect(NativeQueuedMutation.shoppingItemDependencyKey(itemID: "item_local_cm_1") == "shopping:new:cm_1")
        #expect(NativeQueuedMutation.shoppingItemDependencyKey(itemID: "item_local_cm_1-ingredient-12") == "shopping:new:cm_1")
        #expect(NativeQueuedMutation.shoppingClearAll(clientMutationID: "cm_all", createdAt: Self.createdAt).dependencyKey == "shopping-list")
        let clear = NativeQueuedMutation.shoppingClearCompleted(clientMutationID: "cm_clear", createdAt: Self.createdAt)
        #expect(clear.isHeld(byBlockedDependencyKeys: ["shopping:item:item_milk"]))
        #expect(!clear.isHeld(byBlockedDependencyKeys: ["recipe:recipe_soup"]))

        // A stored check with no item id cannot be tied to one item, so it orders on the whole list.
        let check = NativeQueuedMutation.shoppingCheckItem(itemID: "item_milk", checked: true, clientMutationID: "cm_check", createdAt: Self.createdAt)
        let encoded = try JSONEncoder().encode(check)
        var object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var kind = try #require(object["kind"] as? [String: Any])
        #expect(kind.removeValue(forKey: "itemId") != nil)
        object["kind"] = kind
        let withoutItem = try JSONDecoder().decode(NativeQueuedMutation.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(withoutItem.dependencyKey == "shopping-list")
    }

    @Test("an edit names a local id only when the id is exactly the one its creator made")
    func localIDReferences() throws {
        let step = try NativeQueuedMutation.recipeStepCreate(recipeID: "recipe_local_cm_1", clientMutationID: "cm_step", stepNum: 1, stepTitle: nil, description: "Boil", duration: nil, ingredients: [], outputStepNums: [], createdAt: Self.createdAt)
        #expect(step.referencesLocalIDs(createdBy: "cm_1"))
        #expect(!step.referencesLocalIDs(createdBy: "cm_"))
        #expect(!step.referencesLocalIDs(createdBy: "cm_10"))
        let check = NativeQueuedMutation.shoppingCheckItem(itemID: "item_local_cm_10-ingredient-1 and item_local_cm_1", checked: true, clientMutationID: "cm_check", createdAt: Self.createdAt)
        #expect(check.referencesLocalIDs(createdBy: "cm_10"))
        #expect(check.referencesLocalIDs(createdBy: "cm_1"))
        let nested = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_soup",
            scaleFactor: 1,
            recipeIngredients: [RecipeIngredient(id: "ingredient_rice", name: "made from step_local_cm_7", quantity: 1, unit: "cup")],
            clientMutationID: "cm_add",
            createdAt: Self.createdAt
        )
        #expect(nested.referencesLocalIDs(createdBy: "cm_7"))
        #expect(!nested.referencesLocalIDs(createdBy: "cm_8"))
    }
}

/// Accepts every edit except `turnedDown`, which the server rejects.
private actor HoldTransport: NativeSyncTransport {
    private let turnedDown: Set<String>
    private var sent: [String] = []

    init(turnedDown: Set<String>) {
        self.turnedDown = turnedDown
    }

    func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        .success(cursor: nil, tombstones: [])
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        sent.append(mutation.clientMutationID)
        if turnedDown.contains(mutation.clientMutationID) {
            return .conflict(kind: .validation, serverRevision: nil, message: "Turned down.")
        }
        return .success(serverRevision: nil)
    }

    func sentClientMutationIDs() -> [String] {
        sent
    }
}
