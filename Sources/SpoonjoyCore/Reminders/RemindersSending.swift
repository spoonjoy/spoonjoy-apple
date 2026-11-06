import Foundation
import Observation

public enum SpoonjoyRemindersError: Error, Equatable, Sendable {
    case accessDenied
    case noListChosen
    case listMissing
    case saveFailed
}

/// The Reminders lists the app writes to. The app's EventKit adapter conforms; Ouro Reins uses an in-memory one.
/// The rules (which list is remembered, what a send writes) live in this protocol's extension, so every store runs
/// them the same way.
public protocol SpoonjoyRemindersStoring: AnyObject, Sendable {
    var hasFullAccess: Bool { get }
    /// Shows the system prompt the first time. Throws `accessDenied` when the person says no.
    func requestAccess() async throws
    /// The lists the app may add to.
    func lists() -> [ReminderListSummary]
    /// The list the person chose, remembered across launches.
    var chosenListID: String? { get set }
    func createList(title: String) throws -> ReminderListSummary
    /// Incomplete and completed reminders in a list. Throws `listMissing` when the list is gone.
    func existingReminders(listID: String) async throws -> [ReminderExisting]
    /// Writes the plan's creates and updates to the list.
    func apply(_ plan: ReminderSyncPlan, listID: String) throws
}

extension SpoonjoyRemindersStoring {
    /// The remembered list when it still exists, otherwise an existing Groceries list (remembered from now on), otherwise nil.
    public func resolvedList() -> ReminderListSummary? {
        let available = lists()
        if let id = chosenListID, let chosen = available.first(where: { $0.id == id }) {
            return chosen
        }
        guard let fallback = ReminderListSummary.preferredDefault(in: available) else {
            return nil
        }
        chosenListID = fallback.id
        return fallback
    }

    /// Reads the list, plans, then writes only what the plan says, so a repeat send changes nothing.
    public func send(
        _ incoming: [ReminderIncomingIngredient],
        source: ReminderSource,
        listID: String
    ) async throws -> ReminderSyncSummary {
        try await requestAccess()
        let existing = try await existingReminders(listID: listID)
        let plan = ReminderSyncPlanner.plan(incoming: incoming, existing: existing, source: source)
        if !plan.isNoOp {
            try apply(plan, listID: listID)
        }
        return plan.summary
    }
}

/// Drives the "Send to Reminders" flow for the recipe and shopping list screens.
@MainActor
@Observable
public final class SpoonjoyRemindersSender {
    public enum Phase: Equatable, Sendable {
        case idle
        case sending
        case choosingList
        case denied
    }

    public private(set) var phase: Phase = .idle
    public private(set) var statusMessage: String?
    public private(set) var errorMessage: String?
    public private(set) var availableLists: [ReminderListSummary] = []
    public private(set) var currentListTitle: String?

    @ObservationIgnored private let store: any SpoonjoyRemindersStoring
    @ObservationIgnored private var pending: (ingredients: [ReminderIncomingIngredient], source: ReminderSource)?

    public init(store: any SpoonjoyRemindersStoring) {
        self.store = store
    }

    /// Reads the remembered list's name for the menu. Called once the view appears, never while building it.
    public func refreshCurrentListTitle() {
        currentListTitle = store.hasFullAccess ? store.resolvedList()?.title : nil
    }

    public var isPickingList: Bool {
        get { phase == .choosingList }
        set { if !newValue, phase == .choosingList { phase = .idle } }
    }

    public var isShowingDenied: Bool {
        get { phase == .denied }
        set { if !newValue, phase == .denied { phase = .idle } }
    }

    /// The system permission prompt appears here, the first time the user sends.
    @discardableResult
    public func send(ingredients: [ReminderIncomingIngredient], source: ReminderSource) -> Task<Void, Never>? {
        guard phase != .sending else {
            return nil
        }
        statusMessage = nil
        errorMessage = nil
        pending = (ingredients, source)
        phase = .sending
        return Task {
            do {
                try await store.requestAccess()
            } catch SpoonjoyRemindersError.accessDenied {
                phase = .denied
                return
            } catch {
                fail()
                return
            }
            if let list = store.resolvedList() {
                await deliver(to: list)
            } else {
                presentListChoice()
            }
        }
    }

    /// Lets the user change the remembered list. Resends nothing unless a send is waiting on the choice.
    @discardableResult
    public func chooseList() -> Task<Void, Never> {
        Task {
            do {
                try await store.requestAccess()
                presentListChoice()
            } catch SpoonjoyRemindersError.accessDenied {
                phase = .denied
            } catch {
                fail()
            }
        }
    }

    @discardableResult
    public func select(_ list: ReminderListSummary) -> Task<Void, Never>? {
        store.chosenListID = list.id
        currentListTitle = list.title
        guard pending != nil else {
            phase = .idle
            return nil
        }
        phase = .sending
        return Task { await deliver(to: list) }
    }

    @discardableResult
    public func createList(named title: String) -> Task<Void, Never>? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        do {
            return select(try store.createList(title: trimmed))
        } catch {
            fail()
            return nil
        }
    }

    public func cancelListChoice() {
        guard phase != .sending else {
            return
        }
        pending = nil
        phase = .idle
    }

    private func presentListChoice() {
        availableLists = store.lists()
        phase = .choosingList
    }

    private func deliver(to list: ReminderListSummary) async {
        guard let pending else {
            phase = .idle
            return
        }
        do {
            let summary = try await store.send(pending.ingredients, source: pending.source, listID: list.id)
            self.pending = nil
            currentListTitle = list.title
            statusMessage = summary.message(listName: list.title)
            phase = .idle
        } catch SpoonjoyRemindersError.listMissing {
            presentListChoice()
        } catch SpoonjoyRemindersError.accessDenied {
            phase = .denied
        } catch {
            fail()
        }
    }

    private func fail() {
        pending = nil
        phase = .idle
        errorMessage = "Could not send to Reminders."
    }
}
