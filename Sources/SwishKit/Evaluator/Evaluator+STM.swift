import Synchronization

/// Serializes the brief verify-and-commit phase of every `dosync` transaction.
/// Transaction *bodies* run fully unlocked/concurrently (mirroring `Printer.swift`'s
/// `formatterLock` pattern for a module-level lock guarding a narrow critical section).
private let stmCommitLock = Mutex<Void>(())

/// Tracks the refs touched by one in-progress `dosync` transaction on the thread
/// that's running it. Installed only into that thread's `currentTransaction`
/// thread-local slot and never crosses threads (the transaction body runs
/// synchronously in-line, with no GCD dispatch), so unlike `SwishRef`/`SwishAtom`/
/// `SwishAgent` it needs no internal locking of its own.
final class TransactionContext {
    private struct Entry {
        let ref: SwishRef
        let refExpr: Expr
        let startVersion: Int
        let startValue: Expr
        var currentValue: Expr
        var written = false
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    private func entry(for ref: SwishRef, refExpr: Expr) -> Entry {
        let id = ObjectIdentifier(ref)
        if let existing = entries[id] {
            return existing
        }
        let (value, version) = ref.snapshot()
        let created = Entry(ref: ref, refExpr: refExpr, startVersion: version, startValue: value, currentValue: value)
        entries[id] = created
        return created
    }

    /// The in-transaction working value of `ref` — its first-touch snapshot if
    /// untouched so far, or whatever was last written to it in this transaction.
    func read(_ ref: SwishRef, refExpr: Expr) -> Expr {
        entry(for: ref, refExpr: refExpr).currentValue
    }

    func write(_ value: Expr, to ref: SwishRef, refExpr: Expr) {
        var e = entry(for: ref, refExpr: refExpr)
        e.currentValue = value
        e.written = true
        entries[ObjectIdentifier(ref)] = e
    }

    struct CommitResult {
        let refExpr: Expr
        let ref: SwishRef
        let old: Expr
        let new: Expr
    }

    /// Attempts to commit this transaction. Two full passes, never interleaved:
    /// first verify every touched ref (reads AND writes) still matches the version
    /// seen at first touch; only if all of them do, write the written ones. This
    /// ordering matters — interleaving verify-and-write per ref risks writing one
    /// ref, then discovering another's version mismatched, leaving an actually-
    /// aborting transaction partially committed with no rollback path. Returns nil
    /// on a version conflict (caller should retry the whole transaction body).
    func attemptCommit() -> [CommitResult]? {
        stmCommitLock.withLock { _ in
            for e in entries.values where e.ref.version != e.startVersion {
                return nil
            }
            var results: [CommitResult] = []
            for e in entries.values where e.written {
                // Defensive only: phase 1 already verified this under the same
                // lock, and commitIfVersion is the only mutator, so this cannot
                // actually fail here.
                guard e.ref.commitIfVersion(e.startVersion, newValue: e.currentValue) else {
                    return nil
                }
                results.append(CommitResult(refExpr: e.refExpr, ref: e.ref, old: e.startValue, new: e.currentValue))
            }
            return results
        }
    }
}

extension Evaluator {
    private static let currentTransactionKey = "swish.evaluator.currentTransaction"

    /// The `dosync` transaction currently running on this thread, if any. `nil`
    /// outside a transaction. Thread-local for the same reason `bindingFrames`/
    /// `currentCancellationCheck` are: `TransactionContext` runs entirely on the
    /// calling thread, never dispatched elsewhere.
    var currentTransaction: TransactionContext? {
        get { threadLocalBox(for: Self.currentTransactionKey, default: nil).value }
        set { threadLocalBox(for: Self.currentTransactionKey, default: nil).value = newValue }
    }
}
