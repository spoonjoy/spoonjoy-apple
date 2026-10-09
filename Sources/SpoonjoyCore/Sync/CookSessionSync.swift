import Foundation

// Cross-device cook progress. The website keeps one cook session per chef and recipe on the server
// (cook-session protocol v1) and this file is the native side of the same rules, ported from the
// website's `app/lib/cook-session-sync.ts`.
//
// Merge rule: the server holds numbered revisions. The app remembers the last server state it saw (the
// "base") and treats everything that differs from the base as its own pending changes. When the server has
// moved on, the pending changes are replayed on top of the server's state: a changed step or scale wins
// over the server's, and checks and unchecks are applied item by item, so two devices checking different
// ingredients both keep their checks.

/// The part of cook progress the server can represent. Completed steps stay on the device.
public struct CookSyncProgress: Codable, Equatable, Sendable {
    public let activeStepIndex: Int
    public let scaleFactor: Double
    public let checkedIngredientIDs: [String]
    public let checkedStepOutputIDs: [String]

    public init(
        activeStepIndex: Int,
        scaleFactor: Double,
        checkedIngredientIDs: [String],
        checkedStepOutputIDs: [String]
    ) {
        self.activeStepIndex = activeStepIndex
        self.scaleFactor = scaleFactor
        self.checkedIngredientIDs = checkedIngredientIDs
        self.checkedStepOutputIDs = checkedStepOutputIDs
    }

    /// What a session holds when it starts.
    public static let initial = CookSyncProgress(
        activeStepIndex: 0,
        scaleFactor: 1,
        checkedIngredientIDs: [],
        checkedStepOutputIDs: []
    )

    private enum CodingKeys: String, CodingKey {
        case activeStepIndex
        case scaleFactor
        case checkedIngredientIDs = "checkedIngredientIds"
        case checkedStepOutputIDs = "checkedStepOutputIds"
    }

    /// Equal when the step and scale match and each checked list holds the same ids, in any order.
    public func isSame(as other: CookSyncProgress) -> Bool {
        activeStepIndex == other.activeStepIndex &&
            scaleFactor == other.scaleFactor &&
            Set(checkedIngredientIDs) == Set(other.checkedIngredientIDs) &&
            Set(checkedStepOutputIDs) == Set(other.checkedStepOutputIDs)
    }

    /// Puts the step and scale in range and keeps only ids that exist in the recipe as loaded.
    public func normalized(to bounds: CookSyncBounds) -> CookSyncProgress {
        CookSyncProgress(
            activeStepIndex: min(max(activeStepIndex, 0), max(bounds.stepCount - 1, 0)),
            scaleFactor: scaleFactor.isFinite ? (min(max(scaleFactor, 0.25), 50) * 100).rounded() / 100 : 1,
            checkedIngredientIDs: Self.unique(checkedIngredientIDs).filter(bounds.ingredientIDs.contains),
            checkedStepOutputIDs: Self.unique(checkedStepOutputIDs).filter(bounds.stepOutputIDs.contains)
        )
    }

    /// Like `normalized(to:)`, but leaves alone what `server` already holds: a checked id from a newer version of
    /// the recipe, and a step or scale this device did not change. The server checked those against its own
    /// recipe, and sending the trimmed value would erase another device's progress. Only this device's own
    /// changes are fitted to the recipe as it loaded it.
    public func normalized(to bounds: CookSyncBounds, keeping server: CookSyncProgress) -> CookSyncProgress {
        let fitted = normalized(to: bounds)
        let serverIngredients = Set(server.checkedIngredientIDs)
        let serverOutputs = Set(server.checkedStepOutputIDs)
        return CookSyncProgress(
            activeStepIndex: activeStepIndex == server.activeStepIndex ? activeStepIndex : fitted.activeStepIndex,
            scaleFactor: scaleFactor == server.scaleFactor ? scaleFactor : fitted.scaleFactor,
            checkedIngredientIDs: Self.unique(checkedIngredientIDs).filter { bounds.ingredientIDs.contains($0) || serverIngredients.contains($0) },
            checkedStepOutputIDs: Self.unique(checkedStepOutputIDs).filter { bounds.stepOutputIDs.contains($0) || serverOutputs.contains($0) }
        )
    }

    /// Puts back into this device's progress what `base` held outside this device's recipe. The device cannot
    /// show or keep those ids or that step, so their absence here is not a change the cook made.
    public func restoringUnknown(from base: CookSyncProgress, bounds: CookSyncBounds) -> CookSyncProgress {
        let ingredients = Set(checkedIngredientIDs)
        let outputs = Set(checkedStepOutputIDs)
        let baseStepIsUnknown = base.activeStepIndex >= bounds.stepCount || base.activeStepIndex < 0
        let fittedBaseStep = base.normalized(to: bounds).activeStepIndex
        return CookSyncProgress(
            activeStepIndex: baseStepIsUnknown && activeStepIndex == fittedBaseStep ? base.activeStepIndex : activeStepIndex,
            scaleFactor: scaleFactor,
            checkedIngredientIDs: checkedIngredientIDs + base.checkedIngredientIDs.filter { !bounds.ingredientIDs.contains($0) && !ingredients.contains($0) },
            checkedStepOutputIDs: checkedStepOutputIDs + base.checkedStepOutputIDs.filter { !bounds.stepOutputIDs.contains($0) && !outputs.contains($0) }
        )
    }

    /// Replays `local`'s changes since `base` on top of `remote`.
    public static func merge(
        base: CookSyncProgress,
        local: CookSyncProgress,
        remote: CookSyncProgress
    ) -> CookSyncProgress {
        CookSyncProgress(
            activeStepIndex: local.activeStepIndex != base.activeStepIndex ? local.activeStepIndex : remote.activeStepIndex,
            scaleFactor: local.scaleFactor != base.scaleFactor ? local.scaleFactor : remote.scaleFactor,
            checkedIngredientIDs: mergeIDs(
                base: base.checkedIngredientIDs,
                local: local.checkedIngredientIDs,
                remote: remote.checkedIngredientIDs
            ),
            checkedStepOutputIDs: mergeIDs(
                base: base.checkedStepOutputIDs,
                local: local.checkedStepOutputIDs,
                remote: remote.checkedStepOutputIDs
            )
        )
    }

    /// The fields of `target` that differ from `self`, as the `changes` of a protocol PATCH.
    public func changes(to target: CookSyncProgress) -> CookSyncChanges {
        CookSyncChanges(
            activeStepIndex: activeStepIndex != target.activeStepIndex ? target.activeStepIndex : nil,
            scaleFactor: scaleFactor != target.scaleFactor ? target.scaleFactor : nil,
            checkedIngredientIDs: Set(checkedIngredientIDs) != Set(target.checkedIngredientIDs) ? target.checkedIngredientIDs : nil,
            checkedStepOutputIDs: Set(checkedStepOutputIDs) != Set(target.checkedStepOutputIDs) ? target.checkedStepOutputIDs : nil
        )
    }

    private static func mergeIDs(base: [String], local: [String], remote: [String]) -> [String] {
        let baseSet = Set(base)
        let localSet = Set(local)
        let unchecked = Set(base.filter { !localSet.contains($0) })
        var merged = remote.filter { !unchecked.contains($0) }
        for id in local where !baseSet.contains(id) && !merged.contains(id) {
            merged.append(id)
        }
        return merged
    }

    private static func unique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }
}

/// The `changes` object of a protocol PATCH: only the fields that differ.
public struct CookSyncChanges: Equatable, Sendable {
    public let activeStepIndex: Int?
    public let scaleFactor: Double?
    public let checkedIngredientIDs: [String]?
    public let checkedStepOutputIDs: [String]?

    public init(
        activeStepIndex: Int? = nil,
        scaleFactor: Double? = nil,
        checkedIngredientIDs: [String]? = nil,
        checkedStepOutputIDs: [String]? = nil
    ) {
        self.activeStepIndex = activeStepIndex
        self.scaleFactor = scaleFactor
        self.checkedIngredientIDs = checkedIngredientIDs
        self.checkedStepOutputIDs = checkedStepOutputIDs
    }

    public var isEmpty: Bool {
        activeStepIndex == nil && scaleFactor == nil && checkedIngredientIDs == nil && checkedStepOutputIDs == nil
    }

    /// The wire form, with the server's field names.
    public var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        object["activeStepIndex"] = activeStepIndex
        object["scaleFactor"] = scaleFactor
        object["checkedIngredientIds"] = checkedIngredientIDs
        object["checkedStepOutputIds"] = checkedStepOutputIDs
        return object
    }
}

/// What the recipe as loaded allows: the server refuses ids and steps that are not in the recipe.
public struct CookSyncBounds: Equatable, Sendable {
    public let stepCount: Int
    public let ingredientIDs: Set<String>
    public let stepOutputIDs: Set<String>

    public init(stepCount: Int, ingredientIDs: Set<String>, stepOutputIDs: Set<String>) {
        self.stepCount = stepCount
        self.ingredientIDs = ingredientIDs
        self.stepOutputIDs = stepOutputIDs
    }
}

/// The server's session state as last seen: the revision to send back and the progress it held.
public struct CookServerSnapshot: Codable, Equatable, Sendable {
    public let attemptID: String
    public let revision: Int
    public let progress: CookSyncProgress

    public init(attemptID: String, revision: Int, progress: CookSyncProgress) {
        self.attemptID = attemptID
        self.revision = revision
        self.progress = progress
    }

    private enum CodingKeys: String, CodingKey {
        case attemptID = "attemptId"
        case revision
        case progress
    }
}

public enum CookSyncResult: Equatable, Sendable {
    /// The session, or nil when this chef has not started one for the recipe.
    case state(CookServerSnapshot?)
    /// 409: the server has newer progress (a stale revision or a new attempt).
    case conflict(CookServerSnapshot)
    /// 404: the session is gone (PATCH), or the recipe is (start, read).
    case missing
    /// 400: the server refused this request's content.
    case rejected
    /// 401: the sign-in ended or was refused.
    case unauthenticated
    /// Will not succeed by retrying: 503 protocol unavailable (sync is off), 403, 412, 428 and other 4xx.
    case stopped
    /// May succeed later: no network, 429, and 5xx other than 503 protocol unavailable.
    case transient(retryAfterSeconds: Int?)
}

public protocol CookSessionClient: Sendable {
    func read(recipeID: String) async -> CookSyncResult
    func start(recipeID: String) async -> CookSyncResult
    func patch(
        recipeID: String,
        server: CookServerSnapshot,
        changes: CookSyncChanges,
        mutationID: String
    ) async -> CookSyncResult
}

public enum CookSyncOutcome: Equatable, Sendable {
    /// The server has everything this device has.
    case synced
    /// The server could not be reached; changes wait and go at the next sync.
    case retryLater
    /// The server will not take progress right now (sync is off, access refused). Progress stays on this
    /// device and nothing is shown; the next recipe open tries again.
    case off
    /// The sign-in ended. Progress stays on this device.
    case signedOut
}

public struct CookSyncReconciliation: Equatable, Sendable {
    /// The device's progress after the exchange (merged with the server's, or the server's when it refused ours).
    public let progress: CookSyncProgress
    /// The server state to remember as the base for the next exchange.
    public let server: CookServerSnapshot?
    public let outcome: CookSyncOutcome
}

/// One exchange with the server for one recipe: reads the server's latest state when asked (or when none is
/// known), starts the session when there is progress to keep, and sends the device's changes, replaying them
/// on top of the server's state whenever it has moved on. It never waits between attempts: a transient
/// failure ends the exchange and the next sync tries again.
public struct CookSessionReconciler: Sendable {
    public static let maxRounds = 4

    private let client: any CookSessionClient
    private let mutationID: @Sendable () -> String

    public init(
        client: any CookSessionClient,
        mutationID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.client = client
        self.mutationID = mutationID
    }

    public func reconcile(
        recipeID: String,
        local: CookSyncProgress,
        known: CookServerSnapshot?,
        pull: Bool,
        bounds: CookSyncBounds
    ) async -> CookSyncReconciliation {
        var known = known
        var remote = known
        var local = local

        if pull || known == nil {
            switch await client.read(recipeID: recipeID) {
            case .state(let state):
                remote = state
            case let result:
                return failure(result, local: local, known: known)
            }
        }

        // First keep what the server holds that this device cannot show. The server never prunes checks a recipe
        // edit removed and refuses a list that names them, so if it refuses, send again fitted to this recipe.
        var fitsThisRecipeOnly = false
        for _ in 0..<Self.maxRounds {
            if remote == nil {
                // Nothing on the server yet: only start a session once there is progress to keep.
                if local.isSame(as: .initial) {
                    return CookSyncReconciliation(progress: local, server: nil, outcome: .synced)
                }
                switch await client.start(recipeID: recipeID) {
                case .state(let state?):
                    remote = state
                case let result:
                    return failure(result, local: local, known: known)
                }
            }

            let current = remote!
            let base = known?.attemptID == current.attemptID ? known!.progress : CookSyncProgress.initial
            let fitted = CookSyncProgress.merge(base: base, local: local, remote: current.progress).normalized(to: bounds)
            let merged = fitsThisRecipeOnly
                ? fitted
                : CookSyncProgress.merge(base: base, local: local.restoringUnknown(from: base, bounds: bounds), remote: current.progress)
                    .normalized(to: bounds, keeping: current.progress)
            // A refused change that kept nothing extra would be refused again as it is.
            let canRetryFitted = !fitsThisRecipeOnly && !merged.isSame(as: fitted)
            if merged.isSame(as: current.progress) {
                return CookSyncReconciliation(progress: merged, server: current, outcome: .synced)
            }

            let result = await client.patch(
                recipeID: recipeID,
                server: current,
                changes: current.progress.changes(to: merged),
                mutationID: mutationID()
            )
            switch result {
            case .state(let state?):
                // Anything the cook changed since is replayed by the caller against `merged`.
                known = state
                local = merged
                remote = state
            case .conflict(let state):
                // Keep the base the pending changes were made against, and replay them on the newer state.
                remote = state
            case .missing:
                known = nil
                remote = nil
            case .rejected where canRetryFitted:
                fitsThisRecipeOnly = true
            case .rejected:
                return await adoptServerProgress(recipeID: recipeID, local: local, known: known, bounds: bounds)
            default:
                return failure(result, local: local, known: known)
            }
        }
        return CookSyncReconciliation(progress: local, server: known, outcome: .retryLater)
    }

    private func failure(_ result: CookSyncResult, local: CookSyncProgress, known: CookServerSnapshot?) -> CookSyncReconciliation {
        let outcome: CookSyncOutcome
        switch result {
        case .transient:
            outcome = .retryLater
        case .unauthenticated:
            outcome = .signedOut
        default:
            outcome = .off
        }
        return CookSyncReconciliation(progress: local, server: known, outcome: outcome)
    }

    // The server refused this device's progress (the recipe changed since the device loaded it). Show the
    // server's progress instead of sending the same refused change again. The server's state is remembered as
    // the server holds it, so the next exchange does not read ids this device cannot show as unchecks.
    private func adoptServerProgress(
        recipeID: String,
        local: CookSyncProgress,
        known: CookServerSnapshot?,
        bounds: CookSyncBounds
    ) async -> CookSyncReconciliation {
        switch await client.read(recipeID: recipeID) {
        case .state(let state):
            let serverProgress = state?.progress ?? .initial
            return CookSyncReconciliation(
                progress: serverProgress.normalized(to: bounds, keeping: serverProgress),
                server: state,
                outcome: .synced
            )
        case let result:
            return failure(result, local: local, known: known)
        }
    }
}
