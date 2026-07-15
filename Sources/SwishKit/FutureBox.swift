import Foundation

/// Backing store for a `future`. Runs `body` on `SwishExecutor.shared` with the
/// creating thread's dynamic bindings conveyed. `deref` blocks until realized;
/// `cancel()` always synchronously transitions a still-pending future to
/// `.cancelled` — cancellation is cooperative (the reimplemented `sleep` polls
/// `Evaluator.currentCancellationCheck`), not true OS-thread interruption, since
/// Foundation has no portable "interrupt a running thread" primitive. A late
/// completion from a body that doesn't notice cancellation in time is discarded
/// by `complete(_:)`.
public final class FutureBox: @unchecked Sendable {
    private enum State {
        case pending
        case realized(Expr)
        case failed(Error)
        case cancelled
    }

    private var state: State = .pending
    private let cond = NSCondition()

    func run(evaluator: Evaluator, frames: [[ObjectIdentifier: Expr]], body: @escaping @Sendable () throws -> Expr) {
        SwishExecutor.shared.async { [self] in
            evaluator.withInstalledBindings(frames, callDepth: 0) {
                evaluator.currentCancellationCheck = { [weak self] in self?.cancelRequested ?? false }
                defer { evaluator.currentCancellationCheck = nil }
                do {
                    let v = try body()
                    complete(.realized(v))
                } catch {
                    complete(.failed(error))
                }
            }
        }
    }

    private func complete(_ newState: State) {
        cond.lock()
        defer { cond.unlock() }
        guard case .pending = state else { return }
        state = newState
        cond.broadcast()
    }

    private(set) var cancelRequested = false

    var isRealized: Bool {
        cond.lock()
        defer { cond.unlock() }
        if case .pending = state { return false }
        return true
    }

    var isCancelled: Bool {
        cond.lock()
        defer { cond.unlock() }
        if case .cancelled = state { return true }
        return false
    }

    /// Always synchronously flips a still-pending future to cancelled and
    /// returns `true`; returns `false` if the future was already done.
    @discardableResult
    func cancel() -> Bool {
        cond.lock()
        defer { cond.unlock() }
        guard case .pending = state else { return false }
        cancelRequested = true
        state = .cancelled
        cond.broadcast()
        return true
    }

    /// Blocks until realized, cancelled, or failed.
    func deref() throws -> Expr {
        cond.lock()
        while true {
            switch state {
            case .pending:
                cond.wait()
                continue

            case .realized(let v):
                cond.unlock()
                return v

            case .failed(let e):
                cond.unlock()
                throw e

            case .cancelled:
                cond.unlock()
                throw EvaluatorError.invalidArgument(function: "deref", message: "Future has been cancelled")
            }
        }
    }
}
