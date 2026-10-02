import Foundation
import SpoonjoyCore

#if canImport(EventKit)
import EventKit

enum SpoonjoyRemindersError: Error, Equatable {
    case accessDenied
    case noListChosen
    case listMissing
    case saveFailed
}

/// Thin EventKit adapter. All matching and merging rules live in `ReminderSyncPlanner` in SpoonjoyCore.
final class SpoonjoyRemindersStore: @unchecked Sendable {
    static let chosenListDefaultsKey = "spoonjoy.reminders.chosenListIdentifier"

    /// One store for the whole process, created on first use. Creating an EKEventStore connects to the
    /// calendar daemon, and SwiftUI builds a view's `@State` default every time the parent re-renders, so
    /// making one per view struct would stall the main thread.
    nonisolated(unsafe) private static let sharedEventStore = EKEventStore()

    private let eventStoreOverride: EKEventStore?
    private let defaults: UserDefaults

    private var eventStore: EKEventStore {
        eventStoreOverride ?? Self.sharedEventStore
    }

    init(eventStore: EKEventStore? = nil, defaults: UserDefaults = .standard) {
        self.eventStoreOverride = eventStore
        self.defaults = defaults
    }

    var hasFullAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    var isAccessDenied: Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .denied, .restricted, .writeOnly:
            true
        default:
            false
        }
    }

    /// Shows the system prompt the first time. Called only when the user sends something.
    func requestAccess() async throws {
        if hasFullAccess {
            return
        }
        guard try await eventStore.requestFullAccessToReminders() else {
            throw SpoonjoyRemindersError.accessDenied
        }
    }

    func lists() -> [ReminderListSummary] {
        eventStore.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .map { ReminderListSummary(id: $0.calendarIdentifier, title: $0.title) }
    }

    var chosenListID: String? {
        get { defaults.string(forKey: Self.chosenListDefaultsKey) }
        set { defaults.set(newValue, forKey: Self.chosenListDefaultsKey) }
    }

    /// The remembered list when it still exists, otherwise an existing Groceries list (remembered from now on), otherwise nil.
    func resolvedList() -> ReminderListSummary? {
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

    func createList(title: String) throws -> ReminderListSummary {
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = title
        guard let source = eventStore.defaultCalendarForNewReminders()?.source ?? eventStore.sources.first(where: { $0.sourceType != .birthdays }) else {
            throw SpoonjoyRemindersError.saveFailed
        }
        calendar.source = source
        try eventStore.saveCalendar(calendar, commit: true)
        return ReminderListSummary(id: calendar.calendarIdentifier, title: calendar.title)
    }

    /// Reads incomplete and completed reminders, plans, then writes only what the plan says.
    func send(
        _ incoming: [ReminderIncomingIngredient],
        source: ReminderSource,
        listID: String
    ) async throws -> ReminderSyncSummary {
        try await requestAccess()
        guard let calendar = eventStore.calendar(withIdentifier: listID) else {
            throw SpoonjoyRemindersError.listMissing
        }
        let existing = await existingReminders(in: calendar)
        let plan = ReminderSyncPlanner.plan(incoming: incoming, existing: existing, source: source)
        try apply(plan, to: calendar)
        return plan.summary
    }

    private func existingReminders(in calendar: EKCalendar) async -> [ReminderExisting] {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).map { reminder in
                    ReminderExisting(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "",
                        notes: reminder.notes,
                        isCompleted: reminder.isCompleted
                    )
                }
                continuation.resume(returning: mapped)
            }
        }
    }

    private func apply(_ plan: ReminderSyncPlan, to calendar: EKCalendar) throws {
        guard !plan.isNoOp else {
            return
        }
        for operation in plan.operations {
            switch operation {
            case .create(let title, let notes):
                let reminder = EKReminder(eventStore: eventStore)
                reminder.calendar = calendar
                reminder.title = title
                reminder.notes = notes
                try eventStore.save(reminder, commit: false)
            case .update(let id, let title, let notes, let reopen):
                guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
                    throw SpoonjoyRemindersError.saveFailed
                }
                reminder.title = title
                reminder.notes = notes
                if reopen {
                    reminder.isCompleted = false
                }
                try eventStore.save(reminder, commit: false)
            case .unchanged:
                continue
            }
        }
        try eventStore.commit()
    }
}
#endif
