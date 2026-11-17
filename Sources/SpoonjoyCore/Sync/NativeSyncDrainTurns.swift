import Foundation
import Synchronization

/// Sync passes on one store take turns.
///
/// A pass loads the queue once, sends each edit from that copy, and writes what is left back at the end. Two passes on
/// one store at once (the app's own sync, and the one a Siri or Shortcuts intent starts for the edit it just queued)
/// would each send and write back their own stale copy: an edit the first pass had pointed at a new recipe's or item's
/// server id goes out again at the temporary id, and the stale copy then replaces the fixed one in the queue.
/// `NativeSyncEngine` takes a turn here for every pass, so the second pass loads the queue only after the first has
/// finished with it.
///
/// Waiting for a turn can be cancelled, so a Siri pass with a deadline gives up instead of waiting out the app's sync;
/// its edits stay queued for the next sync.
enum NativeSyncDrainTurns {
    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct Turns {
        var nextWaiterID: UInt64 = 0
        /// A store has an entry while a pass holds its turn; the entry lists the passes waiting, first come first served.
        var waitersByStore: [ObjectIdentifier: [Waiter]] = [:]
    }

    private enum Arrival {
        case go
        case wait
        case cancelled
    }

    private static let turns = Mutex(Turns())

    /// Runs `pass` when no other pass on `store` is running, and gives the turn to the next pass when it ends. The engine
    /// calls `take` and `hand` itself; this is the same thing as one call, for tests.
    static func run<Result>(on store: any NativeSyncStore, _ pass: () async throws -> Result) async throws -> Result {
        try await take(on: store)
        defer { hand(on: store) }
        return try await pass()
    }

    /// How many passes on `store` are waiting for their turn.
    static func waitingCount(on store: any NativeSyncStore) -> Int {
        turns.withLock { $0.waitersByStore[ObjectIdentifier(store)]?.count ?? 0 }
    }

    /// Waits for `store`'s turn. Every successful `take` is followed by exactly one `hand`, on every path out.
    static func take(on store: any NativeSyncStore) async throws {
        let key = ObjectIdentifier(store)
        let id = turns.withLock { turns -> UInt64 in
            turns.nextWaiterID += 1
            return turns.nextWaiterID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let arrival = turns.withLock { turns -> Arrival in
                    // Checked under the lock, so a cancellation either lands here or finds this waiter in the list.
                    if Task.isCancelled {
                        return .cancelled
                    }
                    guard turns.waitersByStore[key] != nil else {
                        turns.waitersByStore[key] = []
                        return .go
                    }
                    turns.waitersByStore[key]?.append(Waiter(id: id, continuation: continuation))
                    return .wait
                }
                switch arrival {
                case .go:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .wait:
                    break
                }
            }
        } onCancel: {
            let cancelled = turns.withLock { turns -> CheckedContinuation<Void, any Error>? in
                guard let index = turns.waitersByStore[key]?.firstIndex(where: { $0.id == id }) else {
                    return nil
                }
                return turns.waitersByStore[key]?.remove(at: index).continuation
            }
            cancelled?.resume(throwing: CancellationError())
        }
    }

    /// Gives `store`'s turn to the next pass waiting, if any.
    static func hand(on store: any NativeSyncStore) {
        let key = ObjectIdentifier(store)
        let next = turns.withLock { turns -> CheckedContinuation<Void, any Error>? in
            guard var waiters = turns.waitersByStore[key], !waiters.isEmpty else {
                turns.waitersByStore[key] = nil
                return nil
            }
            let next = waiters.removeFirst()
            turns.waitersByStore[key] = waiters
            return next.continuation
        }
        next?.resume()
    }
}
