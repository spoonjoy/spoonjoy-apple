import AppIntents
import Testing
@testable import SpoonjoyActions

/// The generated actions as code: what an agent asking for approve_agent_connection gets back, and that the App Intent
/// Siri and Shortcuts see asks only for what a person would say.
@Suite("Spoonjoy actions")
@MainActor
struct SpoonjoyActionsTests {
    @Test("approve_agent_connection refuses every agent door with the declaration's words")
    func approveAgentConnectionRefuses() throws {
        #expect(OuroActions.consent["approve_agent_connection"] == .personOnly)
        for name in ["approve_agent_connection", "approve-agent-connection", "approveAgentConnection"] {
            let refusal = try #require(OuroActions.refusal(for: name))
            #expect(refusal.code == "person-only")
            #expect(refusal.exit == 2)
            #expect(refusal.thing == "connection approve")
            #expect(refusal.reason == "You can't approve access to the person's Spoonjoy account; only they can.")
            #expect(refusal.how == "with Approve access on the connection page, after typing the code you showed them")
            #expect(refusal.message == "connection approve: You can't approve access to the person's Spoonjoy account; only they can. Ask the person, who does it with Approve access on the connection page, after typing the code you showed them.")
        }
    }

    @Test("an agent may add to the list, so it has no refusal")
    func addShoppingListItemIsNotRefused() {
        #expect(OuroActions.consent["add_shopping_list_item"] == .write)
        #expect(OuroActions.refusal(for: "add_shopping_list_item") == nil)
    }

    @Test("the add intent's parameters are the person's words only, never a protocol-only field")
    func addIntentHasNoProtocolOnlyParameter() {
        let parameters = Mirror(reflecting: AddShoppingListItemIntent()).children.compactMap(\.label)
        #expect(Set(parameters) == ["_name", "_quantity", "_unit"])
        for protocolOnly in ["categoryKey", "iconKey", "idempotencyKey", "ownerEmail"] {
            #expect(!parameters.contains { $0.localizedCaseInsensitiveContains(protocolOnly) })
        }
    }

    @Test("the intent passes the person's words through to the one handler")
    func intentCarriesInput() {
        let intent = AddShoppingListItemIntent(AddShoppingListItemInput(name: "oat milk", quantity: 2, unit: "cartons"))
        #expect(intent.name == "oat milk")
        #expect(intent.quantity == 2)
        #expect(intent.unit == "cartons")
    }

    @Test("an action run before the app binds it says which action")
    func unboundActionThrows() async {
        let saved = AddShoppingListItemAction.perform
        AddShoppingListItemAction.perform = nil
        defer { AddShoppingListItemAction.perform = saved }
        await #expect(throws: OuroActionNotBound(action: "add_shopping_list_item")) {
            try await AddShoppingListItemAction.run(AddShoppingListItemInput(name: "oat milk"))
        }
    }
}
