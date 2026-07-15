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
        /// Called with [agent, exception] whenever an action throws, regardless
        /// of error mode.
        var errorHandler: Expr? = nil
        /// `nil` means "never explicitly set" — see `effectiveErrorMode`.
        var explicitErrorMode: Expr? = nil

        /// `:fail` fails the agent on a throwing action (see `error`). `:continue`
        /// swallows the exception, leaves the value unchanged, and keeps draining
        /// the queue normally. Matches real Clojure's dynamic default: `:continue`
        /// once an error-handler has been set and error-mode has never been
        /// explicitly set via `set-error-mode!`; `:fail` otherwise. Recomputed live,
        /// so clearing the handler (`set-error-handler! nil`) without ever having
        /// called `set-error-mode!` reverts the effective mode back to `:fail`.
        var effectiveErrorMode: Expr {
            explicitErrorMode ?? (errorHandler != nil ? .keyword("continue") : .keyword("fail"))
        }
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
    var errorHandler: Expr? {
        get { state.withLock { $0.errorHandler } }
        set { state.withLock { $0.errorHandler = newValue } }
    }
    var errorMode: Expr {
        get { state.withLock { $0.effectiveErrorMode } }
        set { state.withLock { $0.explicitErrorMode = newValue } }
    }

    init(_ value: Expr, metadata: [Expr: Expr]? = nil, validator: Expr? = nil) {
        state = Mutex(State(value: value, metadata: metadata, validator: validator))
    }

    func addWatch(key: Expr, fn: Expr) {
        state.withLock { $0.watches[key] = fn }
    }

    func removeWatch(key: Expr) {
        state.withLock { _ = $0.watches.removeValue(forKey: key) }
    }

    /// Clears the failed state and sets a new value, validating it first. Runs on
    /// `queue` so it's ordered relative to any actions already in flight — happens-
    /// after anything queued before this call, happens-before anything queued after.
    func restart(evaluator: Evaluator, newValue: Expr) throws {
        try queue.sync {
            if let vf = validator {
                try checkValidator(evaluator, fn: vf, value: newValue, context: "restart-agent")
            }
            state.withLock { $0.value = newValue; $0.error = nil }
        }
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
            let errExpr = evaluator.exprForError(error)
            let (handler, mode) = state.withLock { ($0.errorHandler, $0.effectiveErrorMode) }
            if let handler {
                _ = try? evaluator.call(handler, args: [agentExpr, errExpr])
            }
            if mode != .keyword("continue") {
                state.withLock { $0.error = errExpr }
            }
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

    /// Backs `await-for`'s bounded wait: enqueues the same no-op identity action
    /// as `await`, but asynchronously — signaling `group` on completion instead of
    /// blocking the calling thread — so a caller can wait across multiple agents
    /// against one shared deadline via `DispatchGroup.wait(timeout:)`. A timed-out
    /// wait doesn't cancel anything; the dispatched action keeps running to
    /// completion, matching real Clojure's `await-for`.
    func awaitAsync(evaluator: Evaluator, agentExpr: Expr, group: DispatchGroup) {
        let frames = evaluator.captureCurrentBindings()
        let identity: Expr = .nativeFunction(name: "identity", arity: .fixed(1)) { $0[0] }
        group.enter()
        queue.async {
            evaluator.withInstalledBindings(frames, callDepth: 0) {
                self.runAction(evaluator: evaluator, agentExpr: agentExpr, actionFn: identity, extraArgs: [])
            }
            group.leave()
        }
    }
}
