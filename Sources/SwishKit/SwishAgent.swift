import Foundation
import Synchronization

/// A Swish agent — a thread-safe mutable reference updated asynchronously by
/// actions dispatched serially (FIFO) via a dedicated per-agent queue, matching
/// Clojure's per-agent action-ordering guarantee.
public final class SwishAgent: @unchecked Sendable {
    private struct State {
        var value: Expr
        var metadata: [Expr: Expr]?
        var validator: Expr?
        var watches: [Expr: Expr] = [:]
        /// Non-nil means the agent is failed: actions no-op until `restart`.
        var error: Expr? = nil
    }

    private let state: Mutex<State>
    private let queue = DispatchQueue(label: "swish.agent.\(UUID().uuidString)")

    var value: Expr { state.withLock { $0.value } }
    var metadata: [Expr: Expr]? {
        get { state.withLock { $0.metadata } }
        set { state.withLock { $0.metadata = newValue } }
    }
    var validator: Expr? {
        get { state.withLock { $0.validator } }
        set { state.withLock { $0.validator = newValue } }
    }
    var watches: [Expr: Expr] { state.withLock { $0.watches } }
    var error: Expr? { state.withLock { $0.error } }

    init(_ value: Expr, metadata: [Expr: Expr]? = nil, validator: Expr? = nil) {
        state = Mutex(State(value: value, metadata: metadata, validator: validator))
    }

    func addWatch(key: Expr, fn: Expr) {
        state.withLock { $0.watches[key] = fn }
    }

    func removeWatch(key: Expr) {
        state.withLock { _ = $0.watches.removeValue(forKey: key) }
    }

    /// Clears the failed state and sets a new value.
    func restart(newValue: Expr) {
        state.withLock { $0.value = newValue; $0.error = nil }
    }

    /// Runs one action: no-ops if the agent is currently failed. Called on `queue`.
    private func runAction(evaluator: Evaluator, agentExpr: Expr, actionFn: Expr, extraArgs: [Expr]) {
        guard state.withLock({ $0.error == nil }) else { return }
        let old = value
        do {
            let newValue = try evaluator.call(actionFn, args: [old] + extraArgs)
            if let vf = validator {
                try checkValidator(evaluator, fn: vf, value: newValue, context: "send")
            }
            state.withLock { $0.value = newValue }
            try notifyWatches(evaluator, watches: watches, ref: agentExpr, old: old, new: newValue)
        } catch {
            state.withLock { $0.error = evaluator.exprForError(error) }
        }
    }

    /// `send`/`send-off` — enqueues an action to run asynchronously on this
    /// agent's serial queue, with the calling thread's dynamic bindings conveyed.
    func enqueue(evaluator: Evaluator, agentExpr: Expr, actionFn: Expr, extraArgs: [Expr]) {
        let frames = evaluator.captureCurrentBindings()
        queue.async {
            evaluator.withInstalledBindings(frames, callDepth: 0) {
                self.runAction(evaluator: evaluator, agentExpr: agentExpr, actionFn: actionFn, extraArgs: extraArgs)
            }
        }
    }

    /// `await` — enqueues a no-op identity action and blocks until every action
    /// submitted before it has completed (the serial queue is strict FIFO). This
    /// goes through the same `runAction` path as a real send, so it also fires
    /// watches (with old == new, since it's a no-op) — matching real Clojure's
    /// `await` implementation.
    func await(evaluator: Evaluator, agentExpr: Expr) {
        let frames = evaluator.captureCurrentBindings()
        let identity: Expr = .nativeFunction(name: "identity", arity: .fixed(1)) { $0[0] }
        queue.sync {
            evaluator.withInstalledBindings(frames, callDepth: 0) {
                self.runAction(evaluator: evaluator, agentExpr: agentExpr, actionFn: identity, extraArgs: [])
            }
        }
    }
}
