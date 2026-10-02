import Foundation
import Observation
import SpoonjoyCore
import SwiftUI

#if canImport(EventKit)

/// Drives the "Send to Reminders" flow for the recipe and shopping list screens.
@MainActor
@Observable
final class SpoonjoyRemindersSender {
    enum Phase: Equatable {
        case idle
        case sending
        case choosingList
        case denied
    }

    private(set) var phase: Phase = .idle
    private(set) var statusMessage: String?
    private(set) var errorMessage: String?
    private(set) var availableLists: [ReminderListSummary] = []
    private(set) var currentListTitle: String?

    @ObservationIgnored private let store: SpoonjoyRemindersStore
    @ObservationIgnored private var pending: (ingredients: [ReminderIncomingIngredient], source: ReminderSource)?

    init(store: SpoonjoyRemindersStore = SpoonjoyRemindersStore()) {
        self.store = store
        currentListTitle = store.hasFullAccess ? store.resolvedList()?.title : nil
    }

    var isPickingList: Bool {
        get { phase == .choosingList }
        set { if !newValue, phase == .choosingList { phase = .idle } }
    }

    var isShowingDenied: Bool {
        get { phase == .denied }
        set { if !newValue, phase == .denied { phase = .idle } }
    }

    /// The system permission prompt appears here, the first time the user sends.
    func send(ingredients: [ReminderIncomingIngredient], source: ReminderSource) {
        guard phase != .sending else {
            return
        }
        statusMessage = nil
        errorMessage = nil
        pending = (ingredients, source)
        phase = .sending
        Task {
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
    func chooseList() {
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

    func select(_ list: ReminderListSummary) {
        store.chosenListID = list.id
        currentListTitle = list.title
        guard pending != nil else {
            phase = .idle
            return
        }
        phase = .sending
        Task { await deliver(to: list) }
    }

    func createList(named title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        do {
            select(try store.createList(title: trimmed))
        } catch {
            fail()
        }
    }

    func cancelListChoice() {
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

/// Presents the list picker and the denied-access alert for a `SpoonjoyRemindersSender`.
struct SpoonjoyRemindersSendModifier: ViewModifier {
    @Bindable var sender: SpoonjoyRemindersSender
    @State private var newListName = ""

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $sender.isPickingList, onDismiss: { sender.cancelListChoice() }) {
                NavigationStack {
                    List {
                        Section("Send ingredients to") {
                            ForEach(sender.availableLists) { list in
                                Button(list.title) { sender.select(list) }
                                    .accessibilityIdentifier("reminders.list")
                            }
                        }
                        Section("Or make a new list") {
                            TextField("List name", text: $newListName)
                                .accessibilityIdentifier("reminders.newListName")
                            Button("Create and use") {
                                sender.createList(named: newListName)
                                newListName = ""
                            }
                            .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("reminders.createList")
                        }
                    }
                    .navigationTitle("Reminders List")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { sender.isPickingList = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Reminders access is off", isPresented: $sender.isShowingDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Spoonjoy needs full access to Reminders to check what is already on your list. Turn it on in Settings, under Privacy & Security, then Reminders.")
            }
    }
}

extension View {
    func spoonjoyRemindersSend(_ sender: SpoonjoyRemindersSender) -> some View {
        modifier(SpoonjoyRemindersSendModifier(sender: sender))
    }
}
#endif
