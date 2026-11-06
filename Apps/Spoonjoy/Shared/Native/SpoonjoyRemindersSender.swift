import Foundation
import Observation
import SpoonjoyCore
import SwiftUI

#if canImport(EventKit)

// `SpoonjoyRemindersSender` lives in SpoonjoyCore so Ouro Reins drives the same send headless.
extension SpoonjoyRemindersSender {
    /// The sender over this device's Reminders, through EventKit.
    convenience init() {
        self.init(store: SpoonjoyRemindersStore())
    }
}

/// Presents the list picker and the denied-access alert for a `SpoonjoyRemindersSender`.
struct SpoonjoyRemindersSendModifier: ViewModifier {
    @Bindable var sender: SpoonjoyRemindersSender
    @State private var newListName = ""

    func body(content: Content) -> some View {
        content
            .task { sender.refreshCurrentListTitle() }
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
