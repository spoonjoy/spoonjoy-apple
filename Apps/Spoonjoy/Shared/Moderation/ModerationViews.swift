import SpoonjoyCore
import SwiftUI

/// A report or block the person asked for from a menu, waiting for the sheet or confirmation that finishes it.
struct ModerationPrompt: Identifiable, Equatable {
    enum Kind: Equatable {
        case report(ContentReportTarget, subject: String)
        case block(BlockedChef, from: ContentReportTarget)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .report(let target, _): "report-\(target.type.rawValue)-\(target.id)"
        case .block(let chef, _): "block-\(chef.id)"
        }
    }

    var reportTarget: (target: ContentReportTarget, subject: String)? {
        if case .report(let target, let subject) = kind { return (target, subject) }
        return nil
    }

    var blockedChef: BlockedChef? {
        if case .block(let chef, _) = kind { return chef }
        return nil
    }

    var blockedFrom: ContentReportTarget? {
        if case .block(_, let target) = kind { return target }
        return nil
    }
}

/// "Report…" and "Block <chef>" for a menu on someone else's recipe or kitchen.
struct ModerationMenuItems: View {
    let reportTarget: ContentReportTarget
    let reportSubject: String
    let chef: BlockedChef
    @Binding var prompt: ModerationPrompt?

    var body: some View {
        Divider()
        Button {
            prompt = ModerationPrompt(kind: .report(reportTarget, subject: reportSubject))
        } label: {
            Label("Report…", systemImage: "flag")
        }
        .accessibilityIdentifier("moderation.report")
        Button(role: .destructive) {
            prompt = ModerationPrompt(kind: .block(chef, from: reportTarget))
        } label: {
            Label("Block \(chef.name)", systemImage: "hand.raised")
        }
        .accessibilityIdentifier("moderation.block")
    }
}

extension View {
    /// Presents the report sheet and the block confirmation for `prompt`. `onHidden` runs once the reported item or
    /// the blocked chef's content is gone, so a detail screen can step back.
    func moderationPrompts(_ prompt: Binding<ModerationPrompt?>, onHidden: @escaping @MainActor () -> Void) -> some View {
        modifier(ModerationPromptsModifier(prompt: prompt, onHidden: onHidden))
    }
}

private struct ModerationPromptsModifier: ViewModifier {
    @Environment(\.moderation) private var moderation
    @Binding var prompt: ModerationPrompt?
    let onHidden: @MainActor () -> Void
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .sheet(item: reportBinding) { prompt in
                if let report = prompt.reportTarget {
                    ReportContentSheet(target: report.target, subject: report.subject) {
                        self.prompt = nil
                        onHidden()
                    }
                }
            }
            .confirmationDialog(
                blockTitle,
                isPresented: blockIsPresented,
                titleVisibility: .visible,
                presenting: prompt?.blockedChef
            ) { chef in
                Button("Block \(chef.name)", role: .destructive) {
                    let target = prompt?.blockedFrom
                    Task { await block(chef, from: target) }
                }
                .accessibilityIdentifier("moderation.blockConfirm")
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("You won't see their recipes, cookbooks or cook logs, and they can't find yours. You can unblock them in Settings.")
            }
            .alert("Something went wrong", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
    }

    private var reportBinding: Binding<ModerationPrompt?> {
        Binding(
            get: { prompt?.reportTarget == nil ? nil : prompt },
            set: { if $0 == nil, prompt?.reportTarget != nil { prompt = nil } }
        )
    }

    private var blockIsPresented: Binding<Bool> {
        Binding(
            get: { prompt?.blockedChef != nil },
            set: { if !$0, prompt?.blockedChef != nil { prompt = nil } }
        )
    }

    private var blockTitle: String {
        prompt?.blockedChef.map { "Block \($0.name)?" } ?? "Block chef?"
    }

    @MainActor private func block(_ chef: BlockedChef, from target: ContentReportTarget?) async {
        do {
            try await moderation.block(chef, from: target)
            prompt = nil
            onHidden()
        } catch {
            failure = ModerationController.failureMessage(error, action: "block \(chef.name)")
        }
    }
}

/// Asks why the person is reporting something, sends it, and thanks them.
struct ReportContentSheet: View {
    let target: ContentReportTarget
    let subject: String
    let onDone: @MainActor () -> Void

    @Environment(\.moderation) private var moderation
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ContentReportReason?
    @State private var details = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label("Thanks — we review reports within 24 hours.", systemImage: "checkmark.seal")
                            .font(KitchenTableTheme.bodyNote)
                            .foregroundStyle(KitchenTableTheme.herb)
                            .accessibilityIdentifier("moderation.reportThanks")
                        Text("We've hidden \(subject) for you.")
                            .font(KitchenTableTheme.bodyNote)
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                    }
                } else {
                    Section("What's wrong with \(subject)?") {
                        ForEach(ContentReportReason.allCases) { option in
                            Button {
                                reason = option
                            } label: {
                                HStack {
                                    Text(option.title)
                                        .foregroundStyle(KitchenTableTheme.charcoal)
                                    Spacer()
                                    if reason == option {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(KitchenTableTheme.brass)
                                    }
                                }
                                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                                .contentShape(Rectangle())
                            }
                            .accessibilityAddTraits(reason == option ? .isSelected : [])
                            .accessibilityIdentifier("moderation.reason.\(option.rawValue)")
                        }
                    }
                    Section("Anything else? (optional)") {
                        TextField("Details", text: $details, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("moderation.reportDetails")
                    }
                    if let failure {
                        Section {
                            Label(failure, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(KitchenTableTheme.tomato)
                        }
                    }
                }
            }
            .navigationTitle("Report")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                if sent {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                            onDone()
                        }
                        .accessibilityIdentifier("moderation.reportDone")
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSending ? "Sending…" : "Send") {
                            Task { await send() }
                        }
                        .disabled(reason == nil || isSending)
                        .accessibilityIdentifier("moderation.reportSubmit")
                    }
                }
            }
        }
    }

    @MainActor private func send() async {
        guard let reason else { return }
        isSending = true
        failure = nil
        defer { isSending = false }
        do {
            try await moderation.report(target, reason: reason, details: details)
            sent = true
        } catch {
            failure = ModerationController.failureMessage(error, action: "send this report")
        }
    }
}

/// Settings > Blocked Chefs: the chefs this account blocked, each with Unblock.
struct BlockedChefsView: View {
    @Environment(\.moderation) private var moderation
    @State private var isLoading = true
    @State private var failure: String?

    var body: some View {
        List {
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(KitchenTableTheme.tomato)
            }
            if moderation.ledger.blockedChefs.isEmpty {
                Text(isLoading ? "Loading…" : "You haven't blocked anyone.")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .accessibilityIdentifier("blockedChefs.empty")
            }
            ForEach(moderation.ledger.blockedChefs) { chef in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chef.name)
                            .font(KitchenTableTheme.objectTitle)
                            .foregroundStyle(KitchenTableTheme.charcoal)
                        if chef.displayName?.isEmpty == false {
                            Text("@\(chef.username)")
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.inkMuted)
                        }
                    }
                    Spacer()
                    Button("Unblock") {
                        Task { await unblock(chef) }
                    }
                    .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                    .accessibilityLabel("Unblock \(chef.name)")
                    .accessibilityIdentifier("blockedChefs.unblock")
                }
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .accessibilityIdentifier("blockedChefs.row")
            }
        }
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .navigationTitle("Blocked Chefs")
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    @MainActor private func refresh() async {
        defer { isLoading = false }
        do {
            try await moderation.refreshBlocks()
            failure = nil
        } catch {
            failure = ModerationController.failureMessage(error, action: "load your blocked chefs")
        }
    }

    @MainActor private func unblock(_ chef: BlockedChef) async {
        do {
            try await moderation.unblock(chefID: chef.id)
            failure = nil
        } catch {
            failure = ModerationController.failureMessage(error, action: "unblock \(chef.name)")
        }
    }
}

/// Shown in place of a recipe or kitchen whose chef is blocked or that the person reported.
struct ModerationHiddenView: View {
    let message: String
    let unblockChef: BlockedChef?
    @Environment(\.moderation) private var moderation

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.raised")
                .font(.largeTitle)
                .foregroundStyle(KitchenTableTheme.inkMuted)
            Text(message)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("moderation.hidden")
            if let unblockChef {
                Button("Unblock \(unblockChef.name)") {
                    Task { try? await moderation.unblock(chefID: unblockChef.id) }
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            }
        }
        .padding(KitchenTableTheme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KitchenTableTheme.bone)
    }
}
