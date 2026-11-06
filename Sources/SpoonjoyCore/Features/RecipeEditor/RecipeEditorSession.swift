import Foundation

// The recipe editor's glue between the editor's view model and the shell: which visit's draft is on screen, what a
// Save sends and how, and what the shell does with each plan. `PlatformNavigationView` and `RecipeEditorView` call
// these, and so does Ouro Reins, so a headless journey and the app save an edit the same way.

/// The editors the cook has open, by visit (`AppNavigationState.editorIdentity(for:)`): the view model as the editor
/// opened, which holds the recipe version the edit starts from, and the cook's unsaved draft. An editor left open on
/// another tab, or under Add a recipe, keeps its draft until the cook saves, cancels or opens a new visit.
/// The app keeps the same thing in the editor view's `@State` under that identity; Ouro Reins keeps it here, pruned to
/// `SpoonjoyShell.openEditorIdentities`, the visits whose editor is still on a stack.
public struct RecipeEditorVisits {
    public struct Visit {
        /// The editor as it opened, whose recipe the edit is based on.
        public let opened: RecipeEditorViewModel
        public var draft: RecipeEditorDraft

        public init(opened: RecipeEditorViewModel, draft: RecipeEditorDraft) {
            self.opened = opened
            self.draft = draft
        }
    }

    private var visits: [String: Visit] = [:]

    public init() {}

    public subscript(identity: String) -> Visit? {
        visits[identity]
    }

    /// The visit `identity` names, started from `viewModel` the first time the editor shows.
    public mutating func open(_ identity: String, with viewModel: RecipeEditorViewModel) -> Visit {
        if let visit = visits[identity] {
            return visit
        }
        let visit = Visit(opened: viewModel, draft: viewModel.draft)
        visits[identity] = visit
        return visit
    }

    /// The cook changed the draft on screen.
    public mutating func record(_ visit: Visit, for identity: String) {
        visits[identity] = visit
    }

    /// Drops every visit no longer open: an editor saved, cancelled or replaced leaves the stacks.
    public mutating func keep(only identities: Set<String>) {
        visits = visits.filter { identities.contains($0.key) }
    }

    public var identities: Set<String> {
        Set(visits.keys)
    }
}

extension SpoonjoyShell {
    /// The editor visits still open: each editor on a tab's stack, and the one on screen.
    public var openEditorIdentities: Set<String> {
        var routes = CompactTab.allCases.flatMap { compactTabs.path(for: $0) }
        routes.append(navigation.route)
        return Set(routes.compactMap { route in
            guard case .recipeEditor = route else {
                return nil
            }
            return navigation.editorIdentity(for: route)
        })
    }
}

extension RecipeEditorConnectivity {
    /// The editor plans offline while the shell shows it is offline, and online otherwise.
    public init(display: OfflineIndicatorDisplay) {
        self = display == .offline ? .offline : .online
    }
}

extension NativeShellContentState {
    /// The signed-in account, which owns the recipes the editor creates.
    public var sessionAccountID: String? {
        switch authSessionState {
        case .signedOut:
            nil
        case .authenticated(let session), .refreshRequired(let session):
            session.accountID
        }
    }

    /// The change held on a recipe: the first sync conflict whose queued mutation edits it.
    public func recipeEditorConflict(for recipeID: String) -> RecipeEditorConflict? {
        for conflict in syncConflicts {
            guard let mutation = queuedMutations.first(where: { $0.clientMutationID == conflict.clientMutationID }),
                  mutation.optimisticRecipeID == recipeID else {
                continue
            }
            return RecipeEditorConflict(resourceID: recipeID, syncConflict: conflict)
        }
        return nil
    }

    /// The editor for a recipe, or for a new one when `id` is nil. Nil when the recipe isn't loaded.
    public func recipeEditorViewModel(
        id: String?,
        connectivity: RecipeEditorConnectivity,
        now: @escaping () -> String
    ) -> RecipeEditorViewModel? {
        let chefID = sessionAccountID ?? "signed-out"
        guard let recipeID = id else {
            return RecipeEditorViewModel(
                mode: .create(currentChefID: chefID, draft: .blank(currentChefID: chefID)),
                connectivity: connectivity,
                conflict: nil,
                queuedRecipeMutations: queuedMutations,
                now: now
            )
        }
        guard let recipe = recipe(id: recipeID) else {
            return nil
        }
        return RecipeEditorViewModel(
            mode: .edit(recipe: recipe, currentChefID: chefID),
            connectivity: connectivity,
            conflict: recipeEditorConflict(for: recipeID),
            queuedRecipeMutations: queuedMutations,
            now: now
        )
    }
}

/// What one Save sends, worked out from the editor's planned actions before anything leaves the device.
public struct RecipeEditorSubmission: Equatable {
    public enum Kind: Equatable {
        /// A plan was turned down, with the reason the editor shows.
        case blocked(String)
        /// Nothing on the recipe changed: the editor just closes.
        case nothing
        /// One change, sent on its own (or queued when offline).
        case single(action: RecipeEditorAction, plan: RecipeEditorMutationPlan)
        /// Several changes, queued together and drained at once when online.
        case batch(mutations: [NativeQueuedMutation], drainImmediately: Bool)
    }

    public let kind: Kind
    /// Where the editor goes once the save is through.
    public let successRoute: AppRoute?

    public init(kind: Kind, successRoute: AppRoute?) {
        self.kind = kind
        self.successRoute = successRoute
    }

    /// The queued mutations a batch sends: each plan's own, or the one it falls back to offline.
    public static func batchMutations(_ plans: [RecipeEditorMutationPlan]) throws -> [NativeQueuedMutation] {
        try plans.map { plan in
            guard let mutation = plan.queuedMutation ?? plan.offlineFallbackMutation else {
                throw RecipeEditorPlanningError.missingQueuedMutation
            }
            return mutation
        }
    }
}

extension RecipeEditorViewModel {
    /// Plans each action against this editor and says how the save goes out.
    public func submission(for actions: [RecipeEditorAction]) throws -> RecipeEditorSubmission {
        var planned: [(action: RecipeEditorAction, plan: RecipeEditorMutationPlan)] = []
        for action in actions {
            let plan = try plan(action)
            if let blockedReason = plan.blockedReason {
                return RecipeEditorSubmission(kind: .blocked(blockedReason), successRoute: nil)
            }
            planned.append((action, plan))
        }
        let successRoute = planned.compactMap(\.plan.successRoute).last
        // A save that changed nothing on the recipe itself still checks the draft, but sends nothing.
        let sending = planned.filter { $0.plan.sendsChange }
        if sending.count > 1 {
            let mutations = try RecipeEditorSubmission.batchMutations(sending.map(\.plan))
            return RecipeEditorSubmission(kind: .batch(mutations: mutations, drainImmediately: connectivity == .online), successRoute: successRoute)
        }
        if let only = sending.first {
            return RecipeEditorSubmission(kind: .single(action: only.action, plan: only.plan), successRoute: successRoute)
        }
        return RecipeEditorSubmission(kind: .nothing, successRoute: successRoute)
    }
}

/// What the editor shows after an online batch went out, instead of closing.
public enum RecipeEditorBatchAttention: Equatable {
    /// Everything went through, or the edit is held on the recipe page: close.
    case none
    /// The server turned a change down; the editor shows it as a conflict.
    case conflict(RecipeEditorConflict)
    /// Some of the edits are still queued.
    case stillQueued(count: Int, oldestClientMutationID: String?)

    public var message: String? {
        switch self {
        case .none:
            nil
        case .conflict(let conflict):
            conflict.message
        case .stillQueued(let count, _):
            count == 1
                ? "One recipe edit is still queued. Review the offline status before leaving the editor."
                : "\(count) recipe edits are still queued. Review the offline status before leaving the editor."
        }
    }

    public init(after result: NativeQueuedMutationBatchResult, mutations: [NativeQueuedMutation], recipeID: String?) {
        // A recipe edit that conflicts with a change made elsewhere is held on the recipe page, where the banner shows
        // both versions; the editor closes as for a saved edit.
        if result.holdsRecipeEditChoice {
            self = .none
            return
        }
        if let conflict = result.submittedConflicts.first {
            let mutation = mutations.first { $0.clientMutationID == conflict.clientMutationID }
            let resourceID = mutation?.recipeID ?? recipeID ?? conflict.clientMutationID
            self = .conflict(RecipeEditorConflict(
                resourceID: resourceID,
                serverRevision: conflict.serverRevision,
                localClientMutationID: conflict.clientMutationID,
                message: conflict.message
            ))
            return
        }
        guard !result.drainedClientMutationIDs.isEmpty, !result.remainingSubmittedClientMutationIDs.isEmpty else {
            self = .none
            return
        }
        self = .stillQueued(
            count: result.remainingSubmittedClientMutationIDs.count,
            oldestClientMutationID: result.remainingSubmittedClientMutationIDs.first
        )
    }
}

/// How the shell sends one editor plan: a queued change is queued; a change that depends on one still queued waits
/// behind it; otherwise it goes to the server, and is queued when the device turns out to be offline or when the
/// recipe changed after the editor opened (the queue then compares the edit with the current recipe).
public enum RecipeEditorPlanRunner {
    @MainActor
    public static func perform(
        _ plan: RecipeEditorMutationPlan,
        queuedMutations: [NativeQueuedMutation],
        queueMutation: (NativeQueuedMutation) async throws -> Void,
        queueMutations: ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        execute: (APIRequestBuilder) async throws -> Void
    ) async throws {
        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            return
        }

        if let offlineFallbackMutation = plan.offlineFallbackMutation,
           queuedMutations.contains(where: { $0.blocksDependencyKey(offlineFallbackMutation.dependencyKey) }) {
            _ = try await queueMutations([offlineFallbackMutation], true)
            return
        }

        guard let requestBuilder = plan.remoteRequestBuilder else {
            return
        }
        do {
            try await execute(requestBuilder)
        } catch let error as APITransportError where error.isOffline {
            if let offlineFallbackMutation = plan.offlineFallbackMutation {
                try await queueMutation(offlineFallbackMutation)
                return
            }
            throw error
        } catch let error as APITransportError where error.isRecipeEditConflict {
            // The recipe changed after the editor opened. The queue compares the edit with the current recipe: it
            // sends it if nobody else changed the same fields, and otherwise holds it on the recipe page with both
            // versions, for the cook to choose.
            if let offlineFallbackMutation = plan.offlineFallbackMutation {
                _ = try await queueMutations([offlineFallbackMutation], true)
                return
            }
            throw error
        }
    }
}

extension NativeRecipeEditConflict {
    /// The held-change banner's heading: a conflict with a change made elsewhere, or an edit the server turned down.
    public static func heldChangeTitle(_ conflict: NativeRecipeEditConflict?) -> String {
        conflict == nil ? "A change to this recipe was not saved" : "This recipe changed somewhere else"
    }

    /// The banner's body. A conflict's heading already says the recipe changed somewhere else, so the body only asks
    /// for the choice instead of repeating it.
    public static func heldChangeMessage(_ conflict: NativeRecipeEditConflict?, serverMessage: String) -> String {
        conflict == nil ? serverMessage : choicePrompt
    }
}
