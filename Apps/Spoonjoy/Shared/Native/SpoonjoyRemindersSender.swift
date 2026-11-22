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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .task { sender.refreshCurrentListTitle() }
            .sheet(isPresented: $sender.isPickingList, onDismiss: { sender.cancelListChoice() }) {
                NavigationStack {
                    List {
                        // At the accessibility sizes the bar's large title read "Remind…", so the bar goes quiet and
                        // the title leads the list, wrapping between words.
                        if dynamicTypeSize.isAccessibilitySize {
                            WholeWordText("Reminders List")
                                .font(KitchenTableTheme.sectionTitle)
                                .foregroundStyle(KitchenTableTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(.isHeader)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                        }
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
#if os(iOS)
                    .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .automatic)
                    .toolbar(removing: dynamicTypeSize.isAccessibilitySize ? .title : nil)
#endif
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
