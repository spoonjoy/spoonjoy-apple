import OuroReins
import SpoonjoyCore

struct ReportReasonInput: ReinsInput {
    let reason: String
}

struct ChefInput: ReinsInput {
    let id: String
}

extension SpoonjoyReinsShell {
    /// Report… and Block <chef> in a recipe page's actions menu (ModerationMenuItems), offered as the view offers them.
    func moderationActions(for recipe: Recipe) -> [ReinsAction] {
        guard moderation.canModerate(chefID: recipe.chef.id, isOwner: recipe.chef.id == content.trustedAccountID) else {
            return []
        }
        let target = ContentReportTarget(type: .recipe, id: recipe.id)
        let chef = BlockedChef(id: recipe.chef.id, username: recipe.chef.username)
        return [
            ReinsAction("report", "Report…") { [unowned self] in
                self.sheet = .report(target, subject: "this recipe", reason: nil, sent: false)
            },
            ReinsAction("block", "Block \(chef.name)") { [unowned self] in
                self.sheet = .blockChef(chef, from: target)
            },
        ]
    }

    /// A recipe the person reported, or whose chef they blocked, in place of the recipe (ModerationHiddenView).
    func moderationHiddenNode(_ notice: ModerationHiddenNotice) -> ReinsNode {
        var actions: [ReinsAction] = []
        if let chef = notice.unblockChef {
            actions.append(ReinsAction("unblock", "Unblock \(chef.name)") { [unowned self] in
                try await self.moderation.unblock(chefID: chef.id)
            })
        }
        return ReinsNode("moderationHidden", state: [
            "message": .string(notice.message),
            "unblockChef": notice.unblockChef.map { .string($0.username) } ?? .null,
        ], actions: actions)
    }

    /// ReportContentSheet: a reason, Send, then the thanks and Done.
    func reportSheetNode(_ target: ContentReportTarget, subject: String, reason: ContentReportReason?, sent: Bool) -> ReinsNode {
        if sent {
            return ReinsNode("report", state: [
                "sent": true,
                "thanks": .string(ModerationPrompt.reportThanks),
                "hidden": .string("We've hidden \(subject) for you."),
            ], actions: [
                ReinsAction("done", "Done") { [unowned self] in
                    self.sheet = nil
                    self.moderationHidden()
                },
            ])
        }
        var actions = [
            ReinsAction("pickReason", "Pick what's wrong", input: ReportReasonInput.self) { [unowned self] input in
                guard let picked = ContentReportReason(rawValue: input.reason) else { return }
                self.sheet = .report(target, subject: subject, reason: picked, sent: false)
            }.narrowed(.object(properties: ["reason": .oneOf(ContentReportReason.allCases.map(\.rawValue))], required: ["reason"])),
            ReinsAction("cancel", "Cancel") { [unowned self] in self.sheet = nil },
        ]
        if let reason {
            actions.insert(ReinsAction("send", "Send") { [unowned self] in
                try await self.moderation.report(target, reason: reason, details: "")
                self.sheet = .report(target, subject: subject, reason: reason, sent: true)
            }, at: 1)
        }
        return ReinsNode("report", state: [
            "sent": false,
            "question": .string("What's wrong with \(subject)?"),
            "reasons": .array(ContentReportReason.allCases.map { ["id": .string($0.rawValue), "title": .string($0.title)] }),
            "reason": reason.map { .string($0.rawValue) } ?? .null,
        ], actions: actions)
    }

    /// The Block <chef> confirmation.
    func blockChefSheetNode(_ chef: BlockedChef, from target: ContentReportTarget) -> ReinsNode {
        ReinsNode("blockChef", state: [
            "title": .string(ModerationPrompt.blockTitle(chef)),
            "chef": .string(chef.username),
        ], actions: [
            ReinsAction("confirm", "Block \(chef.name)") { [unowned self] in
                try await self.moderation.block(chef, from: target)
                self.sheet = nil
                self.moderationHidden()
            },
            ReinsAction("cancel", "Cancel") { [unowned self] in self.sheet = nil },
        ])
    }

    /// Settings > Blocked chefs (BlockedChefsView), which loads the server's list as it opens.
    var blockedChefsSheetNode: ReinsNode {
        let chefs = moderation.ledger.blockedChefs
        var state: [String: ReinsValue] = ["chefs": .array(chefs.map { ["id": .string($0.id), "username": .string($0.username), "name": .string($0.name)] })]
        if chefs.isEmpty { state["empty"] = "You haven't blocked anyone." }
        var actions = [ReinsAction("done", "Done") { [unowned self] in self.sheet = nil }]
        if !chefs.isEmpty {
            actions.append(ReinsAction("unblock", "Unblock a chef", input: ChefInput.self) { [unowned self] in
                try await self.moderation.unblock(chefID: $0.id)
            }.narrowed(.object(properties: ["id": .oneOf(chefs.map(\.id))], required: ["id"])))
        }
        return ReinsNode("blockedChefs", state: .object(state), actions: actions)
    }

    /// Settings' Blocked chefs row: the sheet, then BlockedChefsView's `.task { refresh() }`.
    func openBlockedChefs() async throws {
        sheet = .blockedChefs
        try await moderation.refreshBlocks()
    }

    /// The recipe page's `onHidden`: it steps back (`dismiss()`) once the recipe is hidden.
    private func moderationHidden() {
        if shell.canGoBack { goBack() }
    }
}
