import Foundation

/// Pending edits that belong to an account other than the one the sync store is serving now.
///
/// The store keeps one active queue, for the account whose kitchen it caches. When another account signs in, the
/// previous account's edits are parked here instead of being dropped, and come back when that account signs in again.
/// An entry with no account holds edits made before the server confirmed who is signed in (a fresh sign-in has no
/// account id until its first sync); they join the account that sync confirms.
public struct NativeParkedMutationQueue: Codable, Equatable, Sendable {
    public let accountID: String?
    public let environment: NativeCacheEnvironment?
    public let queue: NativeMutationQueue

    public init(accountID: String?, environment: NativeCacheEnvironment?, queue: NativeMutationQueue) {
        self.accountID = accountID
        self.environment = environment
        self.queue = queue
    }
}

enum NativeMutationQueueParking {
    /// Parks `activeQueue` under the scope the store is leaving and returns the queue that belongs to the scope it is
    /// entering: that account's parked edits, then any edits made before the account was known.
    static func entering(
        accountID: String?,
        environment: NativeCacheEnvironment?,
        leavingAccountID: String?,
        leavingEnvironment: NativeCacheEnvironment?,
        activeQueue: NativeMutationQueue,
        parked: [NativeParkedMutationQueue]
    ) -> (queue: NativeMutationQueue, parked: [NativeParkedMutationQueue]) {
        let parked = parking(activeQueue, accountID: leavingAccountID, environment: leavingEnvironment, in: parked)
        let restored = parked.filter { $0.accountID == accountID && $0.environment == environment } +
            parked.filter { accountID != nil && isUnbound($0, joining: environment) }
        let remaining = parked.filter { entry in
            !(entry.accountID == accountID && entry.environment == environment) && !(accountID != nil && isUnbound(entry, joining: environment))
        }
        return (merged(restored.map(\.queue)), remaining)
    }

    /// Adds `queue` to the parked edits for its scope.
    static func parking(
        _ queue: NativeMutationQueue,
        accountID: String?,
        environment: NativeCacheEnvironment?,
        in parked: [NativeParkedMutationQueue]
    ) -> [NativeParkedMutationQueue] {
        // A queue stored with neither an account nor an environment predates account scoping; nobody can say whose
        // edits it holds, so it is not kept for anyone.
        guard accountID != nil || environment != nil else {
            return parked
        }
        let existing = parked.first { $0.accountID == accountID && $0.environment == environment }?.queue ?? NativeMutationQueue()
        return replacing(
            accountID: accountID,
            environment: environment,
            with: merged([existing, queue]),
            in: parked
        )
    }

    /// The edits made before the account was known, for `environment`.
    static func unboundQueue(environment: NativeCacheEnvironment?, in parked: [NativeParkedMutationQueue]) -> NativeMutationQueue {
        merged(parked.filter { isUnbound($0, joining: environment) }.map(\.queue))
    }

    /// Replaces the edits made before the account was known, for `environment`.
    static func replacingUnboundQueue(
        environment: NativeCacheEnvironment?,
        with queue: NativeMutationQueue,
        in parked: [NativeParkedMutationQueue]
    ) -> [NativeParkedMutationQueue] {
        replacing(accountID: nil, environment: environment, with: queue, in: parked.filter { !isUnbound($0, joining: environment) })
    }

    /// A queue saved into a scope the store just entered: the edits brought back for that scope, then the saved queue.
    /// An edit in both keeps the saved copy.
    static func saving(_ queue: NativeMutationQueue, after restored: NativeMutationQueue) -> NativeMutationQueue {
        let savedIDs = Set(queue.mutations.map(\.clientMutationID))
        return NativeMutationQueue(validatedMutations: restored.mutations.filter { !savedIDs.contains($0.clientMutationID) } + queue.mutations)
    }

    /// Joins queues in order, keeping the first copy of any edit that appears twice.
    static func merged(_ queues: [NativeMutationQueue]) -> NativeMutationQueue {
        var seen = Set<String>()
        return NativeMutationQueue(validatedMutations: queues.flatMap(\.mutations).filter { seen.insert($0.clientMutationID).inserted })
    }

    private static func replacing(
        accountID: String?,
        environment: NativeCacheEnvironment?,
        with queue: NativeMutationQueue,
        in parked: [NativeParkedMutationQueue]
    ) -> [NativeParkedMutationQueue] {
        let others = parked.filter { !($0.accountID == accountID && $0.environment == environment) }
        guard !queue.mutations.isEmpty else {
            return others
        }
        return others + [NativeParkedMutationQueue(accountID: accountID, environment: environment, queue: queue)]
    }

    /// Edits made before the account was known join the next account confirmed in the same environment.
    private static func isUnbound(_ entry: NativeParkedMutationQueue, joining environment: NativeCacheEnvironment?) -> Bool {
        entry.accountID == nil && entry.environment == environment
    }
}

extension NativeSyncSnapshot {
    /// The pending edits for a scope: the active queue when the scope is the one the store serves, the edits made
    /// before the account was known when `accountID` is nil, and nothing otherwise.
    public func queue(accountID: String?, environment: NativeCacheEnvironment?) -> NativeMutationQueue {
        if self.accountID == accountID && self.environment == environment {
            return queue
        }
        guard accountID == nil else {
            return NativeMutationQueue()
        }
        return NativeMutationQueueParking.unboundQueue(environment: environment, in: parkedQueues)
    }
}
