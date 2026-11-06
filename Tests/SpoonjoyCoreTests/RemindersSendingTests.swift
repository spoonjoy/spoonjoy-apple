import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Send to Reminders: the remembered list and the send flow")
@MainActor
struct RemindersSendingTests {
    private static let flour = [ReminderIncomingIngredient(name: "flour", quantity: 2, unit: "cup"), ReminderIncomingIngredient(name: "eggs", quantity: 3, unit: nil)]
    private static let source = ReminderSource(id: "recipe_bread", label: "Bread")

    @Test("the remembered list wins while it exists; else a Groceries list is remembered; else none")
    func resolvedList() {
        let store = FakeRemindersStore(lists: [ReminderListSummary(id: "home", title: "Home"), ReminderListSummary(id: "groc", title: "Groceries")])
        #expect(store.resolvedList()?.id == "groc")
        #expect(store.chosenListID == "groc")
        store.chosenListID = "home"
        #expect(store.resolvedList()?.id == "home")
        store.chosenListID = "gone"
        #expect(store.resolvedList()?.id == "groc")
        #expect(FakeRemindersStore(lists: [ReminderListSummary(id: "home", title: "Home")]).resolvedList() == nil)
    }

    @Test("the first send adds, the second changes nothing, and the list title is remembered")
    func sendTwice() async {
        let store = FakeRemindersStore(lists: [ReminderListSummary(id: "groc", title: "Groceries")])
        let sender = SpoonjoyRemindersSender(store: store)
        sender.refreshCurrentListTitle()
        #expect(sender.currentListTitle == nil)
        store.hasFullAccess = true
        sender.refreshCurrentListTitle()
        #expect(sender.currentListTitle == "Groceries")

        let first = sender.send(ingredients: Self.flour, source: Self.source)
        #expect(sender.phase == .sending)
        #expect(sender.send(ingredients: Self.flour, source: Self.source) == nil)
        await first?.value
        #expect(sender.statusMessage == "Added 2 in Groceries.")
        #expect(sender.phase == .idle)

        await sender.send(ingredients: Self.flour, source: Self.source)?.value
        #expect(sender.statusMessage == "Everything was already in Groceries. Nothing changed.")
        #expect(store.applied == 1)
    }

    @Test("with no list to use the picker opens; choosing or creating a list delivers the waiting send")
    func choosingList() async {
        let store = FakeRemindersStore(lists: [ReminderListSummary(id: "home", title: "Home")])
        let sender = SpoonjoyRemindersSender(store: store)
        await sender.send(ingredients: Self.flour, source: Self.source)?.value
        #expect(sender.isPickingList)
        #expect(sender.availableLists.map(\.id) == ["home"])
        await sender.select(ReminderListSummary(id: "home", title: "Home"))?.value
        #expect(store.chosenListID == "home")
        #expect(sender.statusMessage == "Added 2 in Home.")

        #expect(sender.select(ReminderListSummary(id: "home", title: "Home")) == nil)
        #expect(sender.phase == .idle)

        await sender.send(ingredients: [ReminderIncomingIngredient(name: "salt", quantity: nil, unit: nil)], source: Self.source)?.value
        store.chosenListID = nil
        store.available = []
        await sender.send(ingredients: Self.flour, source: Self.source)?.value
        #expect(sender.isPickingList)
        #expect(sender.createList(named: "   ") == nil)
        await sender.createList(named: " Shop ")?.value
        #expect(sender.currentListTitle == "Shop")
        #expect(sender.statusMessage == "Added 2 in Shop.")

        await sender.chooseList().value
        #expect(sender.isPickingList)
        sender.isPickingList = true
        #expect(sender.isPickingList)
        sender.isPickingList = false
        #expect(sender.phase == .idle)
        sender.isPickingList = false
        await sender.chooseList().value
        sender.cancelListChoice()
        #expect(sender.phase == .idle)
    }

    @Test("a missing list reopens the picker; denied access shows the alert; other failures say so")
    func failures() async {
        let store = FakeRemindersStore(lists: [ReminderListSummary(id: "groc", title: "Groceries")])
        let sender = SpoonjoyRemindersSender(store: store)
        store.existingError = SpoonjoyRemindersError.listMissing
        await sender.send(ingredients: Self.flour, source: Self.source)?.value
        #expect(sender.isPickingList)
        sender.cancelListChoice()

        store.existingError = SpoonjoyRemindersError.accessDenied
        await sender.send(ingredients: Self.flour, source: Self.source)?.value
        #expect(sender.isShowingDenied)
        sender.isShowingDenied = true
        sender.isShowingDenied = false
        #expect(sender.phase == .idle)
        sender.isShowingDenied = false

        store.existingError = SpoonjoyRemindersError.saveFailed
        await sender.send(ingredients: Self.flour, source: Self.source)?.value
        #expect(sender.errorMessage == "Could not send to Reminders.")
        store.existingError = nil

        store.accessError = SpoonjoyRemindersError.accessDenied
        await sender.send(ingredients: Self.flour, source: Self.source)?.value
        #expect(sender.isShowingDenied)
        await sender.chooseList().value
        #expect(sender.isShowingDenied)

        store.accessError = SpoonjoyRemindersError.saveFailed
        await sender.send(ingredients: Self.flour, source: Self.source)?.value
        #expect(sender.errorMessage == "Could not send to Reminders.")
        await sender.chooseList().value
        #expect(sender.phase == .idle)
        store.accessError = nil

        store.createError = SpoonjoyRemindersError.saveFailed
        #expect(sender.createList(named: "Shop") == nil)
        #expect(sender.errorMessage == "Could not send to Reminders.")
    }

    @Test("a send whose choice was cancelled while access was pending delivers nothing")
    func cancelledWhileWaiting() async {
        let store = FakeRemindersStore(lists: [ReminderListSummary(id: "groc", title: "Groceries")])
        store.chosenListID = "groc"
        let sender = SpoonjoyRemindersSender(store: store)
        store.holdsAccess = true
        let sending = sender.send(ingredients: Self.flour, source: Self.source)
        await store.waitUntilHeld()
        // Cancel does nothing while a send is on its way.
        sender.cancelListChoice()
        #expect(sender.phase == .sending)
        // The picker opens over the waiting send and the person cancels it.
        store.holdsAccess = false
        await sender.chooseList().value
        sender.cancelListChoice()
        store.releaseHeld()
        await sending?.value
        #expect(sender.phase == .idle)
        #expect(sender.statusMessage == nil)
        #expect(store.applied == 0)
    }
}

private final class FakeRemindersStore: SpoonjoyRemindersStoring, @unchecked Sendable {
    var hasFullAccess = false
    var available: [ReminderListSummary]
    var chosenListID: String?
    var reminders: [String: [ReminderExisting]] = [:]
    var applied = 0
    var accessError: Error?
    var existingError: Error?
    var createError: Error?
    var holdsAccess = false
    // requestAccess runs off the main actor, so the hold's state changes under a lock: a waiter can never be added
    // after the hold began and miss its wake-up.
    private let lock = NSLock()
    private var held: CheckedContinuation<Void, Never>?
    private var heldWaiters: [CheckedContinuation<Void, Never>] = []

    init(lists: [ReminderListSummary]) {
        self.available = lists
    }

    func requestAccess() async throws {
        if holdsAccess {
            await withCheckedContinuation { continuation in
                let waiters = lock.withLock {
                    held = continuation
                    defer { heldWaiters = [] }
                    return heldWaiters
                }
                waiters.forEach { $0.resume() }
            }
        }
        if let accessError { throw accessError }
    }

    func waitUntilHeld() async {
        await withCheckedContinuation { continuation in
            let isHeld = lock.withLock {
                if held != nil { return true }
                heldWaiters.append(continuation)
                return false
            }
            if isHeld { continuation.resume() }
        }
    }

    func releaseHeld() {
        let continuation = lock.withLock {
            defer { held = nil }
            return held
        }
        continuation?.resume()
    }

    func lists() -> [ReminderListSummary] {
        available
    }

    func createList(title: String) throws -> ReminderListSummary {
        if let createError { throw createError }
        let list = ReminderListSummary(id: title.lowercased(), title: title)
        available.append(list)
        return list
    }

    func existingReminders(listID: String) async throws -> [ReminderExisting] {
        if let existingError { throw existingError }
        return reminders[listID] ?? []
    }

    func apply(_ plan: ReminderSyncPlan, listID: String) throws {
        applied += 1
        for case .create(let title, let notes) in plan.operations {
            reminders[listID, default: []].append(ReminderExisting(id: UUID().uuidString, title: title, notes: notes, isCompleted: false))
        }
    }
}
